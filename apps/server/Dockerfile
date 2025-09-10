FROM python:3.11-slim
WORKDIR /app
COPY pyproject.toml /app/pyproject.toml
RUN pip install --no-cache-dir -U pip && \
    pip install --no-cache-dir fastapi uvicorn boto3 python-multipart sqlalchemy psycopg[binary] pydantic
COPY app /app/app
EXPOSE 8080
CMD ["uvicorn", "app.main:app", "--host","0.0.0.0","--port","8080"]
