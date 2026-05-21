# Report screenshots checklist (§9.1 Result Snapshots)

Use PR **`report/section-9-result-snapshots`** against `main` so GitHub Actions runs NetGuard on this repo.

After the workflow finishes, capture:

1. **Scan Result — CRITICAL blocking**
   - GitHub PR **Checks** tab: failed NetGuard job with merge blocked message.
   - PR **comment** from NetGuard listing CRITICAL `SSH_EXPOSED_TO_PUBLIC`, file path, line.

2. **Scan Result — Autofix proposal**
   - NetGuard UI → Scan detail → **Suggest fix** on `SSH_EXPOSED_TO_PUBLIC` → validated diff + optional **Post to GitHub PR**.

3. **Dashboard view**
   - Summary cards + recent scans table (blocking indicator if applicable).

4. **Graph visualization**
   - Scan graph → click **`web-server`** node → blast radius / inspection panel.

5. **Multi-query scan**
   - Same PR workflow log timing / summary counts from the NetGuard comment body.

Terraform intentionally adds **`report_ssh_blocking.tf`** (SSH `0.0.0.0/0`) and tags the demo EC2 **`web-server`** for graph labels aligned with the report narrative.
