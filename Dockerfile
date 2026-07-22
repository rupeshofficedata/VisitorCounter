# 1. Use the updated, more secure base image recommended by Docker Scout
FROM python:3.13-slim

# 2. Set environment variables to optimize Python for container environments
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# 3. Create a non-root system user and home workspace layout
RUN useradd --create-home --shell /bin/bash appuser

# 4. Set the working directory context
WORKDIR /home/appuser/app

# 5. Leverage Docker layer caching by copying dependencies first
COPY requirements.txt .

# 6. Install required packages safely under the root context
RUN pip install --no-cache-dir -r requirements.txt

# 7. Copy the rest of your application code
COPY . .

# 8. Shift ownership of all copied files to your non-root operator account
RUN chown -R appuser:appuser /home/appuser/app

# 9. Force the runtime environment to drop root access privileges
USER appuser

# 10. Expose your application port (change if your app uses a different port, e.g., 5000 or 8000)
EXPOSE 5000

# 11. Run your visitor counter script
CMD ["python", "app.py"]
