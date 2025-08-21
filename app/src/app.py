import os, json
from flask import Flask

import boto3

app = Flask(__name__)

ENV = os.getenv("APP_ENV", "staging")
PROJECT = os.getenv("PROJECT_NAME", "saas-demo")

@app.get(f"/{ENV}/health")
def health():
    return "ok", 200

@app.get(f"/{ENV}/secret")
def show_secret():
    # Reads secret from AWS Secrets Manager: f"{PROJECT}/app/{ENV}/config"
    name = f"{PROJECT}/app/{ENV}/config"
    client = boto3.client("secretsmanager", region_name=os.getenv("AWS_REGION"))
    try:
        resp = client.get_secret_value(SecretId=name)
        if "SecretString" in resp:
            data = json.loads(resp["SecretString"])
            redacted = {k: "***" for k in data.keys()}
            return {"secret": redacted, "name": name}, 200
        return {"message": "binary secret not displayed"}, 200
    except Exception as e:
        return {"error": str(e), "name": name}, 500
