FROM python:3.11-slim

WORKDIR /app

# Copy requirements and install Python dependencies
# Using oracledb in thin mode - no Oracle Instant Client needed!
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY . .

# Expose port
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]
