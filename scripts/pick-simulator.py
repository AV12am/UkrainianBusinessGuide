#!/usr/bin/env python3
"""Друкує UDID найновішого доступного симулятора iPhone (вхід — `xcrun simctl list devices available -j`)."""
import json
import re
import sys

devices = json.load(sys.stdin)["devices"]
candidates = []
for runtime, items in devices.items():
    match = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not match:
        continue
    version = (int(match.group(1)), int(match.group(2)))
    for device in items:
        if device.get("isAvailable") and device["name"].startswith("iPhone"):
            # Базові моделі без Pro/Max/Plus/SE — стандартний розмір екрана для скриншотів.
            plain = not re.search(r"Pro|Max|Plus|SE|Air|mini", device["name"])
            candidates.append((version, plain, device["name"], device["udid"]))

if not candidates:
    sys.exit("Не знайдено жодного симулятора iPhone")
candidates.sort()
version, _, name, udid = candidates[-1]
print(f"Симулятор: {name} (iOS {version[0]}.{version[1]})", file=sys.stderr)
print(udid)
