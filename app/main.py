import os

import boto3
from fastapi import FastAPI, File, UploadFile

app = FastAPI(title="Taller 5 - Almacenamiento de objetos")

BUCKET_NAME = os.environ["BUCKET_NAME"]
AWS_REGION = os.environ.get("AWS_REGION", "us-east-1")

# Sin claves: boto3 usa automáticamente el rol de la máquina EC2.
s3 = boto3.client("s3", region_name=AWS_REGION)


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/files")
async def upload_file(file: UploadFile = File(...)):
    s3.upload_fileobj(file.file, BUCKET_NAME, file.filename)
    return {"mensaje": "archivo guardado", "nombre": file.filename}


@app.get("/files")
def list_files():
    resp = s3.list_objects_v2(Bucket=BUCKET_NAME)
    archivos = [obj["Key"] for obj in resp.get("Contents", [])]
    return {"bucket": BUCKET_NAME, "archivos": archivos}
