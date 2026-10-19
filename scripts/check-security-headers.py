"""Explicit, read-only checks of response headers on the production portal."""
import argparse
import json
from concurrent.futures import ThreadPoolExecutor
from urllib.error import HTTPError
from urllib.request import Request, urlopen

EXPECTED = {
    "strict-transport-security": "max-age=31536000",
    "x-content-type-options": "nosniff",
    "x-frame-options": "DENY",
    "referrer-policy": "no-referrer",
    "content-security-policy": "base-uri 'none'; object-src 'none'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests",
}
PATHS = ["/", "/admin.html", "/admin", "/portal-sw.js", "/sat-calculator.js", "/portal-navigation.css", "/assets/question-figures/maya-choice-graphs-20261004.png", "/.env"]


def probe(path):
    req = Request("https://math.portal.ghoneem.com" + path, method="HEAD", headers={"User-Agent": "Ghoneem-Security-ReadOnly/1.0", "Cache-Control": "no-cache"})
    try:
        response = urlopen(req, timeout=25)
    except HTTPError as error:
        response = error
    with response:
        actual = {name: response.headers.get(name) for name in EXPECTED}
        binary = path.endswith(".png")
        passed = response.status == (404 if path == "/.env" else 200) and (response.headers.get("Content-Type", "").startswith("image/png") if binary else actual == EXPECTED)
        return {"path": path, "status": response.status, "passed": passed, "scope": "host-served PNG availability" if binary else "all five application headers", "headers": actual}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--allow-live-read-only", required=True, action="store_true")
    parser.parse_args()
    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(probe, PATHS))
    print(json.dumps({"passed": sum(row["passed"] for row in results), "total": len(results), "checks": results}, indent=2))
    raise SystemExit(0 if all(row["passed"] for row in results) else 1)
