#!/usr/bin/env python3
"""Fail on provider credentials in source or direct provider calls in the client.
Only report locations; never echo a matched secret.
"""
from pathlib import Path
import re
import sys

root = Path(__file__).resolve().parents[1]
findings = []
patterns = [re.compile(r"sk-ant-[A-Za-z0-9_-]{20,}"), re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----")]
for folder in [root / "FitnessApp", root / "FitnessApp.xcodeproj", root / "Backend"]:
    for path in folder.rglob("*"):
        if not path.is_file() or any(part in {"node_modules", ".build", ".git"} for part in path.parts):
            continue
        if path.name.startswith(".env") and path.name != ".env.example":
            if path.is_relative_to(root / "FitnessApp"):
                findings.append(f"{path.relative_to(root)}: environment file must not be inside the app target")
            else:
                continue  # Local secrets are permitted only outside the iOS target.
        try:
            source = path.read_text()
        except (UnicodeError, OSError):
            continue
        for line, text in enumerate(source.splitlines(), 1):
            if any(pattern.search(text) for pattern in patterns):
                findings.append(f"{path.relative_to(root)}:{line}: credential detected")
            if path.is_relative_to(root / "FitnessApp") and re.search(r'Config\.apiKey|CLAUDE_API_KEY|x-api-key|api\.anthropic\.com/v1', text):
                findings.append(f"{path.relative_to(root)}:{line}: direct provider credential path in client")
    for path in folder.rglob("Config.swift"):
        if folder.name == "FitnessApp":
            findings.append(f"{path.relative_to(root)}: legacy secret configuration must not be inside the app target")
if findings:
    print("\n".join(findings), file=sys.stderr)
    sys.exit(1)
print("Credential boundary check passed")
