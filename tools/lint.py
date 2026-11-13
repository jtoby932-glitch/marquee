#!/usr/bin/env python3
"""Fails on code the brief forbids: try!, fatalError, TODO/FIXME, placeholder copy,
and secrets in tracked files. Warns about files over 300 lines."""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
rules = [
    (re.compile(r"\btry!"), "try! is not allowed"),
    (re.compile(r"\bfatalError\("), "fatalError is not allowed"),
    (re.compile(r"\b(TODO|FIXME|XXX)\b"), "unfinished-work marker"),
    (re.compile(r"(?i)lorem ipsum|coming soon"), "placeholder copy"),
    (re.compile(r"eyJhbGciOiJIUzI1NiJ9\.[A-Za-z0-9_-]{20,}"), "looks like a TMDB token"),
]
errors, warnings = [], []
tracked = subprocess.run(["git", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split()
files = [ROOT / f for f in tracked if f.endswith(".swift")] or list((ROOT / "MARQUEE").rglob("*.swift"))
for path in files:
    if path.name == "Secrets.swift":
        continue
    lines = path.read_text(encoding="utf-8").splitlines()
    rel = path.relative_to(ROOT)
    for i, line in enumerate(lines, 1):
        for pattern, message in rules:
            if pattern.search(line):
                errors.append(f"{rel}:{i}: {message}")
    if len(lines) > 300 and not str(rel).startswith("MARQUEETests"):
        warnings.append(f"{rel}: {len(lines)} lines (aim for under 300)")
for w in warnings:
    print(f"warning: {w}")
for e in errors:
    print(f"error: {e}")
sys.exit(1 if errors else 0)
