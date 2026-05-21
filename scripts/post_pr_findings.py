#!/usr/bin/env python3
"""
NetGuard CI helper: POST /api/scan, build enhanced PR summary comment,
optionally post GitHub inline review comments on changed files.

Triggered automatically on every PR open/update by the netguard.yml workflow.
Scans ALL .tf/.yaml/.yml files tracked in the PR branch (full topology context).

Expects GitHub Actions env (IAC_FILES, PR_NUMBER, NETGUARD_API_URL, ...).
Writes comment_body, blocking, scan_id to GITHUB_OUTPUT for downstream steps.
"""

from __future__ import annotations

import hashlib
import hmac
import json
import os
import sys
import urllib.error
import urllib.request


def _normalize_netguard_api_base(raw: str) -> str:
    """
    GitHub secret should be the FastAPI origin only, e.g.
    https://abcd.ngrok-free.app  (ngrok -> localhost:8000)

    If callers include a trailing /api, POST would hit /api/api/scan (404).
    """
    u = raw.strip().rstrip("/")
    if u.lower().endswith("/api"):
        u = u[:-4].rstrip("/")
    return u


def _github_api_json(method: str, url: str, token: str, payload: dict | None = None) -> tuple[int, dict | list]:
    data = None
    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": f"Bearer {token}",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if payload is not None:
        data = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            body = resp.read().decode("utf-8")
            code = resp.status
            if not body:
                return code, {}
            return code, json.loads(body)
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        print(f"GitHub API error {e.code}: {err_body}", file=sys.stderr)
        raise


def _list_pr_filenames(owner: str, repo: str, pr_number: int, token: str) -> set[str]:
    names: set[str] = set()
    page = 1
    while True:
        url = (
            f"https://api.github.com/repos/{owner}/{repo}/pulls/"
            f"{pr_number}/files?per_page=100&page={page}"
        )
        code, batch = _github_api_json("GET", url, token)
        if code != 200:
            break
        if not isinstance(batch, list) or not batch:
            break
        for item in batch:
            fn = item.get("filename")
            if fn:
                names.add(fn)
        if len(batch) < 100:
            break
        page += 1
    return names


def _truncate(text: str, max_len: int = 240) -> str:
    t = " ".join(text.split())
    if len(t) <= max_len:
        return t
    return t[: max_len - 1] + "…"


