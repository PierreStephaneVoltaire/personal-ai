import os
import httpx

class LiteLLMClient:
    def __init__(self):
        self.base_url = os.getenv("LITELLM_URL", "http://litellm:4000")
        self.timeout = httpx.Timeout(120.0, connect=10.0)

    async def chat(self, model: str, messages: list, max_tokens: int, temperature: float) -> str:
        async with httpx.AsyncClient(timeout=self.timeout) as client:
            response = await client.post(
                f"{self.base_url}/chat/completions",
                json={
                    "model": model,
                    "messages": messages,
                    "max_tokens": max_tokens,
                    "temperature": temperature,
                    "stream": False
                }
            )
            response.raise_for_status()
            result = response.json()
            return result["choices"][0]["message"]["content"]
