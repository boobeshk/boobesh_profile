"""Sends a prompt to the model through Kong and prints the answer and the request ID.

Usage:
    export LLM_URL=http://<kong-proxy>        # or http://localhost:8000 with port-forward
    export LLM_API_KEY=demo-assistant-key-change-me
    python ask.py "Explain a Kubernetes PodDisruptionBudget in two sentences."
"""

import json
import os
import sys
import urllib.error
import urllib.request

MODEL = os.environ.get("LLM_MODEL", "llama3.2:1b")


def ask(prompt):
    request = urllib.request.Request(
        f"{os.environ['LLM_URL'].rstrip('/')}/api/generate",
        data=json.dumps({"model": MODEL, "prompt": prompt, "stream": False}).encode(),
        headers={"Content-Type": "application/json", "apikey": os.environ["LLM_API_KEY"]},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            body = json.load(response)
            return body["response"], response.headers.get("X-Request-ID", "-")
    except urllib.error.HTTPError as err:
        # 401 = bad key, 413 = prompt too large, 429 = rate limit reached.
        sys.exit(f"Gateway returned {err.code}: {err.read().decode(errors='replace')}")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    answer, request_id = ask(" ".join(sys.argv[1:]))
    print(answer)
    print(f"\n(request id: {request_id})")
