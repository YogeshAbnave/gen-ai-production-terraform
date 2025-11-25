# Use a stable Python 3.9 slim image
FROM python:3.9-slim


# Environment variables
# ENV PYTHONDONTWRITEBYTECODE=1
# ENV PYTHONUNBUFFERED=1

# Optional: Use alternate PyPI mirror if default is slow
# ENV PIP_INDEX_URL=https://pypi.tuna.tsinghua.edu.cn/simple/
# ENV PIP_EXTRA_INDEX_URL=https://pypi.org/simple/

# Expose Streamlit port
EXPOSE 8501

# Set working directory
WORKDIR /app

# Copy requirements first (better layer caching)
COPY requirements.txt .

# Install dependencies with retries & timeout
RUN pip install --upgrade pip && \
    pip install --no-cache-dir \
    --timeout=100 \
    --retries=5 \
    -r requirements.txt
    # --index-url https://pypi.tuna.tsinghua.edu.cn/simple/

# Copy application files
COPY Home.py .
COPY components ./components
COPY pages ./pages

# Create non-root user and set permissions
RUN useradd -u 8877 clouduser && \
    chown -R clouduser:clouduser /app && \
    chmod -R 755 /app

USER clouduser

# Run Streamlit app
CMD ["streamlit", "run", "Home.py", \
     "--server.headless=true", \
     "--server.address=0.0.0.0", \
     "--server.enableCORS=false", \
     "--browser.gatherUsageStats=false"]
