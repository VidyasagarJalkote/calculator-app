# DevOps Calculator

A small Flask calculator (HTML + CSS + Python) used to demonstrate a complete DevOps pipeline.

**Flow:** `git push` → GitHub Actions runs tests (CI) → builds Docker image → pushes to Amazon ECR → deploys to Amazon ECS Express Mode (Fargate + load balancer) (CD).

Run locally: `pip install -r requirements-dev.txt && pytest && python app.py` → http://localhost:8080
