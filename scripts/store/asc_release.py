#!/usr/bin/env python3
"""App Store Connect listing, What's New, screenshots and submit-for-review (gated in CI).

The listing lives in the repo (store/metadata/ios/<locale>/): every locale
directory there is uploaded, and App Store Connect must already have that
locale on the version. App info fields (name, subtitle, privacy URL) are kept
for reference only and are not uploaded.

Metadata steps are idempotent: the live text and screenshots are read first and
only what differs is written. A rerun therefore also works after a review
submission was started (READY_FOR_REVIEW still takes text changes, not
screenshots) or completed (WAITING_FOR_REVIEW takes no changes): it passes when
the metadata is already in place and fails, before any write, when a change
would be needed.

Submitting for review covers both the App Store version and any Ready-to-Submit
in-app purchases or subscriptions listed in store/catalog/products.json. They
are attached to the same draft review submission as the version (subscriptions
through the `subscriptionVersion` relationship, one-time purchases through
`inAppPurchaseVersion`), so everything goes to App Review with one submit, after
the final build recheck. A first-time subscription must go out with the version
or App Review rejects the build.

`--preflight` runs before anything is built: read-only checks (GET requests
only) that the App Store version exists, is in a state the enabled switches can
use, and has every repository locale, so a release fails before it uploads."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[2]
ASC_BASE = "https://api.appstoreconnect.apple.com/v1"
# In-app purchase versions are listed under the v2 inAppPurchases resource.
ASC_V2_BASE = "https://api.appstoreconnect.apple.com/v2"
DEFAULT_BUNDLE_ID = "com.apoorvdarshan.Quit-All"
DEFAULT_APP_ID = "6760978934"
METADATA_DIR = ROOT / "store" / "metadata"
CATALOG = ROOT / "store" / "catalog" / "products.json"

# App Store Connect allows 10 screenshots per display type. Portrait sizes it
# accepts for each display type this app uses.
SCREENSHOT_SET_MAX = 10
SCREENSHOT_SIZES = {
    "APP_IPHONE_67": {(1260, 2736), (1284, 2778), (1290, 2796), (1320, 2868)},
    "APP_IPHONE_65": {(1242, 2688), (1284, 2778)},
}
SCREENSHOT_MANIFEST = "screenshots.json"
WHATS_NEW_VERSION_FILE = "whats_new_version.txt"

# Every metadata field, screenshots included, can be written in these states.
EDITABLE_VERSION_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "METADATA_REJECTED",
    "INVALID_BINARY",
}
# READY_FOR_REVIEW means the version already sits in a draft review submission
# (for example after a failed submit); it can still be submitted, and Apple still
# accepts text changes then, but not new screenshots.
SUBMITTABLE_VERSION_STATES = EDITABLE_VERSION_STATES | {"READY_FOR_REVIEW"}
TEXT_EDITABLE_VERSION_STATES = EDITABLE_VERSION_STATES | {"READY_FOR_REVIEW"}
# A rerun may find the version here after its earlier attempt started or
# completed the submission. Metadata switches pass only when nothing would change.
UNCHANGED_METADATA_STATES = {"READY_FOR_REVIEW", "WAITING_FOR_REVIEW"}


def fail(msg: str) -> None:
    print(f"error: {msg}", file=sys.stderr)
    raise SystemExit(1)


class AscHttpError(SystemExit):
    """An App Store Connect HTTP error; exits like fail() unless a caller retries."""

    def __init__(self, status: int, message: str) -> None:
        super().__init__(f"error: {message}")
        self.status = status


def truthy(name: str) -> bool:
    return os.environ.get(name, "").strip().lower() in {"1", "true", "yes", "on"}


def read_text(path: Path) -> str | None:
    if not path.is_file():
        return None
    text = path.read_text(encoding="utf-8").strip()
    return text or None


class AscClient:
    # JWTs are minted for 20 minutes; refresh well before that during long waits.
    TOKEN_MAX_AGE_SECONDS = 600

    def __init__(
        self, token: str | None = None, *, token_factory: Any | None = None
    ) -> None:
        if token is None and token_factory is None:
            raise ValueError("AscClient needs a token or a token_factory")
        self._token_factory = token_factory
        self._token = token if token is not None else token_factory()
        self._token_minted = time.monotonic()

    def _authorization(self) -> str:
        if (
            self._token_factory is not None
            and time.monotonic() - self._token_minted > self.TOKEN_MAX_AGE_SECONDS
        ):
            self._token = self._token_factory()
            self._token_minted = time.monotonic()
        return f"Bearer {self._token}"

    def request(
        self,
        method: str,
        path: str,
        *,
        body: dict[str, Any] | None = None,
        raw_body: bytes | None = None,
        content_type: str = "application/json",
        accept: str = "application/json",
    ) -> dict[str, Any] | None:
        url = path if path.startswith("http") else f"{ASC_BASE}{path}"
        headers = {
            "Authorization": self._authorization(),
            "Accept": accept,
        }
        data: bytes | None = None
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = content_type
        elif raw_body is not None:
            data = raw_body
            headers["Content-Type"] = content_type

        req = urllib.request.Request(url, data=data, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                payload = resp.read()
                if not payload:
                    return None
                if accept != "application/json":
                    return {"raw": payload}
                return json.loads(payload.decode("utf-8"))
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            print(f"error: ASC {method} {path} → HTTP {exc.code}: {detail[:2000]}", file=sys.stderr)
            raise AscHttpError(exc.code, f"ASC {method} {path} → HTTP {exc.code}") from None

    def get(self, path: str) -> dict[str, Any]:
        result = self.request("GET", path)
        assert result is not None
        return result

    def patch(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        result = self.request("PATCH", path, body=body)
        assert result is not None
        return result

    def post(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        result = self.request("POST", path, body=body)
        assert result is not None
        return result

    def upload_bytes(
        self, url: str, data: bytes, headers: dict[str, str], *, method: str = "PUT"
    ) -> None:
        req = urllib.request.Request(
            url, data=data, method=method.upper(), headers=headers
        )
        try:
            with urllib.request.urlopen(req, timeout=300):
                return
        except urllib.error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            fail(f"ASC asset upload → HTTP {exc.code}: {detail[:1000]}")


def make_asc_token(key_id: str, issuer_id: str, private_key: str) -> str:
    import jwt

    now = int(time.time())
    payload = {
        "iss": issuer_id,
        "iat": now,
        "exp": now + 1200,
        "aud": "appstoreconnect-v1",
    }
    headers = {"kid": key_id, "typ": "JWT"}
    return jwt.encode(payload, private_key, algorithm="ES256", headers=headers)


def load_credentials() -> tuple[str, str, str]:
    key_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ID", "").strip()
    issuer_id = os.environ.get("APP_STORE_CONNECT_ISSUER_ID", "").strip()
    key_p8 = os.environ.get("APP_STORE_CONNECT_API_KEY_P8", "").strip()
    if not key_id or not issuer_id or not key_p8:
        fail(
            "missing ASC credentials — set APP_STORE_CONNECT_API_KEY_ID, "
            "APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_API_KEY_P8"
        )
    key_p8 = key_p8.replace("\\n", "\n")
    return key_id, issuer_id, key_p8


def client_from_environment() -> AscClient:
    """Client whose JWT is re-minted automatically during long-running steps."""
    key_id, issuer_id, key_p8 = load_credentials()
    return AscClient(token_factory=lambda: make_asc_token(key_id, issuer_id, key_p8))


def find_app(client: AscClient, bundle_id: str) -> str:
    """The id of the one App Store Connect app whose bundle id is exactly bundle_id.

    The filter is not trusted to be exact: rows for other bundle ids are ignored,
    and anything but exactly one exact match stops the run.
    """
    query = urllib.parse.urlencode({"filter[bundleId]": bundle_id})
    rows = iter_collection(client, f"/apps?{query}")
    matches = [row for row in rows if (row.get("attributes") or {}).get("bundleId") == bundle_id]
    if not matches:
        fail(f"no App Store Connect app has bundle id {bundle_id}")
    if len(matches) > 1:
        ids = ", ".join(str(row.get("id")) for row in matches)
        fail(f"ambiguous: {len(matches)} App Store Connect apps have bundle id {bundle_id} ({ids})")
    return matches[0]["id"]


def get_ios_app_store_version(
    client: AscClient, app_id: str, version_string: str
) -> dict[str, Any]:
    # Prefer the app relationship listing — some ASC API keys cannot
    # GET_COLLECTION on /appStoreVersions with filter[app]=… (403).
    matches: list[dict[str, Any]] = []
    path: str | None = (
        f"/apps/{app_id}/appStoreVersions?"
        + urllib.parse.urlencode({"limit": "50", "filter[platform]": "IOS"})
    )
    while path:
        payload = client.get(path)
        for row in payload.get("data") or []:
            attrs = row.get("attributes") or {}
            if attrs.get("versionString") == version_string:
                matches.append(row)
        next_url = (payload.get("links") or {}).get("next")
        if not next_url:
            break
        path = next_url
    if not matches:
        fail(
            f"no IOS App Store version {version_string!r} for app {app_id} "
            "(create the version in App Store Connect first)"
        )
    if len(matches) > 1:
        fail(
            f"ambiguous App Store versions for {version_string!r} on IOS — "
            f"got {len(matches)} records"
        )
    return matches[0]


def localization_for_locale(
    client: AscClient, collection_path: str, locale: str
) -> dict[str, Any]:
    query = urllib.parse.urlencode({"filter[locale]": locale, "limit": "1"})
    payload = client.get(f"{collection_path}?{query}")
    data = payload.get("data") or []
    if not data:
        fail(
            f"App Store Connect has no {locale} localization at {collection_path}; "
            "add that language to the version in App Store Connect first"
        )
    return data[0]


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
    """What the metadata step would write for one locale, read with GET requests only."""

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
    client: AscClient,
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
        loc = localization_for_locale(
            client, f"/appStoreVersions/{version_id}/appStoreVersionLocalizations", locale
        )
        plan = LocalePlan(locale, loc["id"])
        wanted = wanted_version_text(
            metadata_dir / "ios" / locale,
            include_listing=include_listing,
            include_whats_new=include_whats_new,
        )
        live = loc.get("attributes") or {}
        plan.text_fields = list(wanted)
        plan.text_changes = {
            field: value
            for field, value in wanted.items()
            if normalized_text(live.get(field)) != normalized_text(value)
        }
        plan.screenshots = dict(sets)
        plan.stale_screenshots = [
            display_type
            for display_type, pngs in sets.items()
            if not screenshots_up_to_date(client, loc["id"], display_type, pngs)
        ]
        plans.append(plan)
    return plans


def metadata_problems(plans: list[LocalePlan], *, version: str, state: str) -> list[str]:
    """Changes the version's state cannot take; empty when the plan can be applied."""
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
    return problems


