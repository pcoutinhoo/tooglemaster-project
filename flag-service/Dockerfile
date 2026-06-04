FROM python:3.9 AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


FROM python:3.9-slim
WORKDIR /app
COPY --from=builder /install /usr/local/
COPY . .

RUN useradd -m appuser
USER appuser

EXPOSE 8002
CMD [ "gunicorn", "--bind", "0.0.0.0:8002", "app:app" ]