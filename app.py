import os
import time
from flask import Flask

USE_REDIS = os.getenv("USE_REDIS", "true").lower() == "true"

if USE_REDIS:
    from redis import Redis
    cache = Redis(host='redis', port=6379, decode_responses=True)
else:
    # Local counter for dev mode
    local_hits = 0

app = Flask(__name__)

def get_hit_count():
    if not USE_REDIS:
        # Increment local counter in dev mode
        global local_hits
        local_hits += 1
        return local_hits

    # Redis mode with retry logic
    retries = 5
    while True:
        try:
            return cache.incr('hits')
        except Exception as exc:
            if retries == 0:
                raise exc
            retries -= 1
            time.sleep(0.5)

@app.route('/')
def hello():
    count = get_hit_count()
    mode = "Redis (prod)" if USE_REDIS else "Local (dev)"
    return f'Hello World! This page has been viewed {count} times. [Mode: {mode}]\n'

@app.route('/healthz')
def healthz():
    return 'OK\n'

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
