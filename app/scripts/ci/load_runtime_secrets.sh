#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${WORKSPACE}/.vault_env"
: > "${ENV_FILE}"
chmod 644 "${ENV_FILE}"

if [[ -z "${VAULT_ADDR:-}" || -z "${VAULT_ROLE_ID:-}" || -z "${VAULT_SECRET_ID:-}" ]]; then
  echo "Vault env vars not fully set. Using Jenkins credentials fallback."
  exit 0
fi

python3 - <<'PY'
import json
import os
import shlex
import sys
import urllib.request

vault_addr = os.environ.get("VAULT_ADDR", "").rstrip("/")
role_id = os.environ.get("VAULT_ROLE_ID", "")
secret_id = os.environ.get("VAULT_SECRET_ID", "")
namespace = os.environ.get("VAULT_NAMESPACE", "")
env_file = os.path.join(os.environ["WORKSPACE"], ".vault_env")

def req(method, path, payload=None, token=None):
    url = f"{vault_addr}{path}"
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    headers = {"Content-Type": "application/json"}
    if namespace:
        headers["X-Vault-Namespace"] = namespace
    if token:
        headers["X-Vault-Token"] = token
    r = urllib.request.Request(url, data=data, headers=headers, method=method)
    with urllib.request.urlopen(r, timeout=20) as resp:
        return json.loads(resp.read().decode("utf-8"))

def first_value(d, keys):
    for k in keys:
        v = d.get(k)
        if v:
            return str(v)
    return ""

try:
    login = req("POST", "/v1/auth/approle/login", {"role_id": role_id, "secret_id": secret_id})
    client_token = login["auth"]["client_token"]

    dh = req("GET", "/v1/kv/data/dev/jenkins/dockerhub", token=client_token)["data"]["data"]
    gl = req("GET", "/v1/kv/data/dev/jenkins/gitlab-token", token=client_token)["data"]["data"]

    dh_user = first_value(dh, ["username", "user", "dh_user"])
    dh_token = first_value(dh, ["token", "password", "dh_token"])
    gl_user = first_value(gl, ["username", "user", "gl_user"])
    gl_token = first_value(gl, ["token", "password", "gl_token"])

    with open(env_file, "w", encoding="utf-8") as f:
        if dh_user:
            f.write(f"export VAULT_DH_USER={shlex.quote(dh_user)}\\n")
        if dh_token:
            f.write(f"export VAULT_DH_TOKEN={shlex.quote(dh_token)}\\n")
        if gl_user:
            f.write(f"export VAULT_GL_USER={shlex.quote(gl_user)}\\n")
        if gl_token:
            f.write(f"export VAULT_GL_TOKEN={shlex.quote(gl_token)}\\n")

    print("Loaded runtime secrets from Vault.")
except Exception as exc:
    print(f"Vault fetch failed, using Jenkins credentials fallback: {exc}")
    with open(env_file, "w", encoding="utf-8") as f:
        f.write("")
    sys.exit(0)
PY
