import csv
import io
import os
import uuid
from pathlib import Path
from typing import Dict, List, Optional

import boto3
from botocore.client import Config
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

router = APIRouter(tags=["pipeline"])

STORAGE = Path(os.getenv("STORAGE_DIR", "/app/storage"))
UP = STORAGE / "uploads"
WORK = STORAGE / "work"
for d in (UP, WORK):
    d.mkdir(parents=True, exist_ok=True)

class ReplaceRule(BaseModel):
    column: str
    replace: Dict[str, str]

class ConcatRule(BaseModel):
    target: str
    cols: List[str]
    sep: str = " "

class MapRequest(BaseModel):
    dataset_id: str
    replace_rules: Optional[List[ReplaceRule]] = None
    concat_rules: Optional[List[ConcatRule]] = None

class ExportRequest(BaseModel):
    work_id: str

def _save_uploaded_csv(fbytes: bytes, delimiter: str, encoding: str) -> Dict:
    dataset_id = str(uuid.uuid4())
    p = UP / f"{dataset_id}.csv"
    p.write_bytes(fbytes)
    # sample
    f = io.StringIO(fbytes.decode(encoding, errors="replace"))
    reader = csv.reader(f, delimiter=delimiter)
    rows = list(reader)
    headers = rows[0] if rows else []
    sample = rows[1:6] if len(rows) > 1 else []
    return {"dataset_id": dataset_id, "headers": headers, "sample": sample}

def _apply_mapping(dataset_id: str,
                   replace_rules: List[ReplaceRule] | None,
                   concat_rules: List[ConcatRule] | None) -> Dict:
    src = UP / f"{dataset_id}.csv"
    if not src.exists():
        raise HTTPException(404, "dataset not found")
    work_id = str(uuid.uuid4())
    dst = WORK / f"{work_id}.csv"

    with src.open("r", encoding="utf-8", newline="") as rf, dst.open("w", encoding="utf-8", newline="") as wf:
        reader = csv.DictReader(rf)
        fieldnames = list(reader.fieldnames or [])
        if concat_rules:
            for r in concat_rules:
                if r.target not in fieldnames:
                    fieldnames.append(r.target)
        writer = csv.DictWriter(wf, fieldnames=fieldnames)
        writer.writeheader()
        for row in reader:
            if replace_rules:
                for rr in replace_rules:
                    if rr.column in row and row[rr.column] in rr.replace:
                        row[rr.column] = rr.replace[row[rr.column]]
            if concat_rules:
                for cr in concat_rules:
                    row[cr.target] = cr.sep.join(str(row.get(c, "")) for c in cr.cols)
            writer.writerow(row)

    with dst.open("r", encoding="utf-8", newline="") as f:
        reader = csv.reader(f)
        rows = list(reader)
    headers = rows[0] if rows else []
    sample = rows[1:6] if len(rows) > 1 else []
    return {"work_id": work_id, "headers": headers, "sample": sample}

def _s3_client():
    endpoint = os.getenv("S3_ENDPOINT")
    key = os.getenv("S3_ACCESS_KEY")
    secret = os.getenv("S3_SECRET_KEY")
    region = os.getenv("S3_REGION", "us-east-1")
    if not (endpoint and key and secret):
        raise HTTPException(500, "S3 not configured")
    return boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=key,
        aws_secret_access_key=secret,
        region_name=region,
        config=Config(s3={"addressing_style": "path"}),  # MinIO + localhost => path-style
    )

@router.post("/import/csv")
async def import_csv(file: UploadFile = File(...), delimiter: str = Form(","), encoding: str = Form("utf-8")):
    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(400, "only .csv accepted")
    fbytes = await file.read()
    return _save_uploaded_csv(fbytes, delimiter, encoding)

@router.post("/aps/map")
async def aps_map(req: MapRequest):
    return _apply_mapping(req.dataset_id, req.replace_rules or [], req.concat_rules or [])

@router.post("/export/dryrun")
async def export_dryrun(req: ExportRequest):
    p = WORK / f"{req.work_id}.csv"
    if not p.exists():
        raise HTTPException(404, "work not found")
    bucket = os.getenv("S3_BUCKET", "amp-tenants")
    key = f"dryrun/{req.work_id}.csv"
    s3 = _s3_client()
    s3.upload_file(str(p), bucket, key)
    url = s3.generate_presigned_url(
        ClientMethod="get_object",
        Params={"Bucket": bucket, "Key": key},
        ExpiresIn=3600,
    )
    return {"bucket": bucket, "key": key, "presigned_url": url}