def apply_metadata(client: AscClient, plans: list[LocalePlan]) -> None:
    """Write only what differs: changed text fields and stale screenshot sets."""
    for plan in plans:
        if plan.text_changes:
            client.patch(
                f"/appStoreVersionLocalizations/{plan.localization_id}",
                {
                    "data": {
                        "type": "appStoreVersionLocalizations",
                        "id": plan.localization_id,
                        "attributes": plan.text_changes,
                    }
                },
            )
            print(f"  updated version localization ({plan.locale}): {', '.join(plan.text_changes)}")
        elif plan.text_fields:
            print(f"  version localization ({plan.locale}) already up to date: {', '.join(plan.text_fields)}")
        for display_type, pngs in plan.screenshots.items():
            if display_type in plan.stale_screenshots:
                print(f"  {plan.locale} {display_type}: {len(pngs)} screenshot(s)")
                replace_screenshot_set(client, plan.localization_id, display_type, pngs)
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


def screenshot_sets_for_localization(
    client: AscClient, version_loc_id: str
) -> list[dict[str, Any]]:
    payload = client.get(
        f"/appStoreVersionLocalizations/{version_loc_id}/appScreenshotSets"
    )
    return payload.get("data") or []


def find_screenshot_set(
    client: AscClient, version_loc_id: str, display_type: str
) -> dict[str, Any] | None:
    for item in screenshot_sets_for_localization(client, version_loc_id):
        if (item.get("attributes") or {}).get("screenshotDisplayType") == display_type:
            return item
    return None


