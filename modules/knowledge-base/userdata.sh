#!/bin/bash
set -e

S3_BUCKET="${s3_bucket}"

dnf install -y python3.11 python3.11-pip poppler-utils
pip3.11 install chromadb sentence-transformers pypdf2 fastapi uvicorn

mkdir -p /opt/knowledge-base/data
aws s3 sync s3://$S3_BUCKET/documents /opt/knowledge-base/data/

cat > /opt/knowledge-base/server.py << 'PYEOF'
import os
import chromadb
from chromadb.config import Settings
from sentence_transformers import SentenceTransformer
from fastapi import FastAPI
from pydantic import BaseModel
from PyPDF2 import PdfReader
import glob

app = FastAPI()
model = SentenceTransformer('all-MiniLM-L6-v2')
client = chromadb.Client(Settings(persist_directory="/opt/knowledge-base/chroma"))

class QueryRequest(BaseModel):
    query: str
    collection: str = "supplements"
    n_results: int = 5

class IngestRequest(BaseModel):
    collection: str

def extract_pdf_text(path):
    reader = PdfReader(path)
    return "\n".join(page.extract_text() or "" for page in reader.pages)

def chunk_text(text, size=500, overlap=50):
    chunks = []
    start = 0
    while start < len(text):
        end = start + size
        chunks.append(text[start:end])
        start = end - overlap
    return chunks

@app.post("/ingest")
def ingest(request: IngestRequest):
    collection = client.get_or_create_collection(name=request.collection)
    data_dir = f"/opt/knowledge-base/data/{request.collection}"
    count = 0
    for pdf_path in glob.glob(f"{data_dir}/*.pdf"):
        text = extract_pdf_text(pdf_path)
        chunks = chunk_text(text)
        for i, chunk in enumerate(chunks):
            doc_id = f"{os.path.basename(pdf_path)}_{i}"
            embedding = model.encode(chunk).tolist()
            collection.add(ids=[doc_id], embeddings=[embedding], documents=[chunk], metadatas=[{"source": pdf_path}])
            count += 1
    return {"status": "ok", "documents_ingested": count}

@app.post("/query")
def query(request: QueryRequest):
    collection = client.get_or_create_collection(name=request.collection)
    query_embedding = model.encode(request.query).tolist()
    results = collection.query(query_embeddings=[query_embedding], n_results=request.n_results)
    return {"results": [{"content": doc, "metadata": meta} for doc, meta in zip(results["documents"][0], results["metadatas"][0])]}

@app.get("/collections")
def list_collections():
    return {"collections": [c.name for c in client.list_collections()]}
PYEOF

cat > /etc/systemd/system/knowledge-base.service << EOF
[Unit]
Description=Knowledge Base API
After=network.target

[Service]
ExecStart=/usr/bin/python3.11 -m uvicorn server:app --host 0.0.0.0 --port 8000
WorkingDirectory=/opt/knowledge-base
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable knowledge-base
systemctl start knowledge-base
