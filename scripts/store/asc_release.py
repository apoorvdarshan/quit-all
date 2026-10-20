#!/usr/bin/env python3
"""App Store Connect listing, What's New, screenshots, creative assets and submit-for-review (gated in CI).

Every App Store Connect call goes through the pinned App Store Connect CLI
(`asc`, see asc_cli.py); this script decides what may change and checks the
results.

The listing lives in the repo (store/metadata/ios/<locale>/): every locale
directory there is uploaded, and App Store Connect must already have that
locale on the version. App info fields (name, subtitle, privacy URL) are kept
for reference only and are not uploaded.

Metadata steps are idempotent: the live text, screenshots and creative assets
are read first and only what differs is written. A rerun therefore also works
after a review submission was started (READY_FOR_REVIEW still takes text
changes, not screenshots or creative assets) or completed (WAITING_FOR_REVIEW
takes no changes): it passes when the metadata is already in place and fails,
before any write, when a change would be needed.

Product page creative assets (IOS_UPLOAD_CREATIVE_ASSETS) come from
store/creative/ios/header/ and store/creative/ios/search-results/. A new image
is uploaded to the Asset Library and sent to App Review in a submission of its
own; once Apple approves it, a later run places it on every listing locale of
the version, or swaps it in for the image placed there.

Submitting for review covers both the App Store version and any Ready-to-Submit
in-app purchases or subscriptions listed in store/catalog/products.json. They
are attached to the same draft review submission as the version (through their
current `subscriptionVersions` / `inAppPurchaseVersions`), so everything goes
to App Review with one submit, after the final build recheck, and only while
the draft holds nothing but this version and versions of catalog products. (A
rerun that finds the version already waiting for review with this run's build
sends a late product in a product-only draft.) A first-time subscription must
go out with the version or App Review rejects the build.

`--create-version` (IOS_CREATE_VERSION) runs first on a release run: it adds the
App Store version for the tag when App Store Connect does not have it yet, and
leaves an existing one alone. It refuses when another version is still on its
way to the store or the tag's version is not newer than every existing one.

`--preflight` runs before anything is built: read-only checks (asc runs with
ASC_READ_ONLY, so it refuses any write) that the App Store version exists, is
in a state the enabled switches can use, and has every repository locale, so a
release fails before it uploads."""
from __future__ import annotations

import argparse
import contextlib
import hashlib
import io
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Any

sys.path.insert(0, str(Path(__file__).resolve().parent))
import asc_cli  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_BUNDLE_ID = "com.apoorvdarshan.Quit-All"
# App Store Connect app record for DEFAULT_BUNDLE_ID. Every run checks that this
# record carries exactly that bundle id before touching anything.
ASC_APP_ID = "6760978934"
PLATFORM = "IOS"
METADATA_DIR = ROOT / "store" / "metadata"
CATALOG = ROOT / "store" / "catalog" / "products.json"
CREATIVE_DIR = ROOT / "store" / "creative" / "ios"

# App Store Connect allows 10 screenshots per display type. Portrait sizes the
# pinned asc uploads for each display type this app uses (asc refuses any other
# size before uploading, so 1284x2778 belongs to the 6.5" set only).
SCREENSHOT_SET_MAX = 10
SCREENSHOT_SIZES = {
    "APP_IPHONE_67": {(1260, 2736), (1290, 2796), (1320, 2868)},
    "APP_IPHONE_65": {(1242, 2688), (1284, 2778)},
}
SCREENSHOT_MANIFEST = "screenshots.json"
WHATS_NEW_VERSION_FILE = "whats_new_version.txt"

# Product page creative assets: the folder under --creative-dir, the placement
# type, and a label for logs. Each folder holds at most one image.
CREATIVE_SLOTS = (
    ("header", "PRODUCT_PAGE_HEADER_ASSET", "product page header"),
    ("search-results", "APP_STORE_SEARCH_RESULTS_ASSET", "search results"),
)
# Apple's image specs per slot (asc asset-library specs): the header is a 21:9
# 3840x1646 PNG; search results are 3:2 PNG or JPEG from 1920x1280 to 3840x2560.
# A 5244x2950 16:9 PNG is a universal image that fits either.
UNIVERSAL_CREATIVE_SIZE = (5244, 2950)
CREATIVE_EXTENSIONS = {".png", ".jpg", ".jpeg"}
# Library image states: still being reviewed, not sent to review yet, or
# finished without approval.
CREATIVE_PENDING_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "ACCEPTED"}
CREATIVE_UNSUBMITTED_STATES = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW", "COMPLETE", "UPLOAD_COMPLETE"}
# AWAITING_UPLOAD is a reservation an interrupted upload left behind (asc never
# deletes it); it is ignored, so the next run uploads the file again.
CREATIVE_DEAD_STATES = {"REJECTED", "FAILED", "ARCHIVED", "AWAITING_UPLOAD"}

# Every metadata field, screenshots and creative assets included, can be written in these states.
EDITABLE_VERSION_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}
# READY_FOR_REVIEW means the version already sits in a draft review submission
# (for example after a failed submit); it can still be submitted, and Apple still
# accepts text changes then, but not new screenshots or creative assets.
SUBMITTABLE_VERSION_STATES = EDITABLE_VERSION_STATES | {"READY_FOR_REVIEW"}
TEXT_EDITABLE_VERSION_STATES = EDITABLE_VERSION_STATES | {"READY_FOR_REVIEW"}
# A rerun may find the version here after its earlier attempt started or
# completed the submission. Metadata switches pass only when nothing would change.
UNCHANGED_METADATA_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW"}
# Versions in these states are finished. Any other state means the version is
# still on its way to the store, and App Store Connect allows only one such
# version per platform, so no new version is created next to it.
FINISHED_VERSION_STATES = {
    "READY_FOR_SALE",
    "REPLACED_WITH_NEW_VERSION",
    "REMOVED_FROM_SALE",
    "DEVELOPER_REMOVED_FROM_SALE",
}