def screenshots_up_to_date(
    client: AscClient, version_loc_id: str, display_type: str, pngs: list[Path]
) -> bool:
    """True when the live set already holds exactly these files, in this order (read-only).

    Compares App Store Connect's sourceFileChecksum (MD5) with the files; a
    screenshot whose processing failed never counts as up to date.
    """
    shot_set = find_screenshot_set(client, version_loc_id, display_type)
    if shot_set is None:
        return False
    payload = client.get(f"/appScreenshotSets/{shot_set['id']}/appScreenshots")
    live: list[str] = []
    for shot in payload.get("data") or []:
        attrs = shot.get("attributes") or {}
        if (attrs.get("assetDeliveryState") or {}).get("state") == "FAILED":
            return False
        live.append(str(attrs.get("sourceFileChecksum") or "").lower())
    return live == [file_md5(path) for path in pngs]


def ensure_screenshot_set(
    client: AscClient, version_loc_id: str, display_type: str
) -> dict[str, Any]:
    existing = find_screenshot_set(client, version_loc_id, display_type)
    if existing is not None:
        return existing
    created = client.post(
        "/appScreenshotSets",
        {
            "data": {
                "type": "appScreenshotSets",
                "attributes": {"screenshotDisplayType": display_type},
                "relationships": {
                    "appStoreVersionLocalization": {
                        "data": {
                            "type": "appStoreVersionLocalizations",
                            "id": version_loc_id,
                        }
                    }
                },
            }
        },
    )
    return created["data"]


def list_screenshot_ids(client: AscClient, screenshot_set_id: str) -> list[str]:
    payload = client.get(f"/appScreenshotSets/{screenshot_set_id}/appScreenshots")
    return [shot["id"] for shot in payload.get("data") or []]


def delete_screenshots(client: AscClient, screenshot_ids: list[str]) -> None:
    for shot_id in screenshot_ids:
        client.request("DELETE", f"/appScreenshots/{shot_id}")


def upload_screenshot_file(
    client: AscClient, screenshot_set_id: str, image_path: Path
) -> None:
    raw = image_path.read_bytes()
    checksum = hashlib.md5(raw, usedforsecurity=False).hexdigest()
    reserved = client.post(
        "/appScreenshots",
        {
            "data": {
                "type": "appScreenshots",
                "attributes": {
                    "fileName": image_path.name,
                    "fileSize": len(raw),
                },
                "relationships": {
                    "appScreenshotSet": {
                        "data": {"type": "appScreenshotSets", "id": screenshot_set_id}
                    }
                },
            }
        },
    )
    shot = reserved["data"]
    shot_id = shot["id"]
    upload_ops = (shot.get("attributes") or {}).get("uploadOperations") or []
    if not upload_ops:
        fail(f"ASC returned no uploadOperations for {image_path.name}")
    for op in upload_ops:
        offset = int(op.get("offset", 0))
        length = int(op["length"])
        chunk = raw[offset : offset + length]
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders") or []}
        method = (op.get("method") or "PUT").upper()
        client.upload_bytes(op["url"], chunk, headers, method=method)
    # The checksum lets a rerun recognise a set that is already up to date.
    client.patch(
        f"/appScreenshots/{shot_id}",
        {
            "data": {
                "type": "appScreenshots",
                "id": shot_id,
                "attributes": {"uploaded": True, "sourceFileChecksum": checksum},
            }
        },
    )
    print(f"  uploaded screenshot {image_path.name}")


def replace_screenshot_set(
    client: AscClient, version_loc_id: str, display_type: str, pngs: list[Path]
) -> None:
    """Replace one display type's screenshots, keeping the manifest order."""
    shot_set = ensure_screenshot_set(client, version_loc_id, display_type)
    set_id = shot_set["id"]

    # Old ASC ids still on the set; pop front when deleting for capacity or final cleanup.
    pending_old_ids = list_screenshot_ids(client, set_id)

    # Upload replacements one at a time. ASC rejects new reservations when the set is
    # at capacity, so delete one pending old screenshot before each upload when full.
    # If a mid-run upload fails, the live set may be mixed (some olds removed, some news
    # uploaded); fix the error and re-run, or restore screenshots in App Store Connect.
    for path in pngs:
        current_ids = list_screenshot_ids(client, set_id)
        if len(current_ids) >= SCREENSHOT_SET_MAX:
            if not pending_old_ids:
                fail(
                    f"ASC {display_type} screenshot set at capacity ({SCREENSHOT_SET_MAX}) "
                    f"with no tracked old screenshots left to replace"
                )
            delete_screenshots(client, [pending_old_ids.pop(0)])
        upload_screenshot_file(client, set_id, path)

    if pending_old_ids:
        delete_screenshots(client, pending_old_ids)
        print(f"  removed {len(pending_old_ids)} previous {display_type} screenshot(s)")