def main() -> int:
    github_output = os.environ["GITHUB_OUTPUT"]

    # IAC_FILES: newline-separated list of all .tf/.yaml/.yml paths in the PR
    # branch (set by the workflow's "Collect all IaC files" step).
    # Fall back to legacy CHANGED_FILES for local testing / backwards compat.
    raw_file_list = os.environ.get("IAC_FILES") or os.environ.get("CHANGED_FILES", "")
    all_paths = [p.strip() for p in raw_file_list.strip().splitlines() if p.strip()]

    if not all_paths:
        print("No IaC files found in this branch — nothing to scan.", file=sys.stderr)
        # Write safe no-op outputs so downstream steps don't fail.
        with open(github_output, "a", encoding="utf-8") as out:
            out.write("comment_body<<EOF\nNo IaC files (.tf/.yaml/.yml) found in this branch.\nEOF\n")
            out.write("blocking=false\n")
            out.write("scan_id=\n")
        return 0

    files = []
    missing: list[str] = []
    for path in all_paths:
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as fh:
                files.append({"filename": path, "content": fh.read()})
        except OSError as exc:
            missing.append(f"{path}: {exc}")

    if missing:
        print(
            f"Warning: {len(missing)} IaC file(s) could not be read (deleted/renamed?):\n"
            + "\n".join(missing),
            file=sys.stderr,
        )

    if not files:
        print("All listed IaC files were unreadable — aborting scan.", file=sys.stderr)
        raise SystemExit(2)

    repository = os.environ["GITHUB_REPOSITORY"]
    pr_number = int(os.environ["PR_NUMBER"])
    commit_sha = os.environ["GITHUB_SHA"]

    netguard_api_key = os.environ.get("NETGUARD_API_KEY", "").strip()
    payload = {
        "repository": repository,
        "repository_url": f"https://github.com/{repository}",
        "pr_number": pr_number,
        "commit_sha": commit_sha,
        "files": files,
    }
    if netguard_api_key:
        # Embedded inside the signed body so HMAC covers it; the API resolves
        # the org from this key when X-NetGuard-Signature is valid.
        payload["api_key"] = netguard_api_key
    payload_bytes = json.dumps(payload).encode("utf-8")
    secret = os.environ.get("NETGUARD_SECRET", "")
    signature = hmac.new(secret.encode("utf-8"), payload_bytes, hashlib.sha256).hexdigest()

    raw_base = os.environ["NETGUARD_API_URL"]
    api_base = _normalize_netguard_api_base(raw_base)
    scan_url = f"{api_base}/api/scan"
    req = urllib.request.Request(
        scan_url,
        data=payload_bytes,
        headers={
            "Content-Type": "application/json",
            "X-NetGuard-Signature": f"sha256={signature}",
            "ngrok-skip-browser-warning": "1",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            result = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8", errors="replace")
        hints = (
            "Check GitHub secret NETGUARD_API_URL: it must be only the API origin "
            "(no trailing /api), with ngrok tunnel pointing to port 8000. "
            "GET {origin}/health should return {\"status\":\"ok\",\"service\":\"api\"}."
        )
        if e.code == 401:
            hints = (
                "401 = HMAC signature mismatch. Ensure NETGUARD_SECRET in GitHub "
                "Actions secrets is byte-for-byte identical to the NETGUARD_SECRET "
                "in the API host's .env file, then restart uvicorn."
            )
        elif e.code == 404:
            hints = (
                "404 = Route not found. Confirm NETGUARD_API_URL is origin-only "
                "(no /api suffix) and ngrok forwards to port 8000 (the FastAPI host)."
            )
        print(
            f"NetGuard API request failed: POST {scan_url} -> HTTP {e.code}\n"
            f"Response body (truncated): {err_body[:2000]}\n"
            f"Hint: {hints}",
            file=sys.stderr,
        )
        raise SystemExit(2) from e

    summary = result.get("summary", {})
    resolution = result.get("resolution_summary", {})
    prefix = (
        f"{resolution.get('resolved_findings', 0)} findings resolved, "
        f"{resolution.get('new_findings', 0)} new finding(s)"
    )

    scan_id = result.get("scan_id")
    ui_base = os.environ.get(
        "NETGUARD_UI_URL",
        raw_base.replace(":8000", ":5173"),
    )

    lines = [
        "## NetGuard Scan Results",
        "",
        f"**{prefix}**",
        "",
        f"- Total findings: {summary.get('total', 0)}",
        f"- Critical: {summary.get('critical', 0)}",
        f"- High: {summary.get('high', 0)}",
        f"- Medium: {summary.get('medium', 0)}",
        f"- Low: {summary.get('low', 0)}",
        "",
    ]

    findings: list[dict] = []
    if scan_id is not None:
        scan_headers = {"ngrok-skip-browser-warning": "1"}
        if netguard_api_key:
            scan_headers["X-API-Key"] = netguard_api_key
        scan_req = urllib.request.Request(
            f"{api_base}/api/scans/{scan_id}",
            method="GET",
            headers=scan_headers,
        )
        try:
            with urllib.request.urlopen(scan_req, timeout=60) as sr:
                scan_body = json.loads(sr.read().decode("utf-8"))
                findings = scan_body.get("findings") or []
        except urllib.error.HTTPError as e:
            print(f"Warning: could not fetch scan details: {e}", file=sys.stderr)

    if findings:
        lines.append("### Findings")
        lines.append("")
        for frow in findings:
            sev = frow.get("severity", "")
            ftype = frow.get("finding_type", "")
            gh_url = frow.get("github_url")
            sf = frow.get("source_file")
            sl = frow.get("source_line")
            details = frow.get("details") if isinstance(frow.get("details"), dict) else {}
            expl = details.get("explanation") or ""
            link_part = ""
            if gh_url and sf is not None and sl is not None:
                link_part = f" — [{sf}:{sl}]({gh_url})"
            elif sf is not None and sl is not None:
                link_part = f" — `{sf}:{sl}`"
            lines.append(
                f"- **{sev}** {ftype}{link_part} — {_truncate(expl)}"
            )
        lines.append("")

    lines.append(
        f"[View findings]({ui_base}/scans/{scan_id}) | "
        f"[View topology graph]({ui_base}/scans/{scan_id}/graph)"
    )

    body = "\n".join(lines)

    blocking = str(result.get("blocking", False)).lower()
    with open(github_output, "a", encoding="utf-8") as out:
        out.write(f"comment_body<<EOF\n{body}\nEOF\n")
        out.write(f"blocking={blocking}\n")
        out.write(f"scan_id={scan_id}\n")

    token = os.environ.get("GITHUB_TOKEN", "").strip()
    owner, repo = repository.split("/", 1)
    pr_filenames: set[str] | None = None
    if token and findings:
        try:
            pr_filenames = _list_pr_filenames(owner, repo, pr_number, token)
        except Exception as exc:
            print(f"Warning: could not list PR files for inline comments: {exc}", file=sys.stderr)
            pr_filenames = None

    if token and pr_filenames is not None and findings:
        comments_url = f"https://api.github.com/repos/{repository}/pulls/{pr_number}/comments"
        for frow in findings:
            sf = frow.get("source_file")
            sl = frow.get("source_line")
            if not sf or sl is None:
                continue
            if sf not in pr_filenames:
                continue
            details = frow.get("details") if isinstance(frow.get("details"), dict) else {}
            expl = details.get("explanation") or ""
            rem = details.get("remediation") or ""
            sev = frow.get("severity", "")
            ftype = frow.get("finding_type", "")
            comment_body = (
                f"**[{sev}] {ftype}**\n\n{expl}\n\n"
                f"**Remediation:** {rem}"
            )
            payload_j = {
                "body": comment_body,
                "commit_id": commit_sha,
                "path": sf,
                "line": int(sl),
                "side": "RIGHT",
            }
            try:
                code, _ = _github_api_json("POST", comments_url, token, payload_j)
                if code not in (200, 201):
                    print(f"Warning: unexpected status posting inline comment: {code}", file=sys.stderr)
            except Exception as exc:
                print(f"Warning: inline comment failed for {sf}:{sl}: {exc}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
