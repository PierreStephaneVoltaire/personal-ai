import json
import uuid
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from typing import List, Optional
from graph import create_council_graph

app = FastAPI()

class Message(BaseModel):
    role: str
    content: str
    name: Optional[str] = None

class ChatCompletionRequest(BaseModel):
    model: str
    messages: List[Message]
    stream: Optional[bool] = False

council_graph = None

@app.on_event("startup")
async def startup_event():
    global council_graph
    council_graph = create_council_graph()

@app.get("/health")
async def health():
    return {"status": "healthy"}

@app.post("/v1/chat/completions")
async def chat_completions(request: ChatCompletionRequest):
    session_id = str(uuid.uuid4())

    messages = [{"role": msg.role, "content": msg.content} for msg in request.messages]

    initial_state = {
        "messages": messages,
        "next_speaker": "",
        "current_speaker": "",
        "resolved": False,
        "turn_count": 0
    }

    if request.stream:
        async def generate():
            streamed_count = len(messages)  # Track how many messages we've already streamed

            async for event in council_graph.astream(initial_state):
                for node_name, node_state in event.items():
                    if node_state.get("messages"):
                        current_messages = node_state["messages"]
                        # Only stream messages we haven't streamed yet
                        new_messages = current_messages[streamed_count:]

                        for message in new_messages:
                            if message["role"] == "assistant":
                                chunk = {
                                    "id": f"chatcmpl-{session_id}",
                                    "object": "chat.completion.chunk",
                                    "created": 1234567890,
                                    "model": "council",
                                    "choices": [{
                                        "index": 0,
                                        "delta": {"content": message["content"] + "\n\n"},
                                        "finish_reason": None
                                    }]
                                }
                                yield f"data: {json.dumps(chunk)}\n\n"

                        streamed_count = len(current_messages)

            final_chunk = {
                "id": f"chatcmpl-{session_id}",
                "object": "chat.completion.chunk",
                "created": 1234567890,
                "model": "council",
                "choices": [{
                    "index": 0,
                    "delta": {},
                    "finish_reason": "stop"
                }]
            }
            yield f"data: {json.dumps(final_chunk)}\n\n"
            yield "data: [DONE]\n\n"

        return StreamingResponse(generate(), media_type="text/event-stream")
    else:
        result = await council_graph.ainvoke(initial_state)

        all_responses = []
        for msg in result["messages"]:
            if msg["role"] == "assistant":
                all_responses.append(msg["content"])

        final_content = "\n\n".join(all_responses)

        return {
            "id": f"chatcmpl-{session_id}",
            "object": "chat.completion",
            "created": 1234567890,
            "model": "council",
            "choices": [{
                "index": 0,
                "message": {
                    "role": "assistant",
                    "content": final_content
                },
                "finish_reason": "stop"
            }],
            "usage": {
                "prompt_tokens": 0,
                "completion_tokens": 0,
                "total_tokens": 0
            }
        }