def iter_collection(client: AscClient, path: str) -> list[dict[str, Any]]:
    """Return every record in an ASC collection, following links.next."""
    rows: list[dict[str, Any]] = []
    while path:
        payload = client.get(path)
        rows.extend(payload.get("data") or [])
        next_url = (payload.get("links") or {}).get("next")
        if not next_url:
            break
        path = next_url
    return rows


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
    ) -> None:
        self.submission_id = submission_id
        self.submitted = submitted
        self.added_items = added_items
        # True when the draft holds intended products (attached now or in an
        # earlier run), so a catch-up retry can still submit the draft.
        self.has_products = has_products


# States that mean the product can still be (re)attached to a review.
SUBMITTABLE_PRODUCT_STATES = {
    "READY_TO_SUBMIT",
    "DEVELOPER_REJECTED",
    "READY_FOR_REVIEW",
}


def get_or_create_draft_submission(client: AscClient, app_id: str) -> str:
    """Return the app's READY_FOR_REVIEW draft review submission, creating one."""
    existing = client.get(
        f"/apps/{app_id}/reviewSubmissions?"
        + urllib.parse.urlencode({"filter[state]": "READY_FOR_REVIEW", "limit": "5"})
    )
    for row in existing.get("data") or []:
        return row["id"]
    submission = client.post(
        "/reviewSubmissions",
        {
            "data": {
                "type": "reviewSubmissions",
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }
        },
    )
    return submission["data"]["id"]


def draft_item_relationships(client: AscClient, submission_id: str) -> list[dict[str, Any]]:
    """Return the draft's items with their version relationships populated.

    App Store Connect omits `relationships` from Review Submission Items unless
    they are requested with `include`, so both relationship readers must ask for
    the version relationships explicitly.
    """
    return iter_collection(
        client,
        f"/reviewSubmissions/{submission_id}/items"
        "?limit=50&include=subscriptionVersion,appStoreVersion,inAppPurchaseVersion",
    )


def draft_item_version_ids(client: AscClient, submission_id: str) -> set[str]:
    """Return the subscription/in-app purchase/app version ids already attached to a draft."""
    ids: set[str] = set()
    for item in draft_item_relationships(client, submission_id):
        relationships = item.get("relationships") or {}
        for name in ("subscriptionVersion", "appStoreVersion", "inAppPurchaseVersion"):
            related = (relationships.get(name) or {}).get("data") or {}
            if related.get("id"):
                ids.add(related["id"])
    return ids


def draft_holds_app_version(client: AscClient, submission_id: str) -> bool:
    """Return True if any item in the draft references an app store version."""
    for item in draft_item_relationships(client, submission_id):
        related = (
            ((item.get("relationships") or {}).get("appStoreVersion") or {}).get("data")
            or {}
        )
        if related.get("id"):
            return True
    return False


def submit_product_draft(client: AscClient, submission_id: str) -> None:
    """Submit a draft review submission.

    Used on the catch-up path when the app version is already under review and a
    late Ready-to-Submit product was attached to a new draft: the draft is
    submitted on its own so the product actually reaches review. Callers must
    ensure the draft holds only products intended for this release.
    """
    client.request(
        "PATCH",
        f"/reviewSubmissions/{submission_id}",
        body={
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True},
            }
        },
    )
    print(f"  submitted product review submission {submission_id}")


def newest_version_id(versions: list[dict[str, Any]]) -> str | None:
    """The highest-numbered product version (App Store Connect allows one in flight)."""
    candidates = [v for v in versions if (v.get("attributes") or {}).get("version")]
    if not candidates:
        return versions[0]["id"] if versions else None
    return max(candidates, key=lambda v: v["attributes"]["version"])["id"]


def current_subscription_version(
    client: AscClient, subscription_id: str
) -> str | None:
    """Return the subscription's current in-flight version id, if any.

    App Store Connect allows only one in-flight version per subscription, so the
    highest-numbered version in a submittable state is the one to attach.
    """
    return newest_version_id(iter_collection(client, f"/subscriptions/{subscription_id}/versions"))


def current_in_app_purchase_version(client: AscClient, iap_id: str) -> str | None:
    """Return the in-app purchase's current in-flight version id, if any (v2 resource)."""
    return newest_version_id(iter_collection(client, f"{ASC_V2_BASE}/inAppPurchases/{iap_id}/versions"))


