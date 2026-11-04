"""Minimal client for the Boomi Platform (AtomSphere) REST API, standard library only.

Authentication uses an API token: user name "BOOMI_TOKEN.<your login email>" and the token as the password.
Set BOOMI_ACCOUNT_ID, BOOMI_USERNAME (your login email) and BOOMI_API_TOKEN in the environment.
"""

import base64
import json
import os
import urllib.error
import urllib.request

BASE_URL = "https://api.boomi.com/api/rest/v1"


class BoomiError(RuntimeError):
    pass


class BoomiClient:
    def __init__(self, account_id=None, username=None, token=None):
        self.account_id = account_id or os.environ["BOOMI_ACCOUNT_ID"]
        user = f"BOOMI_TOKEN.{username or os.environ['BOOMI_USERNAME']}"
        secret = token or os.environ["BOOMI_API_TOKEN"]
        self._auth = "Basic " + base64.b64encode(f"{user}:{secret}".encode()).decode()

    def post(self, path, body):
        # queryMore takes the bare paging token as text; everything else takes JSON.
        is_text = isinstance(body, str)
        request = urllib.request.Request(
            f"{BASE_URL}/{self.account_id}/{path}",
            data=(body if is_text else json.dumps(body)).encode(),
            headers={
                "Authorization": self._auth,
                "Accept": "application/json",
                "Content-Type": "text/plain" if is_text else "application/json",
            },
            method="POST",
        )
        try:
            with urllib.request.urlopen(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as err:
            raise BoomiError(f"{path}: HTTP {err.code} {err.read().decode(errors='replace')}") from err
