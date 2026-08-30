FROM python:3.12-slim

WORKDIR /app

COPY app.py /app/app.py

EXPOSE 8080

CMD ["python", "/app/app.py", "--host", "0.0.0.0", "--port", "8080"]