def submit_in_app_purchases(
    client: AscClient,
    app_id: str,
    *,
    intended_ids: set[str] | None = None,
    submission_id: str | None = None,
) -> ProductSubmitResult:
    """Attach Ready-to-Submit subscriptions / IAPs to the draft review submission.

    As of the 2026 App Store Connect workflow, products are added to the app's
    review submission as Review Submission Items: subscriptions through the
    `subscriptionVersion` relationship (not `subscription`, which the API
    rejects) and one-time purchases (the lifetime unlock) through
    `inAppPurchaseVersion`. Attaching the current in-flight version also clears a
    `DEVELOPER_REJECTED` state left by a prior submission. Nothing reaches App
    Review here: the draft is submitted later in one step, so a failed build
    recheck sends nothing. The deprecated standalone `inAppPurchaseSubmissions`
    endpoint, which submitted a purchase immediately, is not used.

    Only products listed in `store/catalog/products.json` are considered, so an
    unrelated Ready-to-Submit product is not dragged into this release. Products
    that are already approved are left alone.
    """
    if intended_ids is None:
        intended_ids = intended_product_ids()

    if not intended_ids:
        print("  catalog has no products to submit")
        return ProductSubmitResult(submission_id or "", 0, False)

    if submission_id is None:
        submission_id = get_or_create_draft_submission(client, app_id)

    # Idempotency: a retry reuses the same draft, so skip anything already
    # attached instead of posting a duplicate that App Store Connect rejects.
    already_attached = draft_item_version_ids(client, submission_id)

    submitted = 0
    added_items = False
    has_products = False
    failures: list[str] = []

    for group in iter_collection(
        client, f"/apps/{app_id}/subscriptionGroups?limit=200"
    ):
        for sub in iter_collection(
            client, f"/subscriptionGroups/{group['id']}/subscriptions?limit=200"
        ):
            attrs = sub.get("attributes") or {}
            pid = attrs.get("productId") or ""
            if pid not in intended_ids:
                continue
            if attrs.get("state") not in SUBMITTABLE_PRODUCT_STATES:
                continue
            name = attrs.get("name") or sub["id"]
            version_id = current_subscription_version(client, sub["id"])
            if not version_id:
                failures.append(f"subscription {name} ({pid}): no version to submit")
                continue
            if version_id in already_attached:
                submitted += 1
                has_products = True
                print(f"  subscription {name}: already attached (idempotent)")
                continue
            try:
                client.post(
                    "/reviewSubmissionItems",
                    {
                        "data": {
                            "type": "reviewSubmissionItems",
                            "relationships": {
                                "reviewSubmission": {
                                    "data": {
                                        "type": "reviewSubmissions",
                                        "id": submission_id,
                                    }
                                },
                                "subscriptionVersion": {
                                    "data": {
                                        "type": "subscriptionVersions",
                                        "id": version_id,
                                    }
                                },
                            },
                        }
                    },
                )
            except SystemExit:
                failures.append(f"subscription {name} ({pid})")
                continue
            submitted += 1
            added_items = True
            has_products = True
            print(f"  subscription {name}: attached to review submission")

    for iap in iter_collection(client, f"/apps/{app_id}/inAppPurchasesV2?limit=200"):
        attrs = iap.get("attributes") or {}
        pid = attrs.get("productId") or ""
        if pid not in intended_ids:
            continue
        if attrs.get("state") != "READY_TO_SUBMIT":
            continue
        name = attrs.get("name") or iap["id"]
        version_id = current_in_app_purchase_version(client, iap["id"])
        if not version_id:
            failures.append(f"in-app purchase {name} ({pid}): no version to submit")
            continue
        if version_id in already_attached:
            submitted += 1
            has_products = True
            print(f"  in-app purchase {name}: already attached (idempotent)")
            continue
        try:
            client.post(
                "/reviewSubmissionItems",
                {
                    "data": {
                        "type": "reviewSubmissionItems",
                        "relationships": {
                            "reviewSubmission": {
                                "data": {
                                    "type": "reviewSubmissions",
                                    "id": submission_id,
                                }
                            },
                            "inAppPurchaseVersion": {
                                "data": {
                                    "type": "inAppPurchaseVersions",
                                    "id": version_id,
                                }
                            },
                        },
                    }
                },
            )
        except SystemExit:
            failures.append(f"in-app purchase {name} ({pid})")
            continue
        submitted += 1
        added_items = True
        has_products = True
        print(f"  in-app purchase {name}: attached to review submission")

    print(f"  in-app purchases / subscriptions attached: {submitted}")
    if failures:
        raise ProductSubmitError(
            "these required products were not added to App Review: "
            + "; ".join(failures)
            + ". Resolve them in App Store Connect and rerun the release."
        )
    return ProductSubmitResult(submission_id, submitted, added_items, has_products)


def submit_for_review(
    client: AscClient,
    app_id: str,
    version_id: str,
    version_state: str = "",
    *,
    submission_id: str | None = None,
) -> None:
    # Reuse a draft submission when one already exists (an earlier attempt can
    # leave a READY_FOR_REVIEW submission that was never submitted).
    if submission_id is None:
        submission_id = get_or_create_draft_submission(client, app_id)

    items_versions = draft_item_version_ids(client, submission_id)
    # READY_FOR_REVIEW means the version is already held by this draft submission.
    already_added = version_state == "READY_FOR_REVIEW" or version_id in items_versions
    if not already_added:
        client.post(
            "/reviewSubmissionItems",
            {
                "data": {
                    "type": "reviewSubmissionItems",
                    "relationships": {
                        "reviewSubmission": {
                            "data": {"type": "reviewSubmissions", "id": submission_id}
                        },
                        "appStoreVersion": {
                            "data": {"type": "appStoreVersions", "id": version_id}
                        },
                    },
                }
            },
        )

    # Submitting is a PATCH with submitted=true; there is no /submit action.
    client.request(
        "PATCH",
        f"/reviewSubmissions/{submission_id}",
        body={
            "data": {
                "type": "reviewSubmissions",
                "id": submission_id,
                "attributes": {"submitted": True},
            }
        },
    )
    print(
        f"  submitted App Store version {version_id} for review "
        f"(submission {submission_id})"
    )


RELEASE_TYPE_PUBLIC = "AFTER_APPROVAL"
RELEASE_TYPE_MANUAL = "MANUAL"


def verify_build(
    client: AscClient, build_id: str, version_string: str, build_number: str
) -> None:
    """Re-read the build and refuse anything but this run's processed build."""
    payload = client.get(
        f"/builds/{build_id}?"
        + urllib.parse.urlencode(
            {
                "include": "preReleaseVersion",
                "fields[builds]": "version,processingState,expired,preReleaseVersion",
                "fields[preReleaseVersions]": "version,platform",
            }
        )
    )
    data = payload.get("data") or {}
    attrs = data.get("attributes") or {}
    pre = next(
        (row for row in payload.get("included") or [] if row.get("type") == "preReleaseVersions"),
        {},
    )
    pre_attrs = pre.get("attributes") or {}
    problems = []
    if data.get("id") != build_id:
        problems.append(f"id {data.get('id')!r}")
    if attrs.get("version") != build_number:
        problems.append(f"build number {attrs.get('version')!r}")
    if attrs.get("processingState") != "VALID":
        problems.append(f"processing state {attrs.get('processingState')!r}")
    if attrs.get("expired"):
        problems.append("expired")
    if pre_attrs.get("version") != version_string or pre_attrs.get("platform") != "IOS":
        problems.append(f"version {pre_attrs.get('platform')} {pre_attrs.get('version')!r}")
    if problems:
        fail(
            f"build {build_id} is not {version_string} ({build_number}), VALID and unexpired: "
            + ", ".join(problems)
        )


