#!/usr/bin/env python3
"""Print store automation switch status. Never contacts a store.

Quit All ships on iOS only, so only the IOS_* switches exist. ios_release.py
`gates` is the authority that validates them; this is a readable summary.
"""
from __future__ import annotations

import argparse
import os

GATES = {
    "ios": [
        "IOS_RELEASE_AUTOMATION",
        "IOS_UPLOAD_BUILD",
        "IOS_UPLOAD_LISTING",
        "IOS_UPLOAD_WHATS_NEW",
        "IOS_UPLOAD_SCREENSHOTS",
        "IOS_SUBMIT_REVIEW",
        "IOS_PUBLIC_RELEASE",
    ],
}


def enabled(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=("ios",), default="ios")
    parser.parse_args()

    print("Store automation switches (false = nothing reaches the store):")
    any_on = False
    for name in GATES["ios"]:
        on = enabled(name)
        any_on = any_on or on
        print(f"  {name}={'true' if on else 'false'}")
    for name in ("IOS_BUILD_POLL_SECONDS", "IOS_BUILD_WAIT_MINUTES"):
        print(f"  {name}={os.environ.get(name, '').strip() or 'default'}")
    if not enabled("IOS_RELEASE_AUTOMATION"):
        print("  note: IOS_RELEASE_AUTOMATION is off, so every iOS store operation is skipped")
    if not any_on:
        print("all switches off — no upload, listing change, review submission or release will run")
    else:
        print("WARNING: one or more store switches are on")


if __name__ == "__main__":
    main()
