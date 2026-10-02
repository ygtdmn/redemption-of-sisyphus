"""Pre-download the Stable Diffusion weights that gen.py loads, for offline use.

gen.py calls StableDiffusionPipeline.from_pretrained("sd-legacy/stable-diffusion-v1-5")
with no revision, which resolves the repo's "main" ref. This script fetches the same
files into the Hugging Face cache and, when a specific commit is requested, points
the cached "main" ref at it so gen.py picks it up unchanged with HF_HUB_OFFLINE=1.

It also writes a manifest (commit + sha256 of every file) so a build can be compared
against another one.
"""

import hashlib
import os
import sys
from pathlib import Path

from diffusers import StableDiffusionPipeline

MODEL_ID = os.environ.get("MODEL_ID", "sd-legacy/stable-diffusion-v1-5")
MODEL_REVISION = os.environ.get("MODEL_REVISION", "main")
MANIFEST = Path(os.environ.get("MODEL_MANIFEST", "/opt/model-manifest.txt"))


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# Same component overrides as gen.py, so the safety checker weights are skipped
snapshot = Path(
    StableDiffusionPipeline.download(
        MODEL_ID,
        revision=MODEL_REVISION,
        safety_checker=None,
        requires_safety_checker=False,
    )
)
commit = snapshot.name

refs_main = snapshot.parent.parent / "refs" / "main"
if MODEL_REVISION != "main":
    refs_main.parent.mkdir(parents=True, exist_ok=True)
    refs_main.write_text(commit)

lines = [f"model: {MODEL_ID}", f"revision: {commit}", ""]
for path in sorted(p for p in snapshot.rglob("*") if p.is_file()):
    lines.append(f"{sha256_file(path)}  {path.relative_to(snapshot)}")
MANIFEST.write_text("\n".join(lines) + "\n")

print(MANIFEST.read_text())
if MODEL_REVISION not in ("main", commit):
    sys.exit(f"requested revision {MODEL_REVISION} resolved to unexpected commit {commit}")