def attached_build_id(client: AscClient, version_id: str) -> str | None:
    payload = client.get(f"/appStoreVersions/{version_id}/build")
    return (payload.get("data") or {}).get("id")


def confirm_selected_build(client: AscClient, version_id: str, build_id: str) -> None:
    current = attached_build_id(client, version_id)
    if current != build_id:
        fail(
            f"App Store version {version_id} has build {current or 'none'} selected, "
            f"expected {build_id}; not submitting"
        )


def select_build(
    client: AscClient,
    version_id: str,
    build_id: str,
    version_string: str,
    build_number: str,
) -> None:
    """Explicitly select this run's build for the version, then read it back."""
    verify_build(client, build_id, version_string, build_number)
    client.request(
        "PATCH",
        f"/appStoreVersions/{version_id}/relationships/build",
        body={"data": {"type": "builds", "id": build_id}},
    )
    confirm_selected_build(client, version_id, build_id)
    print(f"  selected build {build_number} ({build_id}) for version {version_string}")


def set_release_type(client: AscClient, version_id: str, *, public_release: bool) -> None:
    release_type = RELEASE_TYPE_PUBLIC if public_release else RELEASE_TYPE_MANUAL
    client.patch(
        f"/appStoreVersions/{version_id}",
        {
            "data": {
                "type": "appStoreVersions",
                "id": version_id,
                "attributes": {"releaseType": release_type},
            }
        },
    )
    print(
        "  release type: "
        + ("release automatically after approval" if public_release else "manual release after approval")
    )


