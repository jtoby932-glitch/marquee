#!/usr/bin/env python3
"""Prints the UDID of an available iPhone simulator on the newest iOS runtime.

Usage: pick_simulator.py [standard|small|max]
  standard  a regular iPhone (default)
  small     the smallest available (SE size, else mini, else 16e)
  max       the largest Pro Max
"""
import json
import re
import subprocess
import sys

size = sys.argv[1] if len(sys.argv) > 1 else "standard"
data = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"]))
devices = []
for runtime, entries in data["devices"].items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in entries:
        if device.get("isAvailable", True) and device["name"].startswith("iPhone"):
            devices.append((version, device["name"], device["udid"]))
if not devices:
    raise SystemExit("No iPhone simulator available")


def number(name):
    found = re.search(r"iPhone (\d+)", name)
    return int(found.group(1)) if found else 0


def score(entry):
    version, name, _ = entry
    if size == "small":
        rank = 3 if "SE" in name else 2 if "mini" in name else 1 if re.search(r"\d+e\b", name) else 0
        return (rank, version, number(name))
    if size == "max":
        return ("Pro Max" in name, version, number(name))
    plain = not any(word in name for word in ("Max", "Plus", "SE", "mini", "Pro", "Air")) and not re.search(r"\d+e\b", name)
    return (version, plain, number(name))


best = max(devices, key=score)
print(best[2])
print(f"picked {best[1]} (iOS {best[0][0]}.{best[0][1]}) for {size}", file=sys.stderr)