def fail(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


def truthy(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


def read_text(path: Path) -> str | None:
    if not path.is_file():
        return None
    text = path.read_text(encoding="utf-8").strip()
    return text or None


def data(payload: Any) -> Any:
    return (payload or {}).get("data") if isinstance(payload, dict) else None


def rows(payload: Any) -> list[dict[str, Any]]:
    value = data(payload)
    return value if isinstance(value, list) else []


def attrs(row: dict[str, Any] | None) -> dict[str, Any]:
    return (row or {}).get("attributes") or {}


def related_id(row: dict[str, Any], name: str) -> str | None:
    return (((row.get("relationships") or {}).get(name) or {}).get("data") or {}).get("id")


def asc_value(text: str) -> str:
    """A flag value for asc, which reads a leading @ as @file:/@env: (escaped as @@)."""
    return "@" + text if text.startswith("@") else text


def load_credentials() -> tuple[str, str, str]:
    key_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ID", "").strip()
    issuer_id = os.environ.get("APP_STORE_CONNECT_ISSUER_ID", "").strip()
    key_p8 = os.environ.get("APP_STORE_CONNECT_API_KEY_P8", "").strip()
    if not key_id or not issuer_id or not key_p8:
        fail(
            "missing ASC credentials — set APP_STORE_CONNECT_API_KEY_ID, "
            "APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_API_KEY_P8"
        )
    return key_id, issuer_id, key_p8


def asc_from_environment(*, read_only: bool = False) -> asc_cli.Asc:
    """The asc runner for this job. read_only=True (or ASC_READ_ONLY) makes asc refuse every write."""
    load_credentials()
    return asc_cli.Asc(read_only=read_only)


def call(asc: asc_cli.Asc, *args: str) -> Any:
    """Run asc and stop the release with a readable error when it fails."""
    try:
        return asc.run(*args)
    except asc_cli.AscError as exc:
        fail(str(exc))


def find_app(asc: asc_cli.Asc, bundle_id: str, app_id: str = ASC_APP_ID) -> str:
    """The pinned App Store Connect app, after checking it carries exactly bundle_id."""
    record = data(call(asc, "apps", "view", "--id", app_id)) or {}
    if record.get("id") != app_id:
        fail(f"App Store Connect returned app {record.get('id')!r}, expected {app_id}")
    found = attrs(record).get("bundleId")
    if found != bundle_id:
        fail(f"App Store Connect app {app_id} has bundle id {found!r}, expected {bundle_id}")
    return app_id


def list_ios_app_store_versions(asc: asc_cli.Asc, app_id: str) -> list[dict[str, Any]]:
    return rows(call(asc, "versions", "list", "--app", app_id, "--platform", PLATFORM, "--paginate"))


def get_ios_app_store_version(asc: asc_cli.Asc, app_id: str, version_string: str) -> dict[str, Any]:
    matches = [
        row for row in list_ios_app_store_versions(asc, app_id) if attrs(row).get("versionString") == version_string
    ]
    if not matches:
        fail(
            f"no IOS App Store version {version_string!r} for app {app_id} "
            "(turn on IOS_CREATE_VERSION, or create the version in App Store Connect first)"
        )
    if len(matches) > 1:
        fail(f"ambiguous App Store versions for {version_string!r} on IOS — got {len(matches)} records")
    return matches[0]


def version_localization(asc: asc_cli.Asc, version_id: str, locale: str) -> dict[str, Any]:
    """The version's localization for exactly this locale."""
    found = [
        row
        for row in rows(call(asc, "localizations", "list", "--version", version_id, "--locale", locale))
        if attrs(row).get("locale") == locale
    ]
    if not found:
        fail(
            f"App Store Connect has no {locale} localization on version {version_id}; "
            "add that language to the version in App Store Connect first"
        )
    return found[0]


# Version-localization fields: (App Store Connect attribute, file, max characters).
LISTING_FIELDS = (
    ("description", "description.txt", 4000),
    ("keywords", "keywords.txt", 100),
    ("promotionalText", "promotional_text.txt", 170),
    ("marketingUrl", "marketing_url.txt", None),
    ("supportUrl", "support_url.txt", None),
)
WHATS_NEW_FIELD = ("whatsNew", "whats_new.txt", 4000)
URL_ATTRIBUTES = {"marketingUrl", "supportUrl"}
# The `asc localizations update` flag for each attribute.
TEXT_FLAGS = {
    "description": "--description",
    "keywords": "--keywords",
    "promotionalText": "--promotional-text",
    "marketingUrl": "--marketing-url",
    "supportUrl": "--support-url",
    "whatsNew": "--whats-new",
}


def listing_locales(metadata_dir: Path) -> list[str]:
    """Locales kept in the repo: every store/metadata/ios/<locale>/ directory."""
    ios_dir = metadata_dir / "ios"
    if not ios_dir.is_dir():
        return []
    return sorted(
        child.name
        for child in ios_dir.iterdir()
        if child.is_dir() and re.fullmatch(r"[a-z]{2,3}(-[A-Za-z0-9]+)*", child.name)
    )


def check_listing_text(loc_dir: Path, fields: tuple[tuple[str, str, int | None], ...]) -> list[str]:
    """Problems with the listing files for one locale (missing, too long, bad URL)."""
    problems = []
    for attribute, filename, limit in fields:
        value = read_text(loc_dir / filename)
        if value is None:
            problems.append(f"{loc_dir / filename} is missing or empty")
            continue
        if limit is not None and len(value) > limit:
            problems.append(f"{loc_dir / filename} has {len(value)} characters (max {limit})")
        if attribute in URL_ATTRIBUTES and not re.fullmatch(r"https?://\S+", value):
            problems.append(f"{loc_dir / filename} is not an http(s) URL: {value!r}")
    return problems


def wanted_version_text(
    loc_dir: Path, *, include_listing: bool, include_whats_new: bool
) -> dict[str, str]:
    """Version-localization fields the enabled switches upload for one locale.

    Listing text and What's New are separate gates; app info fields (name,
    subtitle, privacy URL) are never uploaded.
    """
    fields = (LISTING_FIELDS if include_listing else ()) + (
        (WHATS_NEW_FIELD,) if include_whats_new else ()
    )
    wanted: dict[str, str] = {}
    for field, filename, _limit in fields:
        value = read_text(loc_dir / filename)
        if value:
            wanted[field] = value
    return wanted


def normalized_text(value: Any) -> str:
    """Text as compared with App Store Connect (line endings and outer whitespace ignored)."""
    if not isinstance(value, str):
        return ""
    return value.replace("\r\n", "\n").strip()


def file_md5(path: Path) -> str:
    """The MD5 App Store Connect keeps as a screenshot's sourceFileChecksum."""
    return hashlib.md5(path.read_bytes(), usedforsecurity=False).hexdigest()


class LocalePlan:
    """What the metadata step would write for one locale, read without writing anything."""

    def __init__(self, locale: str, localization_id: str) -> None:
        self.locale = locale
        self.localization_id = localization_id
        # Version-localization fields the switches upload, and the ones that differ.
        self.text_fields: list[str] = []
        self.text_changes: dict[str, str] = {}
        # Screenshot display types the switch uploads, and the ones that differ.
        self.screenshots: dict[str, list[Path]] = {}
        self.stale_screenshots: list[str] = []


def plan_metadata(
    asc: asc_cli.Asc,
    *,
    version_id: str,
    locales: list[str],
    metadata_dir: Path,
    include_listing: bool,
    include_whats_new: bool,
    screenshot_sets: dict[str, dict[str, list[Path]]],
) -> list[LocalePlan]:
    """Compare the repository metadata with App Store Connect without changing anything.

    Fails if App Store Connect lacks a repository locale on the version.
    """
    plans: list[LocalePlan] = []
    for locale in locales:
        sets = screenshot_sets.get(locale) or {}
        if not (include_listing or include_whats_new or sets):
            continue
        loc = version_localization(asc, version_id, locale)
        plan = LocalePlan(locale, loc["id"])
        wanted = wanted_version_text(
            metadata_dir / "ios" / locale,
            include_listing=include_listing,
            include_whats_new=include_whats_new,
        )
        live = attrs(loc)
        plan.text_fields = list(wanted)
        plan.text_changes = {
            field: value
            for field, value in wanted.items()
            if normalized_text(live.get(field)) != normalized_text(value)
        }
        plan.screenshots = dict(sets)
        if sets:
            shots = live_screenshot_sets(asc, loc["id"])
            plan.stale_screenshots = [
                display_type
                for display_type, pngs in sets.items()
                if not screenshots_up_to_date(asc, loc["id"], display_type, pngs, live=shots)
            ]
        plans.append(plan)
    return plans


def metadata_problems(plans: list[LocalePlan], *, version: str, state: str) -> list[str]:
    """Changes the version's state (or asc) cannot take; empty when the plan can be applied."""
    problems: list[str] = []
    for plan in plans:
        if plan.text_changes and state not in TEXT_EDITABLE_VERSION_STATES:
            problems.append(
                f"{plan.locale}: {', '.join(plan.text_changes)} differ from App Store Connect, "
                f"and version {version!r} takes no text changes while {state}"
            )
        if plan.stale_screenshots and state not in EDITABLE_VERSION_STATES:
            problems.append(
                f"{plan.locale}: the {', '.join(plan.stale_screenshots)} screenshots differ from "
                f"App Store Connect, and version {version!r} takes no new screenshots while {state}"
            )
            continue
        for display_type in plan.stale_screenshots:
            # App Store Connect, and asc before it uploads, refuses a PNG that
            # stores alpha even when every pixel is opaque.
            with_alpha = [p.name for p in plan.screenshots.get(display_type, []) if asc_cli.image_has_alpha(p)]
            if with_alpha:
                problems.append(
                    f"{plan.locale}: the {display_type} screenshots differ from App Store Connect, but these have "
                    f"an alpha channel, which App Store Connect refuses: {', '.join(with_alpha)}; re-export them "
                    "as RGB PNGs (no transparency), then rerun"
                )
    return problems


def apply_metadata(asc: asc_cli.Asc, plans: list[LocalePlan]) -> None:
    """Write only what differs: changed text fields and stale screenshot sets."""
    for plan in plans:
        if plan.text_changes:
            args = ["localizations", "update", "--id", plan.localization_id]
            for field, value in plan.text_changes.items():
                args += [TEXT_FLAGS[field], asc_value(value)]
            call(asc, *args)
            print(f"  updated version localization ({plan.locale}): {', '.join(plan.text_changes)}")
        elif plan.text_fields:
            print(f"  version localization ({plan.locale}) already up to date: {', '.join(plan.text_fields)}")
        for display_type, pngs in plan.screenshots.items():
            if display_type in plan.stale_screenshots:
                print(f"  {plan.locale} {display_type}: {len(pngs)} screenshot(s)")
                replace_screenshot_set(asc, plan.localization_id, display_type, pngs)
            else:
                print(f"  {plan.locale} {display_type}: already up to date ({len(pngs)} screenshot(s))")


def png_size(path: Path) -> tuple[int, int] | None:
    """Width and height from a PNG header, or None if the file is not a PNG."""
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        return None
    return int.from_bytes(header[16:20], "big"), int.from_bytes(header[20:24], "big")


def load_screenshot_sets(metadata_dir: Path, locale: str, root: Path | None = None) -> dict[str, list[Path]]:
    """Ordered screenshots per display type for one locale, from its screenshots.json.

    Paths in the manifest are relative to the repository root (ROOT unless
    given). Fails with a clear message if the manifest, a file, or an image
    size is wrong.
    """
    root = ROOT if root is None else root
    manifest_path = metadata_dir / "ios" / locale / SCREENSHOT_MANIFEST
    if not manifest_path.is_file():
        fail(
            f"screenshot upload is on, but {manifest_path} is missing; list the App Store "
            "screenshots for each display type there (see store/README.md)"
        )
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{manifest_path} is not valid JSON: {exc}")
    if not isinstance(manifest, dict) or not manifest:
        fail(f"{manifest_path} must map display types to lists of PNG paths")

    sets: dict[str, list[Path]] = {}
    for display_type, entries in manifest.items():
        accepted = SCREENSHOT_SIZES.get(display_type)
        if accepted is None:
            fail(f"{manifest_path}: unsupported display type {display_type!r}")
        if not isinstance(entries, list) or not entries:
            fail(f"{manifest_path}: {display_type} needs at least one screenshot")
        if len(entries) > SCREENSHOT_SET_MAX:
            fail(f"{manifest_path}: {display_type} has {len(entries)} screenshots (max {SCREENSHOT_SET_MAX})")
        paths: list[Path] = []
        for entry in entries:
            if not isinstance(entry, str) or not entry or entry.startswith("/") or ".." in Path(entry).parts:
                fail(f"{manifest_path}: {entry!r} must be a path relative to the repository root")
            path = root / entry
            if not path.is_file():
                fail(f"{manifest_path}: screenshot {entry} does not exist")
            size = png_size(path)
            if size is None:
                fail(f"{manifest_path}: {entry} is not a PNG")
            if size not in accepted:
                allowed = ", ".join(f"{w}x{h}" for w, h in sorted(accepted))
                fail(f"{manifest_path}: {entry} is {size[0]}x{size[1]}; {display_type} accepts {allowed}")
            paths.append(path)
        if len(set(paths)) != len(paths):
            fail(f"{manifest_path}: {display_type} lists a screenshot twice")
        sets[display_type] = paths
    return sets


def live_screenshot_sets(asc: asc_cli.Asc, version_loc_id: str) -> dict[str, list[dict[str, Any]]]:
    """Display type -> the screenshots App Store Connect holds for one localization, in order."""
    payload = call(asc, "screenshots", "list", "--version-localization", version_loc_id)
    live: dict[str, list[dict[str, Any]]] = {}
    for entry in (payload or {}).get("sets") or []:
        display_type = attrs(entry.get("set")).get("screenshotDisplayType")
        live[display_type] = [attrs(shot) for shot in entry.get("screenshots") or []]
    return live


def screenshots_up_to_date(
    asc: asc_cli.Asc,
    version_loc_id: str,
    display_type: str,
    pngs: list[Path],
    *,
    live: dict[str, list[dict[str, Any]]] | None = None,
) -> bool:
    """True when the live set already holds exactly these files, in this order (read-only).

    Compares App Store Connect's sourceFileChecksum (MD5) with the files; a
    screenshot whose processing failed never counts as up to date. `live` is a
    listing already read for this localization.
    """
    shots = (live_screenshot_sets(asc, version_loc_id) if live is None else live).get(display_type)
    if shots is None:
        return False
    checksums: list[str] = []
    for shot in shots:
        if (shot.get("assetDeliveryState") or {}).get("state") == "FAILED":
            return False
        checksums.append(str(shot.get("sourceFileChecksum") or "").lower())
    return checksums == [file_md5(path) for path in pngs]


def replace_screenshot_set(asc: asc_cli.Asc, version_loc_id: str, display_type: str, pngs: list[Path]) -> None:
    """Replace one display type's screenshots, keeping the manifest order, then read the set back.

    asc uploads a folder in file-name order, so the files are copied into a
    temporary folder with their manifest position in front of their names.
    """
    device_type = display_type.removeprefix("APP_")
    with tempfile.TemporaryDirectory(prefix="asc-screenshots-") as staged:
        for number, path in enumerate(pngs, start=1):
            shutil.copyfile(path, Path(staged) / f"{number:02d}-{path.name}")
        # --replace deletes the set's screenshots before uploading. If an upload
        # fails part-way, fix the error and rerun: the set is replaced again.
        call(
            asc,
            "screenshots", "upload", "--version-localization", version_loc_id, "--path", staged,
            "--device-type", device_type, "--replace", "--confirm",
        )
    if not screenshots_up_to_date(asc, version_loc_id, display_type, pngs):
        fail(f"after uploading, App Store Connect's {display_type} set does not hold the manifest's files in order")
    print(f"  uploaded {len(pngs)} {display_type} screenshot(s)")


def image_dimensions(path: Path) -> tuple[str | None, int, int]:
    """(format, width, height) of a PNG or JPEG, read from its headers."""
    raw = Path(path).read_bytes()
    if raw.startswith(asc_cli.PNG_SIGNATURE) and len(raw) >= 24:
        return "png", int.from_bytes(raw[16:20], "big"), int.from_bytes(raw[20:24], "big")
    if raw[:2] == b"\xff\xd8":
        i = 2
        while i + 9 < len(raw):
            if raw[i] != 0xFF:
                i += 1
                continue
            marker = raw[i + 1]
            if marker == 0xFF or marker in (0x01, 0xD8) or 0xD0 <= marker <= 0xD7:
                i += 1 if marker == 0xFF else 2
                continue
            if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
                return "jpeg", int.from_bytes(raw[i + 7:i + 9], "big"), int.from_bytes(raw[i + 5:i + 7], "big")
            i += 2 + int.from_bytes(raw[i + 2:i + 4], "big")
    return None, 0, 0


def creative_size_problem(placement_type: str, path: Path) -> str | None:
    """Why Apple would refuse this image for the slot, or None when it fits."""
    kind, width, height = image_dimensions(path)
    if kind is None:
        return "is not a PNG or JPEG"
    if kind == "png" and (width, height) == UNIVERSAL_CREATIVE_SIZE:
        return None
    if placement_type == "PRODUCT_PAGE_HEADER_ASSET":
        if kind != "png" or (width, height) != (3840, 1646):
            return f"is a {width}x{height} {kind.upper()}; the header must be a 3840x1646 PNG"
        return None
    if not (1920 <= width <= 3840 and width * 2 == height * 3):
        return f"is {width}x{height}; search results images are 3:2, from 1920x1280 to 3840x2560"
    return None


def creative_sources(creative_dir: Path) -> list[tuple[str, str, Path]]:
    """(placement type, label, image) for every creative slot that has an image.

    Checked before anything is built: one image per slot, no alpha channel, and
    a size and format Apple takes for that slot.
    """
    found = []
    for folder, placement_type, label in CREATIVE_SLOTS:
        slot_dir = creative_dir / folder
        images = sorted(
            p for p in slot_dir.glob("*") if p.is_file() and p.suffix.lower() in CREATIVE_EXTENSIONS
        ) if slot_dir.is_dir() else []
        if len(images) > 1:
            fail(f"the {label} slot takes one image; {slot_dir} has {len(images)}")
        if images and asc_cli.image_has_alpha(images[0]):
            fail(f"the {label} image {images[0].name} has an alpha channel, which App Store Connect refuses; re-export it as RGB")
        problem = creative_size_problem(placement_type, images[0]) if images else None
        if problem:
            fail(f"the {label} image {images[0].name} {problem}")
        if images:
            found.append((placement_type, label, images[0]))
    if not found:
        fail(f"creative asset upload is on, but {creative_dir} has no header or search results image")
    return found


def library_images(asc: asc_cli.Asc, library_id: str) -> list[dict[str, Any]]:
    return rows(
        call(asc, "asset-library", "images", "list", "--library-id", library_id, "--category", "CREATIVE_ASSETS", "--paginate")
    )


def library_image_for(images: list[dict[str, Any]], path: Path) -> dict[str, Any] | None:
    """The newest usable library image uploaded from this exact file (name and size)."""
    size = path.stat().st_size
    same_file = [
        image for image in images if attrs(image).get("fileName") == path.name and attrs(image).get("fileSize") == size
    ]
    matches = [image for image in same_file if attrs(image).get("state") not in CREATIVE_DEAD_STATES]
    rejected = [image for image in same_file if attrs(image).get("state") == "REJECTED"]
    if not matches and rejected:
        fail(
            f"App Review rejected {path.name}; replace the image (a new file name) and re-run. "
            f"Details: {json.dumps(attrs(rejected[0]).get('stateDetails'))}"
        )
    return max(matches, key=lambda image: attrs(image).get("createdDate") or "") if matches else None


class CreativePlan:
    """One creative slot: the repository image, its Asset Library record, and where it is missing."""

    def __init__(self, placement_type: str, label: str, path: Path, image: dict[str, Any] | None) -> None:
        self.placement_type = placement_type
        self.label = label
        self.path = path
        # None while the image is not in the Asset Library yet.
        self.image = image
        # (locale, localization id, current placements) where the approved image is not placed.
        self.unplaced: list[tuple[str, str, list[dict[str, Any]]]] = []

    @property
    def state(self) -> str:
        return (attrs(self.image).get("state") or "") if self.image else ""

    def describe(self, *, editable: bool = True) -> str:
        name = self.path.name
        if self.image is None:
            return f"{self.label}: will upload {name} and send it to App Review"
        if self.state in CREATIVE_UNSUBMITTED_STATES or not self.state:
            return f"{self.label}: will send {name} to App Review"
        if self.state in CREATIVE_PENDING_STATES:
            return f"{self.label}: {name} is in App Review ({self.state}); placed on a later run"
        if self.state != "APPROVED":
            return f"{self.label}: {name} is {self.state}"
        if self.unplaced and not editable:
            return f"{self.label}: {name} is approved; placed once the version can be edited"
        if self.unplaced:
            return f"{self.label}: will place {name} on {', '.join(locale for locale, _, _ in self.unplaced)}"
        return f"{self.label}: {name} is already on the product page"


def plan_creative(
    asc: asc_cli.Asc, *, app_id: str, version_id: str, locales: list[str], creative_dir: Path
) -> tuple[str, list[CreativePlan]]:
    """Compare the repository's creative images with App Store Connect without changing anything.

    An image is matched in the Asset Library by file name and size. An approved
    image belongs on every listing locale of the version. Returns the library id
    and one plan per slot that has an image.
    """
    sources = creative_sources(creative_dir)
    library_id = (data(call(asc, "asset-library", "view", "--app", app_id)) or {}).get("id")
    if not library_id:
        fail(f"App Store Connect returned no Asset Library for app {app_id}")
    images = library_images(asc, library_id)
    localizations = {locale: version_localization(asc, version_id, locale)["id"] for locale in locales}
    plans: list[CreativePlan] = []
    for placement_type, label, path in sources:
        plan = CreativePlan(placement_type, label, path, library_image_for(images, path))
        if plan.image is not None and plan.state == "APPROVED":
            for locale, localization_id in localizations.items():
                current = rows(
                    call(
                        asc, "localizations", "placements", "list", "--localization-id", localization_id,
                        "--placement-type", placement_type, "--include", "image",
                    )
                )
                if not any(related_id(row, "image") == plan.image["id"] for row in current):
                    plan.unplaced.append((locale, localization_id, current))
        plans.append(plan)
    return library_id, plans


def creative_problems(plans: list[CreativePlan], *, version: str, state: str) -> list[str]:
    """Creative changes the version's state cannot take, and images that cannot be used."""
    editable = state in EDITABLE_VERSION_STATES
    problems: list[str] = []
    for plan in plans:
        name = plan.path.name
        if plan.image is None:
            if not editable:
                problems.append(
                    f"the {plan.label} image {name} is not in the Asset Library yet, and version {version!r} "
                    f"takes no new images while {state}"
                )
        elif plan.state in CREATIVE_UNSUBMITTED_STATES or not plan.state:
            if not editable:
                problems.append(
                    f"the {plan.label} image {name} has not been sent to App Review, and nothing is sent to "
                    f"review while version {version!r} is {state} (or submit it in App Store Connect)"
                )
        elif plan.state in CREATIVE_PENDING_STATES or plan.state == "APPROVED":
            # An image approved while the version waits for review is not a
            # mismatch: it is placed once the version can be edited.
            continue
        else:
            problems.append(f"the {plan.label} image {name} is {plan.state}; resolve it in App Store Connect")
    return problems


def apply_creative(
    asc: asc_cli.Asc, *, app_id: str, library_id: str, plans: list[CreativePlan], editable: bool = True
) -> dict[str, str]:
    """Upload, send to review, or place each creative image as its plan says.

    Only approved images are placed, because a version that is already approved
    only takes approved assets; one that is still in review or not yet submitted
    is placed on a later run, and so is an approved one while the version cannot
    be edited. Callers check creative_problems() first. Returns placement type ->
    outcome.
    """
    outcomes: dict[str, str] = {}
    to_review: list[tuple[str, dict[str, Any]]] = []
    for plan in plans:
        name = plan.path.name
        image = plan.image
        if image is None:
            # asc waits for processing and prints a receipt (imageId, ready, state).
            receipt = call(asc, "asset-library", "images", "upload", "--library-id", library_id, "--file", str(plan.path))
            if not receipt.get("imageId") or not receipt.get("ready"):
                fail(f"Apple did not finish processing the {plan.label} image {name}: {json.dumps(receipt)}")
            image = {"id": receipt["imageId"], "attributes": {"fileName": name, "state": receipt.get("state")}}
            print(f"  uploaded {name} to the Asset Library ({image['id']})")
        state = attrs(image).get("state") or ""
        if state in CREATIVE_UNSUBMITTED_STATES or not state:
            to_review.append((plan.label, image))
            outcomes[plan.placement_type] = "submitted for review"
            continue
        if state in CREATIVE_PENDING_STATES:
            outcomes[plan.placement_type] = f"in App Review ({state}); placed on a later run"
            print(f"  {plan.label}: {name} is {state}; it is placed once App Review approves it")
            continue
        if state != "APPROVED":
            fail(f"the {plan.label} image {name} is {state}; resolve it in App Store Connect")
        if not plan.unplaced:
            outcomes[plan.placement_type] = "already placed"
            print(f"  {plan.label}: {name} is already on the product page")
            continue
        if not editable:
            # Approval can land between a submit and a rerun; that is not a
            # mismatch, so the rerun passes and placement waits for an editable version.
            outcomes[plan.placement_type] = "approved; placed once the version can be edited"
            print(f"  {plan.label}: {name} is approved; it is placed on a later run, once the version can be edited")
            continue
        for locale, localization_id, current in plan.unplaced:
            if current:
                call(
                    asc, "localizations", "placements", "swap", "--localization-id", localization_id,
                    "--image-id", image["id"], "--placement-type", plan.placement_type,
                    "--placement-id", current[0]["id"], "--confirm",
                )
            else:
                call(
                    asc, "localizations", "placements", "create", "--localization-id", localization_id,
                    "--image-id", image["id"], "--placement-type", plan.placement_type,
                    "--placement-group", "DEFAULT_PROFILE",
                )
            print(f"  {locale} {plan.label}: placed {name} on the product page")
        outcomes[plan.placement_type] = "placed"
    if to_review:
        submit_creative_review(asc, app_id, to_review)
    return outcomes


def submit_creative_review(asc: asc_cli.Asc, app_id: str, images: list[tuple[str, dict[str, Any]]]) -> str:
    """Send not-yet-reviewed creative images to App Review in a submission of their own.

    A draft an earlier attempt left behind holding only some of these images
    (or nothing yet) is finished instead of starting another one.
    """
    wanted = {image["id"] for _, image in images}
    submission_id = None
    for draft in draft_submission_ids(asc, app_id):
        held = {related_id(item, "appAssetLibraryImage") for item in submission_items(asc, draft)}
        if held <= wanted:
            submission_id = draft
            print(f"  finishing creative review submission {draft} from an earlier attempt")
            break
    if submission_id is None:
        submission = data(call(asc, "review", "submissions-create", "--app", app_id, "--platform", PLATFORM)) or {}
        submission_id = submission.get("id")
    if not submission_id:
        fail("asc did not report the new review submission's id")
    for label, image in images:
        call(
            asc, "review", "items-add", "--submission", submission_id, "--item-type", "appAssetLibraryImages",
            "--item-id", image["id"], "--if-exists", "skip",
        )
        print(f"  {label}: {attrs(image).get('fileName')} added to creative review submission {submission_id}")
    items = submission_items(asc, submission_id)
    unexpected = [item["id"] for item in items if related_id(item, "appAssetLibraryImage") not in wanted]
    if unexpected or len(items) != len(images):
        fail(f"review submission {submission_id} holds unexpected items {unexpected}; not submitting it")
    call(asc, "review", "submissions-submit", "--id", submission_id, "--confirm")
    print(f"  submitted {len(images)} creative image(s) for App Review ({submission_id})")
    return submission_id


PRODUCT_GROUPS = ("subscriptions", "non_consumables", "consumables", "tips")


def intended_product_ids(catalog_path: Path = CATALOG) -> set[str]:
    """Product IDs the release is allowed to submit, from the canonical catalog."""
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    ids: set[str] = set()
    for group in PRODUCT_GROUPS:
        for item in catalog.get(group) or []:
            pid = item.get("id")
            if isinstance(pid, str) and pid:
                ids.add(pid)
    return ids


class ProductSubmitError(Exception):
    """A required product could not be added to App Review."""


class ProductSubmitResult:
    """Outcome of attaching products to a review submission."""

    def __init__(
        self,
        submission_id: str,
        submitted: int,
        added_items: bool,
        has_products: bool = False,
        allowed_versions: set[str] | None = None,
    ) -> None:
        self.submission_id = submission_id
        # Intended products the draft now holds (attached now or by an earlier run).
        self.submitted = submitted
        self.added_items = added_items
        # True when the draft holds intended products (attached now or in an
        # earlier run), so a catch-up retry can still submit the draft.
        self.has_products = has_products
        # Every version of every catalog product: the only product items a
        # draft may hold when it is submitted.
        self.allowed_versions = allowed_versions or set()


# States that mean the product can still be (re)attached to a review.
SUBMITTABLE_PRODUCT_STATES = {
    "READY_TO_SUBMIT",
    "DEVELOPER_REJECTED",
    "READY_FOR_REVIEW",
}
# Review submission item relationships asc is asked to include (App Store
# Connect omits them otherwise).
ITEM_RELATIONSHIPS = ("appStoreVersion", "subscriptionVersion", "inAppPurchaseVersion", "appAssetLibraryImage")


def draft_submission_ids(asc: asc_cli.Asc, app_id: str) -> list[str]:
    payload = call(
        asc, "review", "submissions-list", "--app", app_id, "--platform", PLATFORM, "--state", "READY_FOR_REVIEW",
        "--paginate",
    )
    return [row["id"] for row in rows(payload)]


def submission_items(asc: asc_cli.Asc, submission_id: str) -> list[dict[str, Any]]:
    """The submission's items with their related ids."""
    return rows(
        call(
            asc, "review", "items-list", "--submission", submission_id, "--include", ",".join(ITEM_RELATIONSHIPS),
            "--paginate",
        )
    )


def find_draft_submission(asc: asc_cli.Asc, app_id: str, version_id: str | None = None) -> str | None:
    """The app's READY_FOR_REVIEW draft to use for the version and products, if there is one.

    The draft already holding version_id wins. Otherwise only a draft holding no
    app version is reused, so another version's draft is never touched. A draft
    holding creative images belongs to their own review and is skipped.
    """
    drafts = []
    for submission_id in draft_submission_ids(asc, app_id):
        items = submission_items(asc, submission_id)
        if not any(related_id(item, "appAssetLibraryImage") for item in items):
            drafts.append((submission_id, {related_id(item, "appStoreVersion") for item in items} - {None, ""}))
    if version_id:
        for submission_id, versions in drafts:
            if version_id in versions:
                return submission_id
    for submission_id, versions in drafts:
        if not versions:
            return submission_id
    return None


def create_draft_submission(asc: asc_cli.Asc, app_id: str) -> str:
    created = data(call(asc, "review", "submissions-create", "--app", app_id, "--platform", PLATFORM)) or {}
    if not created.get("id"):
        fail("asc did not report the new review submission's id")
    return created["id"]


def get_or_create_draft_submission(asc: asc_cli.Asc, app_id: str, version_id: str | None = None) -> str:
    return find_draft_submission(asc, app_id, version_id) or create_draft_submission(asc, app_id)


def draft_item_version_ids(asc: asc_cli.Asc, submission_id: str) -> set[str]:
    """Return the subscription/in-app purchase/app version ids already attached to a draft."""
    ids: set[str] = set()
    for item in submission_items(asc, submission_id):
        for name in ITEM_RELATIONSHIPS[:3]:
            found = related_id(item, name)
            if found:
                ids.add(found)
    return ids


def draft_holds_app_version(asc: asc_cli.Asc, submission_id: str) -> bool:
    """Return True if any item in the draft references an app store version."""
    return any(related_id(item, "appStoreVersion") for item in submission_items(asc, submission_id))


def check_draft_items(
    asc: asc_cli.Asc, submission_id: str, *, version_id: str | None, allowed_products: set[str]
) -> None:
    """Refuse to submit a draft holding anything but this version and catalog products.

    A reused draft can hold items added by hand or by another tool; they must
    not ride along into App Review. With version_id, the draft must hold that
    version.
    """
    unexpected = []
    items = submission_items(asc, submission_id)
    if version_id and not any(related_id(item, "appStoreVersion") == version_id for item in items):
        fail(f"review submission {submission_id} does not hold App Store version {version_id}; not submitting it")
    for item in items:
        app_version = related_id(item, "appStoreVersion")
        product = related_id(item, "subscriptionVersion") or related_id(item, "inAppPurchaseVersion")
        if app_version and app_version == version_id:
            continue
        if product and not app_version and product in allowed_products:
            continue
        unexpected.append(item.get("id"))
    if unexpected:
        fail(
            f"review submission {submission_id} holds items this release did not choose "
            f"({', '.join(map(str, unexpected))}); remove them in App Store Connect and rerun"
        )


def submit_draft(asc: asc_cli.Asc, submission_id: str) -> None:
    call(asc, "review", "submissions-submit", "--id", submission_id, "--confirm")


def submit_product_draft(asc: asc_cli.Asc, submission_id: str) -> None:
    """Submit a draft review submission.

    Used on the catch-up path when the app version is already under review and a
    late Ready-to-Submit product was attached to a new draft: the draft is
    submitted on its own so the product actually reaches review. Callers must
    ensure the draft holds only products intended for this release.
    """
    submit_draft(asc, submission_id)
    print(f"  submitted product review submission {submission_id}")


def newest_version_id(versions: list[dict[str, Any]]) -> str | None:
    """The highest-numbered product version (App Store Connect allows one in flight)."""
    candidates = [v for v in versions if attrs(v).get("version")]
    if not candidates:
        return versions[0]["id"] if versions else None
    return max(candidates, key=lambda v: v["attributes"]["version"])["id"]


def submit_in_app_purchases(
    asc: asc_cli.Asc,
    app_id: str,
    *,
    intended_ids: set[str] | None = None,
    submission_id: str | None = None,
) -> ProductSubmitResult:
    """Attach Ready-to-Submit subscriptions / IAPs to the draft review submission.

    Products are added to the app's review submission as review items through
    their current version: subscriptions as `subscriptionVersions`, one-time
    purchases (the lifetime unlock) as `inAppPurchaseVersions` (`asc review
    items-add`). Attaching the current in-flight version also clears a
    `DEVELOPER_REJECTED` state left by a prior submission. Nothing reaches App
    Review here: the draft is submitted later in one step, so a failed build
    recheck sends nothing. A purchase is never sent to App Review on its own.

    Only products listed in `store/catalog/products.json` are considered, so an
    unrelated Ready-to-Submit product is not dragged into this release. Products
    that are already approved are left alone, but their versions are listed so
    the draft check can tell catalog items from anything else.

    With submission_id None, an existing draft holding no app version is reused,
    and a new one is created only when a product has to be added, so a rerun
    with nothing to send leaves no empty draft behind.
    """
    if intended_ids is None:
        intended_ids = intended_product_ids()

    if not intended_ids:
        print("  catalog has no products to submit")
        return ProductSubmitResult(submission_id or "", 0, False)

    if submission_id is None:
        submission_id = find_draft_submission(asc, app_id)

    # Idempotency: a retry reuses the same draft, so skip anything already
    # attached instead of adding a duplicate that App Store Connect rejects.
    already_attached = draft_item_version_ids(asc, submission_id) if submission_id else set()

    submitted = 0
    added_items = False
    has_products = False
    failures: list[str] = []
    allowed: set[str] = set()
    candidates: list[tuple[str, str, str, str, list[dict[str, Any]]]] = []

    for sub in rows(call(asc, "subscriptions", "list", "--app", app_id, "--paginate")):
        a = attrs(sub)
        pid = a.get("productId") or ""
        if pid not in intended_ids:
            continue
        versions = rows(call(asc, "subscriptions", "versions", "list", "--subscription-id", sub["id"], "--paginate"))
        allowed |= {version["id"] for version in versions}
        if a.get("state") in SUBMITTABLE_PRODUCT_STATES:
            candidates.append(("subscription", "subscriptionVersions", a.get("name") or sub["id"], pid, versions))

    for iap in rows(call(asc, "iap", "list", "--app", app_id, "--paginate")):
        a = attrs(iap)
        pid = a.get("productId") or ""
        if pid not in intended_ids:
            continue
        versions = rows(call(asc, "iap", "versions", "list", "--iap-id", iap["id"], "--paginate"))
        allowed |= {version["id"] for version in versions}
        if a.get("state") == "READY_TO_SUBMIT":
            candidates.append(("in-app purchase", "inAppPurchaseVersions", a.get("name") or iap["id"], pid, versions))

    for kind, item_type, name, pid, versions in candidates:
        version_id = newest_version_id(versions)
        if not version_id:
            failures.append(f"{kind} {name} ({pid}): no version to submit")
            continue
        if version_id in already_attached:
            submitted += 1
            has_products = True
            print(f"  {kind} {name}: already attached (idempotent)")
            continue
        if submission_id is None:
            submission_id = create_draft_submission(asc, app_id)
        try:
            asc.run(
                "review", "items-add", "--submission", submission_id, "--item-type", item_type,
                "--item-id", version_id, "--if-exists", "skip",
            )
        except asc_cli.AscError as exc:
            failures.append(f"{kind} {name} ({pid}): {exc}")
            continue
        submitted += 1
        added_items = True
        has_products = True
        print(f"  {kind} {name}: attached to review submission")

    print(f"  in-app purchases / subscriptions attached: {submitted}")
    if failures:
        raise ProductSubmitError(
            "these required products were not added to App Review: "
            + "; ".join(failures)
            + ". Resolve them in App Store Connect and rerun the release."
        )
    return ProductSubmitResult(submission_id or "", submitted, added_items, has_products, allowed)


def submit_for_review(
    asc: asc_cli.Asc,
    app_id: str,
    version_id: str,
    version_state: str = "",
    *,
    submission_id: str | None = None,
    allowed_products: set[str] | None = None,
) -> None:
    """Add the version to the draft (unless it already sits there) and submit the draft.

    The draft is submitted only when it holds this version and nothing but
    versions of catalog products besides it.
    """
    # Reuse a draft submission when one already exists (an earlier attempt can
    # leave a READY_FOR_REVIEW submission that was never submitted).
    if submission_id is None:
        submission_id = get_or_create_draft_submission(asc, app_id, version_id)

    # READY_FOR_REVIEW means the version is already held by a draft submission.
    already_added = version_state == "READY_FOR_REVIEW" or version_id in draft_item_version_ids(asc, submission_id)
    if not already_added:
        call(
            asc, "review", "items-add", "--submission", submission_id, "--item-type", "appStoreVersions",
            "--item-id", version_id, "--if-exists", "skip",
        )
    check_draft_items(asc, submission_id, version_id=version_id, allowed_products=allowed_products or set())
    submit_draft(asc, submission_id)
    print(f"  submitted App Store version {version_id} for review (submission {submission_id})")


RELEASE_TYPE_PUBLIC = "AFTER_APPROVAL"
RELEASE_TYPE_MANUAL = "MANUAL"


def verify_build(
    asc: asc_cli.Asc, build_id: str, version_string: str, build_number: str, app_id: str = ASC_APP_ID
) -> None:
    """Re-read the build and refuse anything but this run's processed build."""
    payload = call(
        asc, "builds", "list", "--app", app_id, "--build-number", build_number, "--version", version_string,
        "--platform", PLATFORM, "--processing-state", "all", "--include", "preReleaseVersion",
    )
    included = {(row.get("type"), row.get("id")): row for row in (payload or {}).get("included") or []}
    build = next((row for row in rows(payload) if row.get("id") == build_id), None)
    problems = []
    if build is None:
        problems.append("not listed for this app, version and build number")
        a: dict[str, Any] = {}
        pre: dict[str, Any] = {}
    else:
        a = attrs(build)
        pre = attrs(included.get(("preReleaseVersions", related_id(build, "preReleaseVersion"))))
    if build is not None and a.get("version") != build_number:
        problems.append(f"build number {a.get('version')!r}")
    if build is not None and a.get("processingState") != "VALID":
        problems.append(f"processing state {a.get('processingState')!r}")
    if a.get("expired"):
        problems.append("expired")
    if build is not None and (pre.get("version") != version_string or pre.get("platform") != PLATFORM):
        problems.append(f"version {pre.get('platform')} {pre.get('version')!r}")
    if problems:
        fail(
            f"build {build_id} is not {version_string} ({build_number}), VALID and unexpired: "
            + ", ".join(problems)
        )


def attached_build_id(asc: asc_cli.Asc, version_id: str) -> str | None:
    payload = call(asc, "versions", "view", "--version-id", version_id, "--include", "build")
    return related_id(data(payload) or {}, "build")


def confirm_selected_build(asc: asc_cli.Asc, version_id: str, build_id: str) -> None:
    current = attached_build_id(asc, version_id)
    if current != build_id:
        fail(
            f"App Store version {version_id} has build {current or 'none'} selected, "
            f"expected {build_id}; not submitting"
        )


def select_build(
    asc: asc_cli.Asc,
    version_id: str,
    build_id: str,
    version_string: str,
    build_number: str,
) -> None:
    """Explicitly select this run's build for the version, then read it back."""
    verify_build(asc, build_id, version_string, build_number)
    call(asc, "versions", "attach-build", "--version-id", version_id, "--build-id", build_id)
    confirm_selected_build(asc, version_id, build_id)
    print(f"  selected build {build_number} ({build_id}) for version {version_string}")


def set_release_type(asc: asc_cli.Asc, version_id: str, *, public_release: bool) -> None:
    release_type = RELEASE_TYPE_PUBLIC if public_release else RELEASE_TYPE_MANUAL
    call(asc, "versions", "update", "--version-id", version_id, "--release-type", release_type)
    print(
        "  release type: "
        + ("release automatically after approval" if public_release else "manual release after approval")
    )


class _ScriptedAsc:
    """Offline asc stand-in for the dry-run self-check: answers by command prefix."""

    def __init__(self, answers: dict[tuple[str, ...], Any]) -> None:
        self.answers = answers
        self.calls: list[tuple[str, ...]] = []

    def run(self, *args: str, **_: Any) -> Any:
        self.calls.append(args)
        for prefix, answer in sorted(self.answers.items(), key=lambda kv: -len(kv[0])):
            if args[: len(prefix)] == prefix:
                return answer(args) if callable(answer) else answer
        if args[:2] in {("review", "items-add"), ("review", "submissions-submit")}:
            return {"data": {"id": "ITEM"}}
        raise AssertionError(f"unexpected asc call {args}")


def _flag(args: tuple[str, ...], name: str) -> str:
    return args[args.index(name) + 1]


def _item(item_id: str, relationship: str, related: str) -> dict[str, Any]:
    return {"id": item_id, "relationships": {relationship: {"data": {"id": related}}}}


def dry_run_self_check() -> None:
    """Exercise the product-submission path offline so dry-run covers it."""
    app_id = "APP"
    weekly = "com.quitall.premium.weekly"
    yearly = "com.quitall.premium.yearly"
    lifetime = "com.quitall.premium.lifetime"
    subscriptions = [
        # Weekly is still DEVELOPER_REJECTED from a prior submit.
        {"id": "S0", "attributes": {"name": "Weekly", "productId": weekly, "state": "DEVELOPER_REJECTED"}},
        {"id": "S1", "attributes": {"name": "Yearly", "productId": yearly, "state": "READY_TO_SUBMIT"}},
        # Not in the catalog: must never be submitted.
        {"id": "SX", "attributes": {"name": "Legacy", "productId": "com.quitall.premium.monthly",
                                    "state": "READY_TO_SUBMIT"}},
    ]
    purchases = [
        {"id": "IAP1", "attributes": {"name": "Lifetime", "productId": lifetime, "state": "READY_TO_SUBMIT"}},
        # Already approved: must not be resubmitted.
        {"id": "IAP2", "attributes": {"name": "Old lifetime", "productId": "com.quitall.premium.lifetime.v0",
                                      "state": "APPROVED"}},
    ]

    def subscription_versions(args: tuple[str, ...]) -> dict[str, Any]:
        # Two versions returned out of order: the higher-numbered current
        # version must win regardless of response ordering.
        i = _flag(args, "--subscription-id")[1:]
        return {"data": [{"id": f"V{i}b", "attributes": {"version": 2, "state": "READY_FOR_REVIEW"}},
                         {"id": f"V{i}", "attributes": {"version": 1, "state": "DEVELOPER_REJECTED"}}]}

    def purchase_versions(args: tuple[str, ...]) -> dict[str, Any]:
        if _flag(args, "--iap-id") == "IAP1":
            # The lifetime purchase's approved version 1 and its new version 2, out of order.
            return {"data": [{"id": "IV1", "attributes": {"version": 1, "state": "APPROVED"}},
                             {"id": "IV2", "attributes": {"version": 2, "state": "PREPARE_FOR_SUBMISSION"}}]}
        return {"data": [{"id": "IV0", "attributes": {"version": 1, "state": "APPROVED"}}]}

    held: list[dict[str, Any]] = []
    answers: dict[tuple[str, ...], Any] = {
        ("review", "submissions-list"): {"data": [{"id": "SUB1"}]},
        ("review", "items-list"): lambda args: {"data": list(held)},
        ("subscriptions", "list"): {"data": subscriptions},
        ("subscriptions", "versions", "list"): subscription_versions,
        ("iap", "list"): {"data": purchases},
        ("iap", "versions", "list"): purchase_versions,
    }
    intended = {weekly, yearly, lifetime, "com.quitall.premium.lifetime.v0"}

    def added(fake: _ScriptedAsc, item_type: str) -> set[str]:
        return {_flag(c, "--item-id") for c in fake.calls
                if c[:2] == ("review", "items-add") and _flag(c, "--item-type") == item_type}

    fake = _ScriptedAsc(answers)
    result = submit_in_app_purchases(fake, app_id, intended_ids=intended)
    assert result.submitted == 3, f"expected 3 products, got {result.submitted}"
    assert result.added_items and result.has_products, "expected the products to be attached"
    assert result.submission_id == "SUB1", f"wrong submission: {result.submission_id}"
    assert added(fake, "subscriptionVersions") == {"V0b", "V1b"}, (
        f"expected the current (v2) version of each subscription, got {added(fake, 'subscriptionVersions')}"
    )
    assert added(fake, "inAppPurchaseVersions") == {"IV2"}, (
        "only the Ready-to-Submit lifetime purchase's current version may be attached"
    )
    assert all(_flag(c, "--submission") == "SUB1" for c in fake.calls if c[:2] == ("review", "items-add")), (
        "wrong review submission target"
    )
    assert not [c for c in fake.calls if "SX" in c], "a product outside the catalog was considered"
    assert {"V0", "V0b", "V1", "V1b", "IV0", "IV1", "IV2"} <= result.allowed_versions, (
        "every version of every catalog product may sit in the draft"
    )
    assert not [c for c in fake.calls if c[:2] == ("review", "submissions-submit")], (
        "attaching products must not submit anything"
    )

    # Retry: the same draft already holds a subscription version and the lifetime
    # purchase's version, so the rerun must not add them again.
    held[:] = [_item("ITEM0", "subscriptionVersion", "V0b"), _item("ITEM1", "inAppPurchaseVersion", "IV2")]
    retry = _ScriptedAsc(answers)
    result2 = submit_in_app_purchases(retry, app_id, intended_ids=intended)
    assert result2.submitted == 3, f"expected 3 products on retry, got {result2.submitted}"
    assert result2.has_products, "retry must report the draft holds products"
    retried = added(retry, "subscriptionVersions") | added(retry, "inAppPurchaseVersions")
    assert retried == {"V1b"}, f"retry attached the wrong versions: {retried}"
    assert draft_holds_app_version(retry, "SUB1") is False, "false app-version detection"

    held[:] = [_item("ITEMV", "appStoreVersion", "AV1")]
    assert draft_holds_app_version(_ScriptedAsc(answers), "SUB1") is True, (
        "app-version items must be detected and refused"
    )

    # submit_for_review must not re-add an app version already in the draft.
    review = _ScriptedAsc(answers)
    submit_for_review(review, app_id, "AV1", "PREPARE_FOR_SUBMISSION", submission_id="SUB1")
    assert not [c for c in review.calls if c[:2] == ("review", "items-add")], "app version was added again on retry"
    assert [c for c in review.calls if c[:2] == ("review", "submissions-submit") and _flag(c, "--id") == "SUB1"], (
        "the draft was not submitted"
    )

    # A draft holding an item this release did not choose is never submitted.
    held[:] = [_item("ITEMV", "appStoreVersion", "AV1"), _item("STRAY", "inAppPurchaseVersion", "OTHER")]
    stray = _ScriptedAsc(answers)
    with contextlib.redirect_stderr(io.StringIO()):
        try:
            submit_for_review(stray, app_id, "AV1", "PREPARE_FOR_SUBMISSION", submission_id="SUB1",
                              allowed_products={"IV2"})
        except SystemExit:
            pass
        else:
            raise AssertionError("a draft with an unchosen item was submitted")
    assert not [c for c in stray.calls if c[:2] == ("review", "submissions-submit")], (
        "a draft with an unchosen item was submitted"
    )
    print("  dry-run self-check: product submission selection OK")


def validate_local_inputs(
    *,
    upload_listing: bool,
    upload_whats_new: bool,
    upload_screenshots: bool,
    metadata_dir: Path,
    locales: list[str],
    version: str | None,
    root: Path | None = None,
    upload_creative: bool = False,
    creative_dir: Path | None = None,
) -> dict[str, dict[str, list[Path]]]:
    """Check every repo input before any App Store Connect call.

    Returns the screenshot sets to upload per locale (empty unless screenshots are on).
    """
    if (upload_listing or upload_whats_new or upload_screenshots or upload_creative) and not locales:
        fail(f"no listing locales under {metadata_dir / 'ios'}")
    problems: list[str] = []
    for locale in locales:
        loc_dir = metadata_dir / "ios" / locale
        if not loc_dir.is_dir():
            fail(f"metadata dir missing: {loc_dir}")
        if upload_listing:
            problems += check_listing_text(loc_dir, LISTING_FIELDS)
        if upload_whats_new:
            problems += check_listing_text(loc_dir, (WHATS_NEW_FIELD,))
    if upload_whats_new:
        # What's New is written for one version; stale text must never ship.
        marker_path = metadata_dir / "ios" / WHATS_NEW_VERSION_FILE
        marker = read_text(marker_path)
        if not version:
            problems.append("What's New upload needs --version to check the text is for this release")
        elif marker != version:
            problems.append(
                f"What's New upload is on for {version}, but {marker_path} says the text is for "
                f"{marker or 'no version'}; update whats_new.txt in every locale, then set "
                f"{WHATS_NEW_VERSION_FILE} to {version}"
            )
    if problems:
        fail("listing files are not ready:\n  " + "\n  ".join(problems))

    sets: dict[str, dict[str, list[Path]]] = {}
    if upload_screenshots:
        for locale in locales:
            if (metadata_dir / "ios" / locale / SCREENSHOT_MANIFEST).is_file():
                sets[locale] = load_screenshot_sets(metadata_dir, locale, root)
        if not sets:
            fail(
                f"screenshot upload is on, but no locale under {metadata_dir / 'ios'} has a "
                f"{SCREENSHOT_MANIFEST}; add App Store-sized PNGs and list them there"
            )
        with_alpha = {path for locale_sets in sets.values() for pngs in locale_sets.values()
                      for path in pngs if asc_cli.image_has_alpha(path)}
        if with_alpha:
            print(
                f"  note: {len(with_alpha)} screenshot(s) have an alpha channel, which App Store Connect refuses; "
                "a set that differs from App Store Connect stops the run until it is re-exported as RGB PNG"
            )
    if upload_creative:
        creative_sources(creative_dir or CREATIVE_DIR)
    return sets


def version_key(version_string: str) -> tuple[int, ...] | None:
    """1.2.2 -> (1, 2, 2), padded to three parts; None when it is not numeric."""
    if not re.fullmatch(r"[0-9]+(\.[0-9]+){0,2}", version_string or ""):
        return None
    parts = [int(part) for part in version_string.split(".")]
    return tuple(parts + [0] * (3 - len(parts)))


def ensure_ios_app_store_version(
    asc: asc_cli.Asc, *, bundle_id: str, expected_app_id: str, version_string: str
) -> None:
    """Create the App Store version for this release when it does not exist yet.

    An existing version with this number is left as it is (the preflight then
    checks its state). Nothing is created when another version is still on its
    way to the store, or when this number is not newer than every existing
    version; the created version is read back before the run continues.
    """
    wanted = version_key(version_string)
    if wanted is None:
        fail(f"version {version_string!r} must look like 1.3 or 1.2.2")
    app_id = find_app(asc, bundle_id, expected_app_id)
    versions = list_ios_app_store_versions(asc, app_id)
    existing = [row for row in versions if attrs(row).get("versionString") == version_string]
    if len(existing) > 1:
        fail(f"ambiguous App Store versions for {version_string!r} on IOS — got {len(existing)} records")
    if existing:
        state = attrs(existing[0]).get("appStoreState") or ""
        print(f"App Store version {version_string} already exists ({state}); nothing to create")
        return
    problems: list[str] = []
    for row in versions:
        other = attrs(row).get("versionString") or ""
        state = attrs(row).get("appStoreState") or ""
        if state not in FINISHED_VERSION_STATES:
            problems.append(
                f"version {other!r} is still {state or 'in an unknown state'}; release or remove it "
                f"in App Store Connect before {version_string} can be created"
            )
        other_key = version_key(other)
        if other_key is not None and other_key >= wanted:
            problems.append(f"version {version_string} is not newer than the existing version {other}")
    if problems:
        fail(
            f"not creating App Store version {version_string} (nothing was changed):\n  "
            + "\n  ".join(problems)
        )
    call(asc, "versions", "create", "--app", app_id, "--version", version_string, "--platform", PLATFORM)
    created = [
        row for row in list_ios_app_store_versions(asc, app_id) if attrs(row).get("versionString") == version_string
    ]
    if len(created) != 1:
        fail(
            f"created App Store version {version_string}, but reading it back found "
            f"{len(created)} records; check it in App Store Connect before rerunning"
        )
    state = attrs(created[0]).get("appStoreState") or ""
    print(f"created App Store version {version_string} ({state or 'state not reported yet'})")


def version_state_problems(state: str, version: str, *, edits_metadata: bool, submit: bool) -> list[str]:
    """Version states the enabled switches cannot use at all, checked before anything else."""
    problems: list[str] = []
    metadata_states = TEXT_EDITABLE_VERSION_STATES | UNCHANGED_METADATA_STATES
    if edits_metadata and state not in metadata_states:
        problems.append(
            f"version {version!r} is not editable for metadata (state={state}); "
            f"expected one of: {', '.join(sorted(metadata_states))}"
        )
    # WAITING_FOR_REVIEW is accepted only as a rerun after a completed submit,
    # and only when review holds this run's build (checked by the caller).
    if submit and state not in SUBMITTABLE_VERSION_STATES | {"WAITING_FOR_REVIEW"}:
        problems.append(f"version {version!r} cannot be submitted for review (state={state})")
    return problems


def preflight(
    asc: asc_cli.Asc,
    *,
    bundle_id: str,
    version_string: str,
    locales: list[str],
    metadata_dir: Path,
    do_listing: bool,
    do_whats_new: bool,
    do_screenshots: bool,
    screenshot_sets: dict[str, dict[str, list[Path]]],
    do_submit: bool,
    do_creative: bool = False,
    creative_dir: Path | None = None,
) -> None:
    """Read-only App Store Connect checks before anything is built or uploaded.

    asc runs read-only here: the App Store version must exist (IOS_CREATE_VERSION's
    step, which runs before this, creates a missing one), be in a state the
    enabled switches can use and have every repository locale, and its metadata
    and creative assets must be changeable where they differ. The live step
    repeats every check, because App Store Connect can change while the build is
    processed.
    """
    app_id = find_app(asc, bundle_id)
    version = get_ios_app_store_version(asc, app_id, version_string)
    state = attrs(version).get("appStoreState") or ""
    edits_metadata = do_listing or do_whats_new or do_screenshots or do_creative
    problems = version_state_problems(state, version_string, edits_metadata=edits_metadata, submit=do_submit)
    if do_submit and state == "WAITING_FOR_REVIEW":
        problems.append(
            f"version {version_string!r} is already WAITING_FOR_REVIEW, so the build this run would "
            "upload could never be selected; take the version out of review in App Store Connect first"
        )
    if not problems and (do_listing or do_whats_new or do_screenshots):
        plans = plan_metadata(
            asc,
            version_id=version["id"],
            locales=locales,
            metadata_dir=metadata_dir,
            include_listing=do_listing,
            include_whats_new=do_whats_new,
            screenshot_sets=screenshot_sets,
        )
        problems += metadata_problems(plans, version=version_string, state=state)
        for plan in plans:
            changes = list(plan.text_changes) + plan.stale_screenshots
            print(f"  {plan.locale}: {'will update ' + ', '.join(changes) if changes else 'already up to date'}")
    if not problems and do_creative:
        _, creative = plan_creative(
            asc, app_id=app_id, version_id=version["id"], locales=locales, creative_dir=creative_dir or CREATIVE_DIR
        )
        problems += creative_problems(creative, version=version_string, state=state)
        for plan in creative:
            print(f"  creative {plan.describe(editable=state in EDITABLE_VERSION_STATES)}")
    if problems:
        fail(
            "App Store Connect is not ready for this release (nothing was built or changed):\n  "
            + "\n  ".join(problems)
        )
    print(f"ASC preflight passed: version {version_string} is {state}; nothing was changed")


def main(argv: list[str] | None = None) -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--metadata-dir",
        type=Path,
        default=METADATA_DIR,
        help="Listing tree: <dir>/ios/<locale>/*.txt and screenshots.json",
    )
    parser.add_argument(
        "--creative-dir",
        type=Path,
        default=CREATIVE_DIR,
        help="Product page header and search results images: " + ", ".join(s[0] for s in CREATIVE_SLOTS),
    )
    parser.add_argument(
        "--locale",
        action="append",
        help="Only these locales (repeatable). Default: every locale directory in the repo",
    )
    parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    parser.add_argument(
        "--version",
        help="Marketing version from release tag (e.g. 1.2.2 when tag is v1.2.2)",
    )
    parser.add_argument(
        "--build-id",
        help="App Store Connect id of the build uploaded by this run (required to submit)",
    )
    parser.add_argument(
        "--build-number",
        help="CFBundleVersion of the build uploaded by this run (required to submit)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate flags and local files only — no asc calls",
    )
    parser.add_argument(
        "--preflight",
        action="store_true",
        help="Read-only App Store Connect checks before the build is uploaded (asc refuses every write)",
    )
    parser.add_argument(
        "--create-version",
        action="store_true",
        help="Create the App Store version for --version when it is missing (CREATE_IOS_VERSION)",
    )
    args = parser.parse_args(argv)

    if args.create_version:
        if args.preflight:
            fail("--create-version and --preflight are separate steps; run them one at a time")
        if not truthy("CREATE_IOS_VERSION"):
            print("App Store version creation skipped — CREATE_IOS_VERSION is off")
            return
        if not args.version:
            fail("--create-version needs --version (the marketing version from the tag)")
        if version_key(args.version) is None:
            fail(f"version {args.version!r} must look like 1.3 or 1.2.2")
        if args.dry_run:
            print(f"ASC dry-run — would create App Store version {args.version} if it is missing")
            return
        ensure_ios_app_store_version(
            asc_from_environment(),
            bundle_id=args.bundle_id,
            expected_app_id=ASC_APP_ID,
            version_string=args.version,
        )
        return

    do_listing = truthy("UPLOAD_LISTING")
    do_whats_new = truthy("UPLOAD_WHATS_NEW")
    do_screenshots = truthy("UPLOAD_SCREENSHOTS")
    do_creative = truthy("UPLOAD_CREATIVE_ASSETS")
    do_submit = truthy("SUBMIT_IOS_REVIEW")
    do_public = truthy("PUBLIC_RELEASE")

    if not (do_listing or do_whats_new or do_screenshots or do_creative or do_submit):
        print(
            "ASC release skipped — UPLOAD_LISTING / UPLOAD_WHATS_NEW / UPLOAD_SCREENSHOTS / "
            "UPLOAD_CREATIVE_ASSETS / SUBMIT_IOS_REVIEW are off"
        )
        return
    if do_public and not do_submit:
        fail("PUBLIC_RELEASE only applies when SUBMIT_IOS_REVIEW is on")
    if do_submit and not args.preflight and not (args.build_id and args.build_number):
        fail(
            "submitting needs --build-id and --build-number for the build uploaded by "
            "this run; an older build is never substituted"
        )

    locales = args.locale or listing_locales(args.metadata_dir)
    screenshot_sets = validate_local_inputs(
        upload_listing=do_listing,
        upload_whats_new=do_whats_new,
        upload_screenshots=do_screenshots,
        metadata_dir=args.metadata_dir,
        locales=locales,
        version=args.version,
        upload_creative=do_creative,
        creative_dir=args.creative_dir,
    )

    if args.dry_run:
        print("ASC dry-run — local inputs OK; no asc calls")
        print(
            f"  bundle={args.bundle_id} locales={','.join(locales)} listing={do_listing} "
            f"whats_new={do_whats_new} screenshots={do_screenshots} creative={do_creative} "
            f"submit={do_submit} public_release={do_public}"
        )
        for locale, sets in screenshot_sets.items():
            for display_type, pngs in sets.items():
                print(f"  {locale} {display_type}: {len(pngs)} screenshot(s)")
        if do_submit:
            dry_run_self_check()
        return

    if not args.version:
        fail("--version is required for live ASC calls (pass marketing version from tag)")

    if args.preflight:
        preflight(
            asc_from_environment(read_only=True),
            bundle_id=args.bundle_id,
            version_string=args.version,
            locales=locales,
            metadata_dir=args.metadata_dir,
            do_listing=do_listing,
            do_whats_new=do_whats_new,
            do_screenshots=do_screenshots,
            screenshot_sets=screenshot_sets,
            do_submit=do_submit,
            do_creative=do_creative,
            creative_dir=args.creative_dir,
        )
        return

    asc = asc_from_environment()
    app_id = find_app(asc, args.bundle_id)
    version = get_ios_app_store_version(asc, app_id, args.version)
    version_id = version["id"]
    state = attrs(version).get("appStoreState") or ""
    print(f"ASC app={app_id} version={args.version} id={version_id} state={state}")

    edits_metadata = do_listing or do_whats_new or do_screenshots or do_creative
    problems = version_state_problems(state, args.version, edits_metadata=edits_metadata, submit=do_submit)
    if problems:
        fail("; ".join(problems))
    in_review = state == "WAITING_FOR_REVIEW"
    if in_review and do_submit:
        # A rerun after a successful submit: only accept it if review holds
        # exactly this run's build.
        confirm_selected_build(asc, version_id, args.build_id)

    # Read everything first, so a change the version's state cannot take fails
    # before anything is written. Only what differs is written, which also makes
    # a rerun after a started or completed submission work.
    plans: list[LocalePlan] = []
    if do_listing or do_whats_new or do_screenshots:
        plans = plan_metadata(
            asc,
            version_id=version_id,
            locales=locales,
            metadata_dir=args.metadata_dir,
            include_listing=do_listing,
            include_whats_new=do_whats_new,
            screenshot_sets=screenshot_sets,
        )
        problems += metadata_problems(plans, version=args.version, state=state)
    library_id = ""
    creative: list[CreativePlan] = []
    if do_creative:
        library_id, creative = plan_creative(
            asc, app_id=app_id, version_id=version_id, locales=locales, creative_dir=args.creative_dir
        )
        problems += creative_problems(creative, version=args.version, state=state)
    if problems:
        fail(
            "cannot update the version metadata (nothing was changed):\n  "
            + "\n  ".join(problems)
            + "\n  To change it, take the version out of review in App Store Connect, then rerun."
        )
    if plans:
        print("updating App Store metadata (only what differs)…")
        apply_metadata(asc, plans)
    if creative:
        print("syncing the product page header and search results images…")
        apply_creative(asc, app_id=app_id, library_id=library_id, plans=creative,
                       editable=state in EDITABLE_VERSION_STATES)

    if in_review:
        if do_submit:
            print(
                "ASC submit skipped — version already WAITING_FOR_REVIEW with this run's "
                "build (idempotent)"
            )
            try:
                result = submit_in_app_purchases(asc, app_id)
            except ProductSubmitError as exc:
                fail(str(exc))
            # Attaching a product to a fresh draft does not submit it. If the
            # version is already under review, the draft holding the late
            # products must be submitted on its own or they never reach review.
            # `has_products` also covers a retry where an earlier run attached
            # the products but failed to submit their draft. No draft is created
            # when there is nothing to send, and only a draft holding no app
            # version is reused. Only submit a product-only draft of catalog
            # products: refuse if it holds an app version (e.g. another
            # release's) or anything else this release did not choose, so
            # unrelated items never ship.
            if result.has_products and result.submission_id:
                if draft_holds_app_version(asc, result.submission_id):
                    fail(
                        "refusing to submit a draft that contains an app "
                        "version; remove it in App Store Connect and rerun"
                    )
                check_draft_items(asc, result.submission_id, version_id=None, allowed_products=result.allowed_versions)
                submit_product_draft(asc, result.submission_id)
        print("ASC release step finished")
        return

    if do_submit:
        # The draft that already holds this version wins; otherwise only a draft
        # holding no app version is reused. A READY_FOR_REVIEW version that no
        # draft holds stops here, before anything is written, so a rerun is not
        # stuck on the wrong draft.
        submission_id = find_draft_submission(asc, app_id, version_id)
        if state == "READY_FOR_REVIEW" and (
            submission_id is None
            or not any(related_id(item, "appStoreVersion") == version_id for item in submission_items(asc, submission_id))
        ):
            fail(
                f"version {args.version} is READY_FOR_REVIEW, but no draft review submission holds it; "
                "remove the version from its submission in App Store Connect and rerun"
            )
        print("selecting this run's build…")
        select_build(asc, version_id, args.build_id, args.version, args.build_number)
        set_release_type(asc, version_id, public_release=do_public)
        print("attaching in-app purchases / subscriptions to the review submission…")
        submission_id = submission_id or create_draft_submission(asc, app_id)
        try:
            result = submit_in_app_purchases(asc, app_id, submission_id=submission_id)
        except ProductSubmitError as exc:
            # A first-time subscription must ship with the version, so a failed
            # required product blocks the whole submission rather than letting
            # the version enter review without it.
            fail(f"{exc} Not submitting the app version.")
        # Recheck immediately before submitting: the selection must still be
        # this run's processed build. Nothing has reached App Review yet; the
        # version and its products go out together with the one submit below.
        verify_build(asc, args.build_id, args.version, args.build_number)
        confirm_selected_build(asc, version_id, args.build_id)
        print("submitting for App Store review…")
        submit_for_review(
            asc, app_id, version_id, state, submission_id=submission_id, allowed_products=result.allowed_versions
        )
        print(f"  {result.submitted} product(s) went out with the version")

    print("ASC release step finished")


if __name__ == "__main__":
    main()
