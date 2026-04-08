# NetGuard demo — flawed IaC for [demo-guard](https://github.com/iyertrisha/demo-guard)

This folder is a **self-contained “bad infrastructure” sample** for demos and CI:

- **Large AWS graph**: multiple VPCs/subnets, security groups, EC2 instances, RDS, load balancer, gateways — so the graph engine builds **many nodes and edges** (including `internet → security_group` where ingress allows `0.0.0.0/0`).
- **Intentional misconfigurations** that NetGuard’s risk rules can flag (public SSH/RDP/DB ports, wide-open SG, public S3 settings, unencrypted RDS, permissive IAM, HTTP without HTTPS, etc.).
- **Kubernetes**: `LoadBalancer` service, **privileged** workload, and a namespace spec suitable for **missing NetworkPolicy** Heuristics.

## Remote repository

Push this `demo-guard/` directory to: **https://github.com/iyertrisha/demo-guard**

Suggested first-time setup:

```bash
cd demo-guard
git init
git remote add origin https://github.com/iyertrisha/demo-guard.git
git add .
git commit -m "Add flawed IaC demo for NetGuard"
git branch -M main
git push -u origin main
```

Then open a **pull request** that touches `terraform/*.tf` or `kubernetes/*.yaml` so `.github/workflows/netguard.yml` can POST changed files to your deployed `NETGUARD_API_URL`.

## Scan locally (mini-project)

From the **mini-project** repo root with Docker Compose running:

```bash
python - <<'PY'
import json, pathlib, urllib.request
ROOT = pathlib.Path("demo-guard")
files = []
for p in ROOT.rglob("*"):
    if p.is_file() and p.suffix in {".tf", ".yaml", ".yml"}:
        files.append({
            "filename": str(p.relative_to(ROOT)),
            "content": p.read_text(encoding="utf-8", errors="ignore"),
        })
payload = {
    "repository": "iyertrisha/demo-guard",
    "repository_url": "https://github.com/iyertrisha/demo-guard",
    "pr_number": 1,
    "commit_sha": "local-demo",
    "files": files,
}
req = urllib.request.Request(
    "http://localhost:8000/api/scan",
    data=json.dumps(payload).encode("utf-8"),
    headers={"Content-Type": "application/json"},
    method="POST",
)
print(urllib.request.urlopen(req).read().decode())
PY
```

Then open **http://localhost:5173** and/or `GET /api/scans` on the API.

## Security warning

**Do not apply this Terraform to a real AWS account.** It is for scanning and teaching only.
