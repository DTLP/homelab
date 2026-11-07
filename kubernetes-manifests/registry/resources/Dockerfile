FROM python:3.12-alpine

WORKDIR /app

COPY registry-cache-proxy.py /app/registry-cache-proxy.py

USER 65534:65534

EXPOSE 8081

ENTRYPOINT ["python", "/app/registry-cache-proxy.py"]
