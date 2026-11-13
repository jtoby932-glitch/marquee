#!/usr/bin/env python3
"""Prints the CHANGELOG.md section for one version, for GitHub release notes."""
import sys
from pathlib import Path

version = sys.argv[1]
text = (Path(__file__).resolve().parent.parent / "CHANGELOG.md").read_text()
out, capture = [], False
for line in text.splitlines():
    if line.startswith("## "):
        if capture:
            break
        capture = line[3:].strip().startswith(version)
        continue
    if capture:
        out.append(line)
print("\n".join(out).strip() or f"MARQUEE {version}")
