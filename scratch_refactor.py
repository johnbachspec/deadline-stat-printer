"""Rebuild the compact attachment datasets and report Luau bytecode sizes."""
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
for tool in ("build_attachment_aliases.py", "build_attachment_names.py"):
    result = subprocess.run([sys.executable, str(ROOT / "tools" / tool)], cwd=ROOT)
    if result.returncode:
        raise SystemExit(result.returncode)
result = subprocess.run([sys.executable, str(ROOT / "check_bc.py")], cwd=ROOT)
raise SystemExit(result.returncode)
