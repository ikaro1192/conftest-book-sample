FROM public.ecr.aws/docker/library/python:3.13-slim
WORKDIR /app
COPY requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt
COPY report/ ./report/
USER 10001
ENTRYPOINT ["python", "-m", "report"]
