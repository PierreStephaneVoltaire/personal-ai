import json
import os
import urllib.request

KNOWLEDGE_BASE_URL = os.environ.get('KNOWLEDGE_BASE_URL', '')

def lambda_handler(event, context):
    query = event.get('query', '')
    collection = event.get('collection', 'supplements')
    n_results = event.get('n_results', 5)

    if not query:
        return {'statusCode': 400, 'body': json.dumps({'error': 'Missing query parameter'})}

    if not KNOWLEDGE_BASE_URL:
        return {'statusCode': 500, 'body': json.dumps({'error': 'Knowledge base URL not configured'})}

    try:
        payload = json.dumps({'query': query, 'collection': collection, 'n_results': n_results}).encode()
        req = urllib.request.Request(f"{KNOWLEDGE_BASE_URL}/query", data=payload, headers={'Content-Type': 'application/json'})
        with urllib.request.urlopen(req, timeout=10) as response:
            data = json.loads(response.read().decode())
            return {'statusCode': 200, 'body': json.dumps(data)}
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}
