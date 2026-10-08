#!/usr/bin/env python3
"""Guard the shipping target against reintroducing remote services or backend files.

This is a regression guard for this app's local-only boundary, not a complete
network/security audit. Apple Health and opening iOS Settings remain permitted.
Pass --app-bundle after a release build to inspect the actual shipped contents.
"""
import argparse
from pathlib import Path
import plistlib
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_SOURCE = re.compile(
    r"\b(?:URLSession\w*|URLRequest|URLProtocol|NSURLConnection|NWConnection|"
    r"NWListener|CFHTTPMessage\w*|SecItem\w*|ClaudeService|ClaudeError|"
    r"WorkoutAnalyticsService|TargetedWorkoutView|FitnessAIEndpoint)\b|"
    r"\bimport\s+(?:Network|FoundationNetworking|WebKit|Security)\b|"
    r"https?://|anthropic|fitness-ai|gateway-access-token",
    re.IGNORECASE,
)
FORBIDDEN_BINARY = (
    b"ClaudeService", b"ClaudeError", b"WorkoutAnalyticsService",
    b"TargetedWorkoutView", b"FitnessAIEndpoint", b"api.anthropic.com",
    b"fitness-ai", b"gateway-access-token", b"URLSession",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-bundle", type=Path, help="Built .app directory")
    args = parser.parse_args()
    findings = []

    for path in (ROOT / "FitnessApp").rglob("*.swift"):
        for line, source in enumerate(path.read_text().splitlines(), 1):
            if FORBIDDEN_SOURCE.search(source):
                findings.append(f"{path.relative_to(ROOT)}:{line}: remote-service code in local-only target")

    project = ROOT / "FitnessApp.xcodeproj/project.pbxproj"
    if re.search(r"\bBackend\b|gateway\.mjs|FitnessAIEndpoint", project.read_text()):
        findings.append("FitnessApp.xcodeproj: backend or gateway must not be included in the app target")

    for path in (ROOT / "FitnessApp").rglob("*"):
        if not path.is_file():
            continue
        if "Backend" in path.parts or path.name.startswith(".env") or path.suffix in {".mjs", ".js"}:
            findings.append(f"{path.relative_to(ROOT)}: server/configuration file in the app target")

    with (ROOT / "FitnessApp/Info.plist").open("rb") as file:
        info = plistlib.load(file)
    if "FitnessAIEndpoint" in info or "NSAppTransportSecurity" in info:
        findings.append("FitnessApp/Info.plist: unexpected remote-service configuration")
    with (ROOT / "FitnessApp/PrivacyInfo.xcprivacy").open("rb") as file:
        privacy = plistlib.load(file)
    if privacy.get("NSPrivacyTracking") or privacy.get("NSPrivacyTrackingDomains") or privacy.get("NSPrivacyCollectedDataTypes"):
        findings.append("FitnessApp/PrivacyInfo.xcprivacy: local-only app must not declare remote collection or tracking")

    if args.app_bundle:
        bundle = args.app_bundle.resolve()
        if not bundle.is_dir() or bundle.suffix != ".app":
            findings.append("App bundle: provide an existing .app directory")
        else:
            with (bundle / "Info.plist").open("rb") as file:
                built_info = plistlib.load(file)
            if "FitnessAIEndpoint" in built_info or "NSAppTransportSecurity" in built_info:
                findings.append("App bundle: unexpected remote-service configuration")
            executable = bundle / built_info["CFBundleExecutable"]
            contents = executable.read_bytes()
            if any(marker in contents for marker in FORBIDDEN_BINARY):
                findings.append("App executable: remote-service implementation remains")
            for path in bundle.rglob("*"):
                if not path.is_file():
                    continue
                relative = path.relative_to(bundle)
                if "Backend" in relative.parts or path.name.startswith(".env") or path.suffix in {".mjs", ".js"}:
                    findings.append(f"App bundle/{relative}: server/configuration file is bundled")

    if findings:
        print("\n".join(findings), file=sys.stderr)
        return 1
    print("Local-only source" + (" and app bundle" if args.app_bundle else "") + " check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
