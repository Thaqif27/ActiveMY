# Use Python 3.11 with Debian Bookworm (supported by Playwright)
FROM python:3.11-bookworm

# Set working directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install Playwright browsers (only chromium since we only use that)
RUN playwright install chromium --with-deps

# Copy application code
COPY . .

# Expose port (DigitalOcean uses 8080 by default)
ENV PORT=8080
EXPOSE 8080

# Run the API server
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
