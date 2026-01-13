FROM public.ecr.aws/docker/library/python:3.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    curl \
    unzip \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI at root
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/awscliv2.zip" \
    && unzip /awscliv2.zip -d / \
    && /aws/install \
    && rm -rf /awscliv2.zip /aws

# Verify AWS CLI installation
RUN aws --version

WORKDIR /app

# Copy requirements and install Python dependencies (includes yt-dlp)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Verify yt-dlp installation
RUN yt-dlp --version

# Copy application code
COPY app.py .

# Create necessary directories
RUN mkdir -p /tmp/yt-downloads /.config

# Expose port
EXPOSE 8080

# Run the Flask app
CMD ["python", "app.py"]
