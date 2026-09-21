import os
import sys
import uvicorn

backend_dir = os.path.join(os.path.dirname(__file__), "backend")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True, app_dir=backend_dir)