class _RecordingClient:
    """Offline AscClient stand-in for the dry-run self-check."""

    def __init__(self, collections: dict[str, list[dict[str, Any]]]) -> None:
        self._collections = collections
        self.posts: list[tuple[str, dict[str, Any]]] = []
        self.requests: list[tuple[str, str, dict[str, Any] | None]] = []

    def get(self, path: str) -> dict[str, Any]:
        return {"data": self._collections.get(path, [])}

    def post(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        self.posts.append((path, body))
        return {"data": {"id": "fake"}}

    def patch(self, path: str, body: dict[str, Any]) -> dict[str, Any]:  # pragma: no cover
        raise AssertionError(f"unexpected PATCH {path}")

    def request(self, method: str, path: str, body: dict[str, Any] | None = None) -> Any:
        self.requests.append((method, path, body))
        return {"data": {"id": "fake"}}


ITEMS_PATH = (
    "/reviewSubmissions/SUB1/items?limit=50&include=subscriptionVersion,appStoreVersion,inAppPurchaseVersion"
)


def _attached_ids(posts: list[tuple[str, dict[str, Any]]], relationship: str) -> set[str]:
    """Version ids attached to a review submission through one item relationship."""
    return {
        body["data"]["relationships"][relationship]["data"]["id"]
        for path, body in posts
        if path == "/reviewSubmissionItems" and relationship in body["data"]["relationships"]
    }


def dry_run_self_check() -> None:
    """Exercise the product-submission path offline so dry-run covers it."""
    app_id = "APP"
    groups_path = f"/apps/{app_id}/subscriptionGroups?limit=200"
    subs_path = "/subscriptionGroups/G1/subscriptions?limit=200"
    submission_path = (
        f"/apps/{app_id}/reviewSubmissions?"
        + urllib.parse.urlencode({"filter[state]": "READY_FOR_REVIEW", "limit": "5"})
    )
    weekly = "com.quitall.premium.weekly"
    yearly = "com.quitall.premium.yearly"
    lifetime = "com.quitall.premium.lifetime"
    collections: dict[str, list[dict[str, Any]]] = {
        groups_path: [{"id": "G1"}],
        subs_path: [
            # Weekly is still DEVELOPER_REJECTED from a prior submit.
            {"id": "S0", "attributes": {"name": "Weekly", "productId": weekly, "state": "DEVELOPER_REJECTED"}},
            {"id": "S1", "attributes": {"name": "Yearly", "productId": yearly, "state": "READY_TO_SUBMIT"}},
            # Not in the catalog: must never be submitted.
            {"id": "SX", "attributes": {"name": "Legacy", "productId": "com.quitall.premium.monthly",
                                        "state": "READY_TO_SUBMIT"}},
        ],
        submission_path: [{"id": "SUB1"}],
        f"/apps/{app_id}/inAppPurchasesV2?limit=200": [
            {"id": "IAP1", "attributes": {"name": "Lifetime", "productId": lifetime, "state": "READY_TO_SUBMIT"}},
            # Already approved: must not be resubmitted.
            {"id": "IAP2", "attributes": {"name": "Old lifetime", "productId": "com.quitall.premium.lifetime.v0",
                                          "state": "APPROVED"}},
        ],
    }
    for i in range(2):
        # Two versions returned out of order: the higher-numbered current
        # version must win regardless of response ordering.
        collections[f"/subscriptions/S{i}/versions"] = [
            {"id": f"V{i}b", "attributes": {"version": 2, "state": "READY_FOR_REVIEW"}},
            {"id": f"V{i}", "attributes": {"version": 1, "state": "DEVELOPER_REJECTED"}},
        ]
    # The lifetime purchase's approved version 1 and its new version 2, out of order.
    collections[f"{ASC_V2_BASE}/inAppPurchases/IAP1/versions"] = [
        {"id": "IV1", "attributes": {"version": 1, "state": "APPROVED"}},
        {"id": "IV2", "attributes": {"version": 2, "state": "PREPARE_FOR_SUBMISSION"}},
    ]
    intended = {weekly, yearly, lifetime, "com.quitall.premium.lifetime.v0"}
    fake = _RecordingClient(collections)
    result = submit_in_app_purchases(fake, app_id, intended_ids=intended)
    assert result.submitted == 3, f"expected 3 products, got {result.submitted}"
    assert result.added_items, "expected added_items=True"
    assert result.has_products, "expected has_products=True"
    assert result.submission_id == "SUB1", f"wrong submission: {result.submission_id}"
    item_posts = [body for path, body in fake.posts if path == "/reviewSubmissionItems"]
    attached_versions = _attached_ids(fake.posts, "subscriptionVersion")
    assert attached_versions == {"V0b", "V1b"}, (
        f"expected the current (v2) version of each subscription, got {attached_versions}"
    )
    attached_purchases = _attached_ids(fake.posts, "inAppPurchaseVersion")
    assert attached_purchases == {"IV2"}, (
        f"only the Ready-to-Submit lifetime purchase's current version may be attached, got {attached_purchases}"
    )
    assert all(
        body["data"]["relationships"]["reviewSubmission"]["data"]["id"] == "SUB1"
        for body in item_posts
    ), "wrong review submission target"
    assert not [path for path, _ in fake.posts if path == "/inAppPurchaseSubmissions"], (
        "the deprecated immediate in-app purchase submission must not be used"
    )
    assert not fake.requests, "attaching products must not submit anything"

    # Retry: the same draft already holds a subscription version and the lifetime
    # purchase's version, so the rerun must not post them again (App Store
    # Connect rejects duplicates).
    collections[ITEMS_PATH] = [
        {
            "id": "ITEM0",
            "relationships": {
                "subscriptionVersion": {"data": {"type": "subscriptionVersions", "id": "V0b"}},
                "appStoreVersion": {"data": None},
            },
        },
        {
            "id": "ITEM1",
            "relationships": {
                "inAppPurchaseVersion": {"data": {"type": "inAppPurchaseVersions", "id": "IV2"}},
                "appStoreVersion": {"data": None},
            },
        },
    ]
    retry = _RecordingClient(collections)
    result2 = submit_in_app_purchases(retry, app_id, intended_ids=intended)
    assert result2.submitted == 3, f"expected 3 products on retry, got {result2.submitted}"
    assert result2.has_products, "retry must report the draft holds products"
    retry_versions = _attached_ids(retry.posts, "subscriptionVersion") | _attached_ids(
        retry.posts, "inAppPurchaseVersion"
    )
    assert retry_versions == {"V1b"}, f"retry attached the wrong versions: {retry_versions}"
    assert draft_holds_app_version(retry, "SUB1") is False, "false app-version detection"

    collections[ITEMS_PATH] = [
        {
            "id": "ITEMV",
            "relationships": {
                "appStoreVersion": {"data": {"type": "appStoreVersions", "id": "AV1"}},
                "subscriptionVersion": {"data": None},
            },
        }
    ]
    assert draft_holds_app_version(_RecordingClient(collections), "SUB1") is True, (
        "app-version items must be detected and refused"
    )

    # submit_for_review must not re-add an app version already in the draft.
    review = _RecordingClient(collections)
    submit_for_review(review, app_id, "AV1", "PREPARE_FOR_SUBMISSION", submission_id="SUB1")
    assert not [path for path, _ in review.posts if path == "/reviewSubmissionItems"], (
        "app version was posted again on retry"
    )
    assert any(
        method == "PATCH"
        and path == "/reviewSubmissions/SUB1"
        and body is not None
        and body["data"]["attributes"]["submitted"] is True
        for method, path, body in review.requests
    ), "submission was not PATCHed to submitted=true"
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
) -> dict[str, dict[str, list[Path]]]:
    """Check every repo input before any App Store Connect call.

    Returns the screenshot sets to upload per locale (empty unless screenshots are on).
    """
    if (upload_listing or upload_whats_new or upload_screenshots) and not locales:
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
    return sets


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
    client: AscClient,
    *,
    bundle_id: str,
    expected_app_id: str,
    version_string: str,
    locales: list[str],
    metadata_dir: Path,
    do_listing: bool,
    do_whats_new: bool,
    do_screenshots: bool,
    screenshot_sets: dict[str, dict[str, list[Path]]],
    do_submit: bool,
) -> None:
    """Read-only App Store Connect checks before anything is built or uploaded.

    GET requests only: the App Store version must exist (the automation never
    creates one), be in a state the enabled switches can use and have every
    repository locale, and its metadata must be changeable where it differs.
    The live step repeats every check, because App Store Connect can change
    while the build is processed.
    """
    app_id = find_app(client, bundle_id)
    if app_id != expected_app_id:
        fail(f"{bundle_id} resolved to App Store Connect app {app_id}, expected {expected_app_id}")
    version = get_ios_app_store_version(client, app_id, version_string)
    state = (version.get("attributes") or {}).get("appStoreState") or ""
    edits_metadata = do_listing or do_whats_new or do_screenshots
    problems = version_state_problems(state, version_string, edits_metadata=edits_metadata, submit=do_submit)
    if do_submit and state == "WAITING_FOR_REVIEW":
        problems.append(
            f"version {version_string!r} is already WAITING_FOR_REVIEW, so the build this run would "
            "upload could never be selected; take the version out of review in App Store Connect first"
        )
    if not problems and edits_metadata:
        plans = plan_metadata(
            client,
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
        "--locale",
        action="append",
        help="Only these locales (repeatable). Default: every locale directory in the repo",
    )
    parser.add_argument("--bundle-id", default=DEFAULT_BUNDLE_ID)
    parser.add_argument("--app-id", default=DEFAULT_APP_ID, help="Expected App Store Connect app id")
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
        help="Validate flags and local files only — no ASC HTTP calls",
    )
    parser.add_argument(
        "--preflight",
        action="store_true",
        help="Read-only App Store Connect checks before the build is uploaded (GET requests only)",
    )
    args = parser.parse_args(argv)

    do_listing = truthy("UPLOAD_LISTING")
    do_whats_new = truthy("UPLOAD_WHATS_NEW")
    do_screenshots = truthy("UPLOAD_SCREENSHOTS")
    do_submit = truthy("SUBMIT_IOS_REVIEW")
    do_public = truthy("PUBLIC_RELEASE")

    if not (do_listing or do_whats_new or do_screenshots or do_submit):
        print(
            "ASC release skipped — UPLOAD_LISTING / UPLOAD_WHATS_NEW / "
            "UPLOAD_SCREENSHOTS / SUBMIT_IOS_REVIEW are off"
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
    )

    if args.dry_run:
        print("ASC dry-run — local inputs OK; no API calls")
        print(
            f"  bundle={args.bundle_id} locales={','.join(locales)} listing={do_listing} "
            f"whats_new={do_whats_new} screenshots={do_screenshots} submit={do_submit} "
            f"public_release={do_public}"
        )
        for locale, sets in screenshot_sets.items():
            for display_type, pngs in sets.items():
                print(f"  {locale} {display_type}: {len(pngs)} screenshot(s)")
        if do_submit:
            dry_run_self_check()
        return

    if not args.version:
        fail("--version is required for live ASC calls (pass marketing version from tag)")

    client = client_from_environment()
    edits_metadata = do_listing or do_whats_new or do_screenshots
    if args.preflight:
        preflight(
            client,
            bundle_id=args.bundle_id,
            expected_app_id=args.app_id,
            version_string=args.version,
            locales=locales,
            metadata_dir=args.metadata_dir,
            do_listing=do_listing,
            do_whats_new=do_whats_new,
            do_screenshots=do_screenshots,
            screenshot_sets=screenshot_sets,
            do_submit=do_submit,
        )
        return

    app_id = find_app(client, args.bundle_id)
    if app_id != args.app_id:
        fail(f"{args.bundle_id} resolved to App Store Connect app {app_id}, expected {args.app_id}")
    version = get_ios_app_store_version(client, app_id, args.version)
    version_id = version["id"]
    state = (version.get("attributes") or {}).get("appStoreState") or ""
    print(
        f"ASC app={app_id} version={args.version} id={version_id} state={state}"
    )

    problems = version_state_problems(state, args.version, edits_metadata=edits_metadata, submit=do_submit)
    if problems:
        fail("; ".join(problems))
    in_review = state == "WAITING_FOR_REVIEW"
    if in_review and do_submit:
        # A rerun after a successful submit: only accept it if review holds
        # exactly this run's build.
        confirm_selected_build(client, version_id, args.build_id)

    if edits_metadata:
        # Read everything first, so a change the version's state cannot take
        # fails before anything is written. Only what differs is written, which
        # also makes a rerun after a started or completed submission work.
        plans = plan_metadata(
            client,
            version_id=version_id,
            locales=locales,
            metadata_dir=args.metadata_dir,
            include_listing=do_listing,
            include_whats_new=do_whats_new,
            screenshot_sets=screenshot_sets,
        )
        problems = metadata_problems(plans, version=args.version, state=state)
        if problems:
            fail(
                "cannot update the version metadata (nothing was changed):\n  "
                + "\n  ".join(problems)
                + "\n  To change it, take the version out of review in App Store Connect, then rerun."
            )
        print("updating App Store metadata (only what differs)…")
        apply_metadata(client, plans)

    if in_review:
        if do_submit:
            print(
                "ASC submit skipped — version already WAITING_FOR_REVIEW with this run's "
                "build (idempotent)"
            )
            try:
                result = submit_in_app_purchases(client, app_id)
            except ProductSubmitError as exc:
                fail(str(exc))
            # Attaching a product to a fresh draft does not submit it. If the
            # version is already under review, the draft holding the late
            # products must be submitted on its own or they never reach review.
            # `has_products` also covers a retry where an earlier run attached
            # the products but failed to submit their draft. Only submit a
            # product-only draft: refuse if it holds an app version (e.g.
            # another release's) so unrelated items never ship.
            if result.has_products and result.submission_id:
                if draft_holds_app_version(client, result.submission_id):
                    fail(
                        "refusing to submit a draft that contains an app "
                        "version; remove it in App Store Connect and rerun"
                    )
                submit_product_draft(client, result.submission_id)
        print("ASC release step finished")
        return

    if do_submit:
        print("selecting this run's build…")
        select_build(client, version_id, args.build_id, args.version, args.build_number)
        set_release_type(client, version_id, public_release=do_public)
        print("attaching in-app purchases / subscriptions to the review submission…")
        submission_id = get_or_create_draft_submission(client, app_id)
        try:
            result = submit_in_app_purchases(
                client, app_id, submission_id=submission_id
            )
        except ProductSubmitError as exc:
            # A first-time subscription must ship with the version, so a failed
            # required product blocks the whole submission rather than letting
            # the version enter review without it.
            fail(f"{exc} Not submitting the app version.")
        # Recheck immediately before submitting: the selection must still be
        # this run's processed build. Nothing has reached App Review yet; the
        # version and its products go out together with the one submit below.
        verify_build(client, args.build_id, args.version, args.build_number)
        confirm_selected_build(client, version_id, args.build_id)
        print("submitting for App Store review…")
        submit_for_review(
            client, app_id, version_id, state, submission_id=submission_id
        )
        print(f"  {result.submitted} product(s) went out with the version")

    print("ASC release step finished")


if __name__ == "__main__":
    main()
