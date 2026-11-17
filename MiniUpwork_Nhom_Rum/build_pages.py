"""Build the static GitHub Pages frontend with the deployment's public API URL."""

import argparse
from html import escape
from pathlib import Path
from shutil import copytree
from urllib.parse import urlsplit


WEB = Path(__file__).resolve().parent / "miniupwork" / "web"


def build_pages(api_url: str, output: Path):
    api = urlsplit(api_url.rstrip("/"))
    if (api.scheme != "https" or not api.hostname or api.netloc != api.hostname
            or api.path or api.query or api.fragment
            or api.hostname in {"localhost", "127.0.0.1"}):
        raise ValueError("Use the public HTTPS origin for the FastAPI service, without a path.")
    base = f"https://{api.hostname}"
    output.mkdir(parents=True, exist_ok=True)
    copytree(WEB, output / "ui", dirs_exist_ok=True, ignore=lambda _path, _names: {"index.html"})
    template = (WEB / "index.html").read_text(encoding="utf-8")
    config = f'<meta name="miniupwork-api" content="{escape(base, quote=True)}">'
    policy = (
        "default-src 'none'; script-src 'self'; style-src 'self'; "
        f"font-src 'self'; img-src 'self' data:; connect-src {base}; base-uri 'none'; form-action 'none'"
    )
    csp = f'<meta http-equiv="Content-Security-Policy" content="{escape(policy, quote=True)}">'
    index = template.replace('<meta name="miniupwork-api" content="">', f"{config}\n  {csp}")
    index = index.replace('="/ui/', '="./ui/').replace('href="/docs"', f'href="{base}/docs"')
    (output / "index.html").write_text(index, encoding="utf-8")
    (output / ".nojekyll").touch()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--api-url", required=True)
    parser.add_argument("--output", type=Path, default=Path("pages-build"))
    args = parser.parse_args()
    build_pages(args.api_url, args.output)
