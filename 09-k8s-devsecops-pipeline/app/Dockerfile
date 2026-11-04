# Small, pinned base image; no build tools or shell utilities needed at runtime.
FROM python:3.12.7-slim-bookworm

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Dedicated non-root user with a fixed UID (matches runAsUser in the Deployment).
RUN groupadd --gid 10001 app && useradd --uid 10001 --gid app --no-create-home --shell /usr/sbin/nologin app

WORKDIR /app
COPY --chown=app:app app.py .

USER 10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/healthz')"

ENTRYPOINT ["python", "app.py"]
