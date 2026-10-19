"""Opt-in, read-only probes of the existing portal. Never run by offline CI."""
import argparse
import json
import re
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen
from concurrent.futures import ThreadPoolExecutor


def request(url, method="GET", headers=None, body=None):
    req = Request(url, data=body, headers={"User-Agent": "Ghoneem-Security-ReadOnly/1.0", **(headers or {})}, method=method)
    try:
        with urlopen(req, timeout=20) as response:
            return response.status, response.headers, response.read()
    except HTTPError as error:
        return error.code, error.headers, error.read()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-live-read-only", action="store_true", required=True)
    parser.parse_args()
    source = Path("web/index.html").read_text()
    api = re.search(r"const SB_URL = '([^']+)'", source)[1]
    key = re.search(r"const SB_KEY = '([^']+)'", source)[1]
    assert api == "https://wfhurjyouemahvkcfkdz.supabase.co"
    origin = "https://math.portal.ghoneem.com"
    results = []

    def record(name, condition, status):
        results.append({"check": name, "passed": bool(condition), "status": status})

    for path in ["/", "/admin.html", "/.env", "/.git/config"]:
        status, _, _ = request(origin + path)
        record(path, status == (404 if path.startswith("/.") else 200), status)
    headers = {"apikey": key, "Content-Type": "application/json", "Origin": origin}
    for table in ["profiles", "question_keys", "attempt_answers", "course_payments"]:
        status, _, _ = request(api + "/rest/v1/" + table + "?select=*&limit=0", headers=headers)
        record("anonymous table denied: " + table, status in (401, 403), status)
    for name, body in [("admin_bank_page", {"p_track": "sat"}), ("staff_diagnosis", {"p_track": "sat"})]:
        status, _, _ = request(api + "/rest/v1/rpc/" + name, "POST", headers, json.dumps(body).encode())
        record("anonymous RPC denied: " + name, status in (401, 403), status)
    endpoints = [("me-tracks","GET"), ("start-attempt","POST"), ("submit-attempt","POST"), ("attempt-review","GET"), ("grant-retake","POST"), ("admin-users","POST"), ("enrollments","POST"), ("staff-console","POST"), ("daily-challenge","POST"), ("admin-delete-user","POST"), ("final-revision","POST"), ("portal-controls","POST"), ("exam-activity","POST"), ("student-groups","POST")]
    def probe_endpoint(endpoint):
        name, method = endpoint
        for token in [None, "invalid-security-probe"]:
            h = {**headers, **({"Authorization": "Bearer " + token} if token else {})}
            status, _, _ = request(api + "/functions/v1/" + name, method, h, b"{}" if method == "POST" else None)
            record(("invalid-token" if token else "unauthenticated") + " function denied: " + name, status in (401, 403), status)
    with ThreadPoolExecutor(max_workers=5) as pool:
        list(pool.map(probe_endpoint, endpoints))
    # OPTIONS and auth status only: no notification worker/test action is invoked.
    for supplied, allowed in [(origin, True), (origin + ".evil.invalid", False)]:
        status, response_headers, _ = request(api + "/functions/v1/me-tracks", "OPTIONS", {"Origin": supplied})
        actual = response_headers.get("Access-Control-Allow-Origin")
        record("CORS " + ("allowed" if allowed else "lookalike denied"), actual == supplied if allowed else actual is None, status)
    print(json.dumps({"checks": results, "passed": sum(r["passed"] for r in results), "total": len(results)}, indent=2))
    if not all(r["passed"] for r in results):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
