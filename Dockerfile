FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /docs

COPY requirements.txt .
RUN pip install --no-cache-dir --requirement requirements.txt

COPY mkdocs.yml .
COPY docs ./docs

EXPOSE 8000

CMD ["mkdocs", "serve", "--dev-addr=0.0.0.0:8000"]
