#!/usr/bin/env python3
"""Offline tests for iOS release switches, build waiting, build selection and repo inputs.

No network: every App Store Connect call goes to an in-memory fake.
Run: python3 -m unittest scripts/store/test_ios_release.py
"""
from __future__ import annotations

import io
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))

import asc_release  # noqa: E402
import ios_release  # noqa: E402
from ios_release import ReleaseError, resolve_gates  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
TAG = "v1.2.2"
VERSION = "1.2.2"
ALL_ON = {
    "IOS_RELEASE_AUTOMATION": "true",
    "IOS_UPLOAD_BUILD": "true",
    "IOS_UPLOAD_LISTING": "true",
    "IOS_UPLOAD_WHATS_NEW": "true",
    "IOS_UPLOAD_SCREENSHOTS": "true",
    "IOS_SUBMIT_REVIEW": "true",
    "IOS_PUBLIC_RELEASE": "true",
}
OPS = ("upload_build", "listing", "whats_new", "screenshots", "submit", "public_release")
ASC_FLAGS = {"UPLOAD_LISTING", "UPLOAD_WHATS_NEW", "UPLOAD_SCREENSHOTS", "SUBMIT_IOS_REVIEW", "PUBLIC_RELEASE"}


def gates(env: dict[str, str], *, event: str = "push", ref: str = TAG) -> dict:
    return resolve_gates(env, event=event, ref_name=ref, marketing_version=VERSION)


class GateTests(unittest.TestCase):
    def test_missing_settings_mean_everything_off(self) -> None:
        result = gates({})
        self.assertEqual(result["mode"], "release")
        self.assertFalse(result["master"])
        self.assertFalse(result["build"])
        self.assertFalse(result["asc"])
        for key in OPS:
            self.assertFalse(result[key], key)
        self.assertEqual(result["poll_seconds"], 30)
        self.assertEqual(result["wait_minutes"], 120)

    def test_master_off_ignores_operation_switches(self) -> None:
        result = gates({**ALL_ON, "IOS_RELEASE_AUTOMATION": "false"})
        for key in OPS:
            self.assertFalse(result[key], key)
        self.assertFalse(result["build"])
        self.assertTrue(any("ignored" in note for note in result["notes"]))

    def test_each_operation_is_independent(self) -> None:
        result = gates({"IOS_RELEASE_AUTOMATION": "yes", "IOS_UPLOAD_LISTING": "on"})
        self.assertTrue(result["listing"])
        self.assertTrue(result["asc"])
        self.assertFalse(result["whats_new"])
        self.assertFalse(result["upload_build"])
        self.assertFalse(result["build"])
        result = gates({"IOS_RELEASE_AUTOMATION": "1", "IOS_UPLOAD_BUILD": "1"})
        self.assertTrue(result["build"])
        self.assertFalse(result["asc"], "uploading a build alone touches no listing")

    def test_all_on(self) -> None:
        result = gates(ALL_ON)
        for key in OPS:
            self.assertTrue(result[key], key)
        self.assertTrue(result["build"])
        self.assertTrue(result["master"])

    def test_every_accepted_spelling(self) -> None:
        for value in ("true", "TRUE", " yes ", "on", "1"):
            self.assertTrue(gates({"IOS_RELEASE_AUTOMATION": value, "IOS_UPLOAD_LISTING": value})["listing"], value)
        for value in ("false", "No", "off", "0", ""):
            self.assertFalse(gates({"IOS_RELEASE_AUTOMATION": "true", "IOS_UPLOAD_LISTING": value})["listing"], value)

    def test_invalid_values_are_rejected_even_when_master_is_off(self) -> None:
        for name in ("IOS_RELEASE_AUTOMATION", "IOS_UPLOAD_BUILD", "IOS_SUBMIT_REVIEW",
                     "IOS_UPLOAD_WHATS_NEW", "IOS_PUBLIC_RELEASE"):
            with self.subTest(name=name), self.assertRaisesRegex(ReleaseError, name):
                gates({name: "maybe"})
        with self.assertRaisesRegex(ReleaseError, "IOS_UPLOAD_SCREENSHOTS"):
            gates({"IOS_RELEASE_AUTOMATION": "false", "IOS_UPLOAD_SCREENSHOTS": "enabled"})

    def test_invalid_values_also_fail_manual_validation_runs(self) -> None:
        with self.assertRaisesRegex(ReleaseError, "IOS_UPLOAD_LISTING"):
            gates({"IOS_UPLOAD_LISTING": "yep"}, event="workflow_dispatch", ref="main")

    def test_bad_timing_values_are_rejected(self) -> None:
        for env in (
            {"IOS_BUILD_POLL_SECONDS": "5"},
            {"IOS_BUILD_POLL_SECONDS": "601"},
            {"IOS_BUILD_POLL_SECONDS": "thirty"},
            {"IOS_BUILD_POLL_SECONDS": "٣٠"},
            {"IOS_BUILD_WAIT_MINUTES": "0"},
            {"IOS_BUILD_WAIT_MINUTES": "9"},
            {"IOS_BUILD_WAIT_MINUTES": "301"},
            {"IOS_BUILD_WAIT_MINUTES": "-5"},
        ):
            with self.subTest(env=env), self.assertRaises(ReleaseError):
                gates(env)
        result = gates({"IOS_BUILD_POLL_SECONDS": "45", "IOS_BUILD_WAIT_MINUTES": "90"})
        self.assertEqual((result["poll_seconds"], result["wait_minutes"]), (45, 90))
        result = gates({"IOS_BUILD_POLL_SECONDS": "10", "IOS_BUILD_WAIT_MINUTES": "300"})
        self.assertEqual((result["poll_seconds"], result["wait_minutes"]), (10, 300))

    def test_submit_requires_this_runs_build(self) -> None:
        env = {"IOS_RELEASE_AUTOMATION": "true", "IOS_SUBMIT_REVIEW": "true"}
        with self.assertRaisesRegex(ReleaseError, "IOS_UPLOAD_BUILD"):
            gates(env)

    def test_public_release_requires_submit(self) -> None:
        env = {"IOS_RELEASE_AUTOMATION": "true", "IOS_UPLOAD_BUILD": "true", "IOS_PUBLIC_RELEASE": "true"}
        with self.assertRaisesRegex(ReleaseError, "IOS_SUBMIT_REVIEW"):
            gates(env)

    def test_tag_must_match_marketing_version_exactly(self) -> None:
        for ref in ("v1.2.3", "v1.2", "v1.2.2.0", "v1.2.2-beta", "V1.2.2"):
            with self.subTest(ref=ref), self.assertRaises(ReleaseError):
                gates({}, ref=ref)
        with self.assertRaisesRegex(ReleaseError, "v\\* tag"):
            gates({}, ref="1.2.2")
        with self.assertRaisesRegex(ReleaseError, "v\\* tag"):
            gates({}, ref="ios-v1.2.2")

    def test_unsupported_events_are_refused(self) -> None:
        for event in ("pull_request", "schedule", ""):
            with self.subTest(event=event), self.assertRaisesRegex(ReleaseError, "unsupported event"):
                gates({}, event=event)

    def test_manual_run_validates_only(self) -> None:
        result = gates(ALL_ON, event="workflow_dispatch", ref="main")
        self.assertEqual(result["mode"], "validate")
        self.assertTrue(result["build"])
        self.assertFalse(result["master"])
        self.assertFalse(result["asc"])
        for key in OPS:
            self.assertFalse(result[key], key)

    def test_manual_run_can_validate_a_future_version(self) -> None:
        result = resolve_gates({}, event="workflow_dispatch", ref_name="main",
                               marketing_version="1.2.1", validation_version="1.2.2")
        self.assertEqual(result["mode"], "validate")
        self.assertEqual(result["marketing_version"], "1.2.2")
        self.assertFalse(result["asc"])
        self.assertTrue(any("1.2.2" in note for note in result["notes"]))
        default = resolve_gates({}, event="workflow_dispatch", ref_name="main", marketing_version="1.2.1")
        self.assertEqual(default["marketing_version"], "1.2.1")

    def test_version_override_is_rejected_for_releases_and_bad_values(self) -> None:
        with self.assertRaisesRegex(ReleaseError, "manual validation"):
            resolve_gates({}, event="push", ref_name=TAG, marketing_version=VERSION, validation_version="1.2.3")
        for bad in ("1.x", "v1.2.2", "1.2.2.1", "1.2.2 beta", "١.٢"):
            with self.subTest(bad=bad), self.assertRaisesRegex(ReleaseError, "must look like"):
                resolve_gates({}, event="workflow_dispatch", ref_name="main",
                              marketing_version=VERSION, validation_version=bad)

    def test_project_versions_are_consistent(self) -> None:
        self.assertRegex(ios_release.single_project_value("MARKETING_VERSION"), r"^\d+(\.\d+){0,2}$")
        self.assertRegex(ios_release.single_project_value("CURRENT_PROJECT_VERSION"), r"^\d+$")
        # App and widget must ship the same version and build.
        self.assertEqual(len(ios_release.project_values("MARKETING_VERSION")), 1)
        with tempfile.TemporaryDirectory() as tmp:
            pbx = Path(tmp) / "project.pbxproj"
            pbx.write_text("MARKETING_VERSION = 1.0;\nMARKETING_VERSION = 1.1;\n")
            with self.assertRaisesRegex(ReleaseError, "identical"):
                ios_release.single_project_value("MARKETING_VERSION", pbx)

    def test_gates_command_writes_outputs(self) -> None:
        with tempfile.NamedTemporaryFile("r", suffix=".out") as out, mock.patch.dict(
            os.environ,
            {"GITHUB_OUTPUT": out.name, "GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_REF_NAME": "main",
             "VALIDATION_MARKETING_VERSION": "9.9.9", "IOS_UPLOAD_BUILD": "true"},
            clear=True,
        ), redirect_stdout(io.StringIO()):
            ios_release.main(["gates"])
            written = Path(out.name).read_text()
        self.assertIn("mode=validate", written)
        self.assertIn("build=true", written)
        self.assertIn("upload_build=false", written)
        self.assertIn("marketing_version=9.9.9", written)

    def test_gates_command_exits_non_zero_on_bad_switch(self) -> None:
        with mock.patch.dict(os.environ, {"GITHUB_EVENT_NAME": "push", "GITHUB_REF_NAME": TAG,
                                          "IOS_UPLOAD_BUILD": "sometimes"}, clear=True), \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()) as err, \
                self.assertRaises(SystemExit) as raised:
            ios_release.main(["gates"])
        self.assertEqual(raised.exception.code, 1)
        self.assertIn("IOS_UPLOAD_BUILD", err.getvalue())


class BuildNumberTests(unittest.TestCase):
    def test_next_build_number(self) -> None:
        # Quit All's App Store Connect history restarts build numbers per version.
        self.assertEqual(ios_release.next_build_number(6, ["1", "1", "1", "2", "2", "3", "3", "4", "5"]), 6)
        self.assertEqual(ios_release.next_build_number(6, ["6", "2"]), 7)
        self.assertEqual(ios_release.next_build_number(1, []), 1)
        self.assertEqual(ios_release.next_build_number(5, ["7.1", "abc", "9"]), 10)
        self.assertEqual(ios_release.next_build_number(5, ["٩٩"]), 5)  # only ASCII digits count


APP = "APP1"
STARTED = 1_800_000_000.0  # this run's upload start (epoch seconds)


def iso(epoch: float) -> str:
    import datetime as dt

    return dt.datetime.fromtimestamp(epoch, dt.timezone.utc).isoformat()


def build_row(
    build_id: str = "B1",
    *,
    number: str = "6",
    state: str = "VALID",
    expired: bool = False,
    uploaded: float = STARTED + 60,
    app: str = APP,
    pre: str = "P1",
) -> dict:
    return {
        "type": "builds",
        "id": build_id,
        "attributes": {
            "version": number,
            "processingState": state,
            "expired": expired,
            "uploadedDate": iso(uploaded),
        },
        "relationships": {
            "preReleaseVersion": {"data": {"type": "preReleaseVersions", "id": pre}},
            "app": {"data": {"type": "apps", "id": app}},
        },
    }


def pre_row(pre_id: str = "P1", version: str = VERSION, platform: str = "IOS") -> dict:
    return {"type": "preReleaseVersions", "id": pre_id, "attributes": {"version": version, "platform": platform}}


class FakeClock:
    def __init__(self, start: float) -> None:
        self.time = start
        self.sleeps: list[float] = []

    def now(self) -> float:
        return self.time

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.time += seconds


class SequenceClient:
    """Returns queued /builds payloads (or raises queued exceptions) per GET."""

    def __init__(self, responses: list) -> None:
        self.responses = list(responses)
        self.paths: list[str] = []

    def get(self, path: str) -> dict:
        self.paths.append(path)
        item = self.responses.pop(0) if len(self.responses) > 1 else self.responses[0]
        if isinstance(item, BaseException):
            raise item
        return item


def wait(client: SequenceClient, clock: FakeClock, *, minutes: int = 120, transient=None) -> dict:
    with redirect_stdout(io.StringIO()):
        return ios_release.wait_for_build(
            client,
            app_id=APP,
            marketing_version=VERSION,
            build_number="6",
            uploaded_after=STARTED,
            deadline=STARTED + minutes * 60,
            poll_seconds=30,
            now=clock.now,
            sleep=clock.sleep,
            is_transient=transient,
        )


class WaitForBuildTests(unittest.TestCase):
    def test_waits_through_missing_and_processing_then_returns_build(self) -> None:
        client = SequenceClient(
            [
                {"data": []},
                {"data": [build_row(state="PROCESSING")], "included": [pre_row()]},
                {"data": [build_row()], "included": [pre_row()]},
            ]
        )
        clock = FakeClock(STARTED + 120)
        build = wait(client, clock)
        self.assertEqual(build["id"], "B1")
        self.assertEqual(clock.sleeps, [30, 30])
        self.assertIn("filter%5Bversion%5D=6", client.paths[0])
        self.assertIn("filter%5Bapp%5D=APP1", client.paths[0])

    def test_times_out_without_using_another_build(self) -> None:
        client = SequenceClient([{"data": [build_row(state="PROCESSING")], "included": [pre_row()]}])
        clock = FakeClock(STARTED)
        with self.assertRaisesRegex(ReleaseError, "timed out"):
            wait(client, clock, minutes=10)
        self.assertLessEqual(clock.time, STARTED + 10 * 60 + 30)

    def test_ready_build_after_the_deadline_is_still_a_timeout(self) -> None:
        client = SequenceClient([{"data": [build_row()], "included": [pre_row()]}])
        clock = FakeClock(STARTED + 121 * 60)  # job started after the 120-minute budget
        with self.assertRaisesRegex(ReleaseError, "timed out"):
            wait(client, clock)
        self.assertEqual(client.paths, [], "must not poll once the budget is spent")

    def test_processing_failure_stops(self) -> None:
        for state in ("FAILED", "INVALID"):
            client = SequenceClient([{"data": [build_row(state=state)], "included": [pre_row()]}])
            with self.subTest(state=state), self.assertRaisesRegex(ReleaseError, state):
                wait(client, FakeClock(STARTED))

    def test_expired_build_is_rejected(self) -> None:
        client = SequenceClient([{"data": [build_row(expired=True)], "included": [pre_row()]}])
        with self.assertRaisesRegex(ReleaseError, "expired"):
            wait(client, FakeClock(STARTED))

    def test_ambiguous_match_stops(self) -> None:
        client = SequenceClient(
            [{"data": [build_row("B1"), build_row("B2")], "included": [pre_row()]}]
        )
        with self.assertRaisesRegex(ReleaseError, "ambiguous"):
            wait(client, FakeClock(STARTED))

    def test_older_upload_is_never_substituted(self) -> None:
        old = build_row(uploaded=STARTED - 3600)
        client = SequenceClient([{"data": [old], "included": [pre_row()]}])
        with self.assertRaisesRegex(ReleaseError, "older build"):
            wait(client, FakeClock(STARTED))

    def test_other_versions_and_platforms_are_ignored(self) -> None:
        other_version = build_row("BX", pre="P2")
        other_platform = build_row("BY", pre="P3")
        client = SequenceClient(
            [
                {
                    "data": [other_version, other_platform],
                    "included": [pre_row("P2", "1.2.1"), pre_row("P3", VERSION, "MAC_OS")],
                },
                {"data": [other_version, build_row("B1")], "included": [pre_row("P2", "1.2.1"), pre_row()]},
            ]
        )
        self.assertEqual(wait(client, FakeClock(STARTED))["id"], "B1")

    def test_build_from_another_app_is_a_mismatch(self) -> None:
        client = SequenceClient([{"data": [build_row(app="OTHER")], "included": [pre_row()]}])
        with self.assertRaisesRegex(ReleaseError, "another app"):
            wait(client, FakeClock(STARTED))

    def test_transient_errors_are_retried_and_others_raise(self) -> None:
        transient = asc_release.AscHttpError(503, "unavailable")
        client = SequenceClient([transient, {"data": [build_row()], "included": [pre_row()]}])
        with redirect_stderr(io.StringIO()):
            build = wait(client, FakeClock(STARTED), transient=lambda exc: getattr(exc, "status", 0) == 503)
        self.assertEqual(build["id"], "B1")
        fatal = SequenceClient([asc_release.AscHttpError(401, "unauthorized")])
        with self.assertRaises(SystemExit):
            wait(fatal, FakeClock(STARTED), transient=lambda exc: getattr(exc, "status", 0) == 503)


class SelectionClient:
    """Fake ASC client for build verification and selection."""

    def __init__(self, *, build: dict, included: list, attached: str | None, sticky: bool = True) -> None:
        self.build = build
        self.included = included
        self.attached = attached
        self.sticky = sticky
        self.calls: list[tuple[str, str, dict | None]] = []

    def get(self, path: str) -> dict:
        self.calls.append(("GET", path, None))
        if path.startswith(f"/builds/{self.build['id']}"):
            return {"data": self.build, "included": self.included}
        if path.endswith("/build"):
            return {"data": {"type": "builds", "id": self.attached} if self.attached else None}
        raise AssertionError(f"unexpected GET {path}")

    def patch(self, path: str, body: dict) -> dict:
        self.calls.append(("PATCH", path, body))
        return {"data": body["data"]}

    def request(self, method: str, path: str, body: dict | None = None):
        self.calls.append((method, path, body))
        if method == "PATCH" and path.endswith("/relationships/build") and self.sticky:
            self.attached = body["data"]["id"]
        return None


def quiet(fn, *args, **kwargs):
    with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
        return fn(*args, **kwargs)


class BuildSelectionTests(unittest.TestCase):
    def test_selects_and_reads_back_this_runs_build(self) -> None:
        client = SelectionClient(build=build_row("B9"), included=[pre_row()], attached="OLD")
        quiet(asc_release.select_build, client, "V1", "B9", VERSION, "6")
        self.assertEqual(client.attached, "B9")
        methods = [(m, p) for m, p, _ in client.calls]
        self.assertIn(("PATCH", "/appStoreVersions/V1/relationships/build"), methods)
        self.assertEqual(methods[-1], ("GET", "/appStoreVersions/V1/build"))

    def test_selection_that_does_not_stick_fails(self) -> None:
        client = SelectionClient(build=build_row("B9"), included=[pre_row()], attached="OLD", sticky=False)
        with self.assertRaises(SystemExit):
            quiet(asc_release.select_build, client, "V1", "B9", VERSION, "6")

    def test_unprocessed_expired_or_wrong_build_is_refused(self) -> None:
        cases = {
            "processing": (build_row("B9", state="PROCESSING"), [pre_row()]),
            "expired": (build_row("B9", expired=True), [pre_row()]),
            "number": (build_row("B9", number="7"), [pre_row()]),
            "version": (build_row("B9"), [pre_row(version="1.2.1")]),
            "platform": (build_row("B9"), [pre_row(platform="TV_OS")]),
        }
        for label, (build, included) in cases.items():
            client = SelectionClient(build=build, included=included, attached=None)
            with self.subTest(label), self.assertRaises(SystemExit):
                quiet(asc_release.select_build, client, "V1", "B9", VERSION, "6")
            self.assertFalse([c for c in client.calls if c[0] == "PATCH"], label)

    def test_release_type(self) -> None:
        for public, expected in ((True, "AFTER_APPROVAL"), (False, "MANUAL")):
            client = SelectionClient(build=build_row(), included=[], attached=None)
            quiet(asc_release.set_release_type, client, "V1", public_release=public)
            body = client.calls[-1][2]
            self.assertEqual(body["data"]["attributes"]["releaseType"], expected)


class TokenRefreshTests(unittest.TestCase):
    def test_token_is_reminted_during_long_waits(self) -> None:
        minted: list[str] = []

        def factory() -> str:
            minted.append(f"t{len(minted)}")
            return minted[-1]

        with mock.patch.object(asc_release.time, "monotonic", side_effect=[0, 100, 700, 700, 800]):
            client = asc_release.AscClient(token_factory=factory)
            self.assertEqual(client._authorization(), "Bearer t0")
            self.assertEqual(client._authorization(), "Bearer t1")
            self.assertEqual(client._authorization(), "Bearer t1")

    def test_tokens_are_short_lived_es256_for_app_store_connect(self) -> None:
        try:
            import jwt  # noqa: F401
            from cryptography.hazmat.primitives import serialization
            from cryptography.hazmat.primitives.asymmetric import ec
        except ImportError:
            self.skipTest("PyJWT is installed only with requirements-store.txt")
        key = ec.generate_private_key(ec.SECP256R1())
        pem = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8,
                                serialization.NoEncryption()).decode()
        token = asc_release.make_asc_token("KEYID", "ISSUER", pem)
        header = jwt.get_unverified_header(token)
        claims = jwt.decode(token, key.public_key(), algorithms=["ES256"], audience="appstoreconnect-v1")
        self.assertEqual((header["alg"], header["kid"]), ("ES256", "KEYID"))
        self.assertEqual(claims["iss"], "ISSUER")
        self.assertLessEqual(claims["exp"] - claims["iat"], 1200)


class AscCliTests(unittest.TestCase):
    def run_cli(self, env: dict[str, str], *args: str) -> tuple[int, str]:
        out = io.StringIO()
        full_env = {k: v for k, v in os.environ.items() if k not in ASC_FLAGS}
        full_env.update(env)
        with mock.patch.dict(os.environ, full_env, clear=True), mock.patch.object(
            sys, "argv", ["asc_release.py", "--dry-run", *args]
        ), redirect_stdout(out), redirect_stderr(out):
            try:
                asc_release.main()
            except SystemExit as exc:
                return (exc.code if isinstance(exc.code, int) else 1), out.getvalue()
        return 0, out.getvalue()

    def test_everything_off_is_a_no_op(self) -> None:
        code, output = self.run_cli({})
        self.assertEqual(code, 0)
        self.assertIn("skipped", output)

    def test_submit_without_this_runs_build_fails(self) -> None:
        code, output = self.run_cli({"SUBMIT_IOS_REVIEW": "true"})
        self.assertEqual(code, 1)
        self.assertIn("--build-id", output)

    def test_public_release_without_submit_fails(self) -> None:
        code, _ = self.run_cli({"UPLOAD_LISTING": "true", "PUBLIC_RELEASE": "true"})
        self.assertEqual(code, 1)

    def test_whats_new_requires_text_and_a_matching_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            loc = Path(tmp) / "ios" / "en-US"
            loc.mkdir(parents=True)
            code, output = self.run_cli({"UPLOAD_WHATS_NEW": "true"}, "--metadata-dir", tmp, "--version", VERSION)
            self.assertEqual(code, 1)
            self.assertIn("whats_new.txt", output)

            (loc / "whats_new.txt").write_text("Fixes\n")
            (Path(tmp) / "ios" / "whats_new_version.txt").write_text("1.2.1\n")
            code, output = self.run_cli({"UPLOAD_WHATS_NEW": "true"}, "--metadata-dir", tmp, "--version", VERSION)
            self.assertEqual(code, 1, "stale What's New text must not ship")
            self.assertIn("says the text is for 1.2.1", output)

            code, output = self.run_cli({"UPLOAD_WHATS_NEW": "true"}, "--metadata-dir", tmp)
            self.assertEqual(code, 1, "the version is required to check the text")

            (Path(tmp) / "ios" / "whats_new_version.txt").write_text(f"{VERSION}\n")
            code, output = self.run_cli({"UPLOAD_WHATS_NEW": "true"}, "--metadata-dir", tmp, "--version", VERSION)
            self.assertEqual(code, 0, output)

    def test_listing_text_is_checked_before_upload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            loc = Path(tmp) / "ios" / "en-US"
            loc.mkdir(parents=True)
            files = {
                "description.txt": "A" * 4000,
                "keywords.txt": "quit,habits",
                "promotional_text.txt": "Promo",
                "marketing_url.txt": "https://quit-all.com",
                "support_url.txt": "https://quit-all.com",
            }
            for name, text in files.items():
                (loc / name).write_text(text)
            code, output = self.run_cli({"UPLOAD_LISTING": "true"}, "--metadata-dir", tmp)
            self.assertEqual(code, 0, output)

            for name, bad, message in (
                ("description.txt", "A" * 4001, "4001 characters"),
                ("keywords.txt", "k" * 101, "max 100"),
                ("promotional_text.txt", "p" * 171, "max 170"),
                ("support_url.txt", "quit-all.com", "not an http(s) URL"),
                ("marketing_url.txt", "", "missing or empty"),
            ):
                with self.subTest(name=name):
                    (loc / name).write_text(bad)
                    code, output = self.run_cli({"UPLOAD_LISTING": "true"}, "--metadata-dir", tmp)
                    self.assertEqual(code, 1)
                    self.assertIn(message, output)
                    (loc / name).write_text(files[name])

    def test_no_locales_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, output = self.run_cli({"UPLOAD_LISTING": "true"}, "--metadata-dir", tmp)
            self.assertEqual(code, 1)
            self.assertIn("no listing locales", output)

    def test_listing_excludes_whats_new_unless_enabled(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            loc = Path(tmp) / "ios" / "en-US"
            loc.mkdir(parents=True)
            (loc / "description.txt").write_text("Desc")
            (loc / "whats_new.txt").write_text("New")
            for whats_new, expected in ((False, {"description"}), (True, {"description", "whatsNew"})):
                client = mock.Mock()
                client.get.return_value = {"data": [{"id": "LOC", "attributes": {"locale": "en-US"}}]}
                quiet(
                    asc_release.upload_listing,
                    client,
                    app_id=APP,
                    version_id="V1",
                    locale="en-US",
                    metadata_dir=Path(tmp),
                    include_listing=True,
                    include_whats_new=whats_new,
                )
                attrs = client.patch.call_args[0][1]["data"]["attributes"]
                self.assertEqual(set(attrs), expected)

    def test_dry_run_submit_exercises_product_selection(self) -> None:
        code, output = self.run_cli({"SUBMIT_IOS_REVIEW": "true"}, "--build-id", "B9", "--build-number", "6")
        self.assertEqual(code, 0, output)
        self.assertIn("product submission selection OK", output)


def png(path: Path, width: int, height: int) -> None:
    """Writes a PNG signature and IHDR header; enough for the size check."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + width.to_bytes(4, "big")
                     + height.to_bytes(4, "big") + b"\x08\x06\x00\x00\x00")


class ScreenshotManifestTests(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.metadata = self.root / "store" / "metadata"
        (self.metadata / "ios" / "en-US").mkdir(parents=True)

    def write_manifest(self, manifest: object) -> None:
        (self.metadata / "ios" / "en-US" / "screenshots.json").write_text(json.dumps(manifest))

    def load(self) -> tuple[int, str, dict]:
        out = io.StringIO()
        with redirect_stdout(out), redirect_stderr(out):
            try:
                sets = asc_release.load_screenshot_sets(self.metadata, "en-US", self.root)
            except SystemExit as exc:
                return exc.code if isinstance(exc.code, int) else 1, out.getvalue(), {}
        return 0, out.getvalue(), sets

    def test_valid_manifest_keeps_its_order(self) -> None:
        for name in ("b.png", "a.png"):
            png(self.root / "shots/67" / name, 1260, 2736)
        png(self.root / "shots/65/a.png", 1242, 2688)
        self.write_manifest({"APP_IPHONE_67": ["shots/67/b.png", "shots/67/a.png"],
                             "APP_IPHONE_65": ["shots/65/a.png"]})
        code, output, sets = self.load()
        self.assertEqual(code, 0, output)
        self.assertEqual([p.name for p in sets["APP_IPHONE_67"]], ["b.png", "a.png"])
        self.assertEqual(len(sets["APP_IPHONE_65"]), 1)

    def test_missing_manifest_fails_clearly(self) -> None:
        code, output, _ = self.load()
        self.assertEqual(code, 1)
        self.assertIn("screenshots.json", output)

    def test_bad_entries_fail(self) -> None:
        png(self.root / "shots/ok.png", 1260, 2736)
        png(self.root / "shots/small.png", 1179, 2556)
        (self.root / "shots/fake.png").write_bytes(b"GIF89a not a png at all......")
        cases = {
            "unknown display type": ({"APP_IPAD_PRO_129": ["shots/ok.png"]}, "unsupported display type"),
            "wrong size": ({"APP_IPHONE_67": ["shots/small.png"]}, "1179x2556"),
            "size for another slot": ({"APP_IPHONE_65": ["shots/ok.png"]}, "1260x2736"),
            "not a png": ({"APP_IPHONE_67": ["shots/fake.png"]}, "not a PNG"),
            "missing file": ({"APP_IPHONE_67": ["shots/none.png"]}, "does not exist"),
            "escapes the repo": ({"APP_IPHONE_67": ["../shots/ok.png"]}, "relative to the repository root"),
            "absolute": ({"APP_IPHONE_67": ["/etc/hosts"]}, "relative to the repository root"),
            "empty": ({"APP_IPHONE_67": []}, "at least one"),
            "too many": ({"APP_IPHONE_67": ["shots/ok.png"] * 11}, "max 10"),
            "duplicate": ({"APP_IPHONE_67": ["shots/ok.png", "shots/ok.png"]}, "twice"),
            "not a mapping": (["shots/ok.png"], "must map display types"),
        }
        for label, (manifest, message) in cases.items():
            with self.subTest(label):
                self.write_manifest(manifest)
                code, output, _ = self.load()
                self.assertEqual(code, 1, label)
                self.assertIn(message, output)

    def test_screenshot_switch_without_any_manifest_fails(self) -> None:
        out = io.StringIO()
        with redirect_stdout(out), redirect_stderr(out), self.assertRaises(SystemExit):
            asc_release.validate_local_inputs(
                upload_listing=False, upload_whats_new=False, upload_screenshots=True,
                metadata_dir=self.metadata, locales=["en-US"], version=VERSION, root=self.root,
            )
        self.assertIn("no locale", out.getvalue())

    def test_replacing_a_full_set_keeps_the_manifest_order(self) -> None:
        class SetClient:
            def __init__(self) -> None:
                self.ids = [f"old{i}" for i in range(10)]
                self.events: list[str] = []

            def get(self, path: str) -> dict:
                if path.endswith("/appScreenshotSets"):
                    return {"data": [{"id": "SET", "attributes": {"screenshotDisplayType": "APP_IPHONE_67"}}]}
                if path.endswith("/appScreenshots"):
                    return {"data": [{"id": i} for i in self.ids]}
                raise AssertionError(path)

            def request(self, method: str, path: str, body: dict | None = None) -> None:
                assert method == "DELETE"
                shot = path.rsplit("/", 1)[-1]
                self.ids.remove(shot)
                self.events.append(f"delete {shot}")

        client = SetClient()
        uploaded: list[str] = []

        def fake_upload(_client, _set_id, path):
            assert len(client.ids) < 10, "uploads only when the set has room"
            client.ids.append(path.name)
            uploaded.append(path.name)

        pngs = [Path(f"{n}.png") for n in ("3", "2", "1")]
        with mock.patch.object(asc_release, "upload_screenshot_file", side_effect=fake_upload), \
                redirect_stdout(io.StringIO()):
            asc_release.replace_screenshot_set(client, "LOC", "APP_IPHONE_67", pngs)
        self.assertEqual(uploaded, ["3.png", "2.png", "1.png"])
        self.assertEqual(client.ids, ["3.png", "2.png", "1.png"], "old screenshots are all removed")


class RepoInputTests(unittest.TestCase):
    """The committed listing, screenshots and catalog are valid release inputs."""

    def test_committed_listing_and_screenshots_pass_validation(self) -> None:
        metadata = ROOT / "store" / "metadata"
        locales = asc_release.listing_locales(metadata)
        self.assertEqual(locales, ["en-US"])
        marker = (metadata / "ios" / "whats_new_version.txt").read_text().strip()
        with redirect_stdout(io.StringIO()):
            sets = asc_release.validate_local_inputs(
                upload_listing=True, upload_whats_new=True, upload_screenshots=True,
                metadata_dir=metadata, locales=locales, version=marker,
            )
        self.assertEqual(sorted(sets["en-US"]), ["APP_IPHONE_65", "APP_IPHONE_67"])
        for display_type, paths in sets["en-US"].items():
            self.assertEqual(len(paths), 10, display_type)

    def test_product_catalog_matches_the_app_and_storekit_file(self) -> None:
        catalog = json.loads((ROOT / "store" / "catalog" / "products.json").read_text())
        catalog_ids = asc_release.intended_product_ids()
        self.assertEqual(catalog_ids, {
            "com.quitall.premium.weekly", "com.quitall.premium.yearly", "com.quitall.premium.lifetime",
        })
        paywall = (ROOT / "ios" / "Quit All" / "Core" / "PaywallManager.swift").read_text()
        swift_ids = set(re.findall(r'case \w+ = "(com\.quitall\.[^"]+)"', paywall))
        self.assertEqual(swift_ids, catalog_ids, "SubscriptionProduct in PaywallManager.swift")
        storekit = json.loads((ROOT / "ios" / "Quit All" / "Products.storekit").read_text())
        storekit_ids = {p["productID"] for p in storekit["products"]} | {
            s["productID"] for group in storekit["subscriptionGroups"] for s in group["subscriptions"]
        }
        self.assertEqual(storekit_ids, catalog_ids, "Products.storekit")
        entitlements = set(re.findall(r'entitlementIDs = \[([^\]]+)\]', paywall)[0].replace('"', "").split(", "))
        self.assertEqual(entitlements, set(catalog["entitlements"]))
        self.assertEqual(catalog["app"]["bundle_id"], ios_release.BUNDLE_ID)
        self.assertEqual(catalog["app"]["asc_app_id"], ios_release.ASC_APP_ID)


class ReleaseNotesTests(unittest.TestCase):
    def run_notes(self, text: str, tag: str) -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as tmp:
            notes = Path(tmp) / "RELEASE_NOTES.md"
            notes.write_text(text)
            return subprocess.run(
                [sys.executable, str(ROOT / "scripts" / "release_notes.py"), tag, "--file", str(notes)],
                capture_output=True, text=True,
            )

    def test_matching_section_is_printed(self) -> None:
        result = self.run_notes("# Notes\n\n## v1.2.2\n\n- Faster SOS\n\n## v1.2.1\n\nOld\n", "v1.2.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "- Faster SOS")

    def test_missing_section_prints_nothing_so_github_generates_notes(self) -> None:
        result = self.run_notes("# Notes\n\n## v1.2.1\n\nOld\n", "v1.2.2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertIn("generate", result.stderr)

    def test_empty_section_fails(self) -> None:
        result = self.run_notes("## v1.2.2\n\n## v1.2.1\n\nOld\n", "v1.2.2")
        self.assertNotEqual(result.returncode, 0)

    def test_committed_notes_parse(self) -> None:
        result = subprocess.run([sys.executable, str(ROOT / "scripts" / "release_notes.py"), "v1.2.1"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.strip())


class TransientErrorTests(unittest.TestCase):
    def test_real_retry_rule(self) -> None:
        import http.client
        import urllib.error

        transient = [
            http.client.RemoteDisconnected("closed"),
            ConnectionResetError("reset"),
            http.client.IncompleteRead(b""),
            urllib.error.URLError("dns"),
            TimeoutError("slow"),
            asc_release.AscHttpError(503, "busy"),
            asc_release.AscHttpError(429, "rate limited"),
            urllib.error.HTTPError("https://x", 502, "bad gateway", {}, None),
        ]
        fatal = [
            asc_release.AscHttpError(401, "unauthorized"),
            asc_release.AscHttpError(409, "conflict"),
            urllib.error.HTTPError("https://x", 404, "missing", {}, None),
            ValueError("bad"),
            ReleaseError("mismatch"),
            SystemExit(1),
        ]
        for exc in transient:
            with self.subTest(exc=repr(exc)):
                self.assertTrue(ios_release.is_transient_error(exc))
        for exc in fatal:
            with self.subTest(exc=repr(exc)):
                self.assertFalse(ios_release.is_transient_error(exc))


class CmdWaitBuildTests(unittest.TestCase):
    def test_deadline_counts_from_upload_start_and_app_lookup_is_retried(self) -> None:
        import argparse
        import http.client

        lookups = []

        def find_app(_client, bundle_id):
            lookups.append(bundle_id)
            if len(lookups) == 1:
                raise http.client.RemoteDisconnected("closed")
            return ios_release.ASC_APP_ID

        fake_module = mock.Mock(find_app=find_app)
        captured = {}

        def fake_wait(client, **kwargs):
            captured.update(kwargs)
            return {"id": "B9"}

        args = argparse.Namespace(
            version=VERSION, build=6, started_at=STARTED, wait_minutes=120, poll_seconds=30
        )
        with tempfile.NamedTemporaryFile("r", suffix=".out") as out, mock.patch.object(
            ios_release, "asc_client", return_value=(fake_module, object())
        ), mock.patch.object(ios_release, "wait_for_build", side_effect=fake_wait), mock.patch.object(
            ios_release.time, "sleep"
        ), mock.patch.object(
            ios_release.time, "time", return_value=STARTED + 30
        ), mock.patch.dict(os.environ, {"GITHUB_OUTPUT": out.name}), redirect_stdout(io.StringIO()):
            ios_release.cmd_wait_build(args)
            written = Path(out.name).read_text()
        self.assertEqual(lookups, [ios_release.BUNDLE_ID] * 2)
        self.assertEqual(captured["app_id"], ios_release.ASC_APP_ID)
        self.assertEqual(captured["deadline"], STARTED + 120 * 60)
        self.assertEqual(captured["uploaded_after"], STARTED)
        self.assertEqual(captured["build_number"], "6")
        self.assertIs(captured["is_transient"], ios_release.is_transient_error)
        self.assertIn("build_id=B9", written)

    def test_bundle_id_resolving_to_another_app_stops(self) -> None:
        fake_module = mock.Mock(find_app=lambda _client, _bundle: "999")
        with self.assertRaisesRegex(ReleaseError, "expected 6760978934"):
            ios_release.find_this_app(fake_module, object())

    def test_app_lookup_gives_up_at_the_deadline(self) -> None:
        import http.client

        def boom():
            raise http.client.RemoteDisconnected("closed")

        clock = FakeClock(STARTED)
        with redirect_stdout(io.StringIO()), self.assertRaises(http.client.RemoteDisconnected):
            ios_release.call_with_retries(
                boom, deadline=STARTED + 90, poll_seconds=30, now=clock.now, sleep=clock.sleep
            )
        self.assertEqual(clock.sleeps, [30, 30, 30])


class FakeAsc:
    """App Store Connect stand-in for asc_release.main() (live path, no network)."""

    def __init__(self, *, state: str = "PREPARE_FOR_SUBMISSION", attached: str | None = "OLD",
                 revert_after_select: bool = False, app_id: str = asc_release.DEFAULT_APP_ID) -> None:
        self.state = state
        self.attached = attached
        self.revert_after_select = revert_after_select
        self.app_id = app_id
        self.build_reads = 0
        self.calls: list[tuple[str, str]] = []

    def get(self, path: str) -> dict:
        self.calls.append(("GET", path))
        if path.startswith("/apps?"):
            return {"data": [{"id": self.app_id}]}
        if path.startswith(f"/apps/{self.app_id}/appStoreVersions"):
            return {"data": [{"id": "V1", "attributes": {"versionString": VERSION, "appStoreState": self.state}}]}
        if path.startswith("/builds/B9"):
            return {"data": build_row("B9"), "included": [pre_row()]}
        if path == "/appStoreVersions/V1/build":
            self.build_reads += 1
            if self.revert_after_select and self.build_reads >= 2:
                return {"data": {"type": "builds", "id": "OLD"}}
            return {"data": {"type": "builds", "id": self.attached} if self.attached else None}
        if path.startswith(f"/apps/{self.app_id}/reviewSubmissions"):
            return {"data": [{"id": "SUB1"}]}
        if path.startswith("/reviewSubmissions/SUB1/items"):
            return {"data": []}
        raise AssertionError(f"unexpected GET {path}")

    def post(self, path: str, body: dict) -> dict:
        self.calls.append(("POST", path))
        return {"data": {"id": "ITEM"}}

    def patch(self, path: str, body: dict) -> dict:
        self.calls.append(("PATCH", path))
        return {"data": body["data"]}

    def request(self, method: str, path: str, body: dict | None = None):
        self.calls.append((method, path))
        if method == "PATCH" and path == "/appStoreVersions/V1/relationships/build":
            self.attached = body["data"]["id"]
        return None


class LiveSubmitFlowTests(unittest.TestCase):
    def run_main(self, fake: FakeAsc) -> tuple[int, mock.Mock]:
        products = mock.Mock(return_value=asc_release.ProductSubmitResult("SUB1", 0, False))
        argv = ["asc_release.py", "--version", VERSION, "--build-id", "B9", "--build-number", "6"]
        env = {k: v for k, v in os.environ.items() if k not in ASC_FLAGS}
        env["SUBMIT_IOS_REVIEW"] = "true"
        code = 0
        with mock.patch.dict(os.environ, env, clear=True), mock.patch.object(sys, "argv", argv), \
                mock.patch.object(asc_release, "client_from_environment", return_value=fake), \
                mock.patch.object(asc_release, "submit_in_app_purchases", products), \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
            try:
                asc_release.main()
            except SystemExit as exc:
                code = exc.code if isinstance(exc.code, int) else 1
        return code, products

    def test_selects_rechecks_then_submits(self) -> None:
        fake = FakeAsc()
        code, products = self.run_main(fake)
        self.assertEqual(code, 0)
        calls = fake.calls
        select = calls.index(("PATCH", "/appStoreVersions/V1/relationships/build"))
        submit = calls.index(("PATCH", "/reviewSubmissions/SUB1"))
        reads = [i for i, c in enumerate(calls) if c == ("GET", "/appStoreVersions/V1/build")]
        build_checks = [i for i, c in enumerate(calls) if c[0] == "GET" and c[1].startswith("/builds/B9")]
        self.assertEqual(len(reads), 2, "selection must be read back and rechecked")
        self.assertTrue(select < reads[0] < reads[1] < submit)
        self.assertEqual(len(build_checks), 2)
        self.assertTrue(build_checks[1] < reads[1] < submit, "build must be re-verified just before submit")
        self.assertIn(("PATCH", "/appStoreVersions/V1"), calls)  # release type
        products.assert_called_once()

    def test_selection_changed_before_submit_aborts(self) -> None:
        fake = FakeAsc(revert_after_select=True)
        code, _ = self.run_main(fake)
        self.assertEqual(code, 1)
        self.assertNotIn(("PATCH", "/reviewSubmissions/SUB1"), fake.calls)

    def test_waiting_for_review_with_another_build_aborts(self) -> None:
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="OTHER")
        code, products = self.run_main(fake)
        self.assertEqual(code, 1)
        products.assert_not_called()
        self.assertNotIn(("PATCH", "/reviewSubmissions/SUB1"), fake.calls)

    def test_waiting_for_review_with_this_build_is_idempotent(self) -> None:
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9")
        code, products = self.run_main(fake)
        self.assertEqual(code, 0)
        products.assert_called_once()
        self.assertNotIn(("PATCH", "/appStoreVersions/V1/relationships/build"), fake.calls)

    def test_live_version_is_not_submittable(self) -> None:
        fake = FakeAsc(state="READY_FOR_SALE")
        code, products = self.run_main(fake)
        self.assertEqual(code, 1)
        products.assert_not_called()
        self.assertNotIn(("PATCH", "/appStoreVersions/V1/relationships/build"), fake.calls)

    def test_bundle_id_of_another_app_stops_before_any_change(self) -> None:
        fake = FakeAsc(app_id="1234567890")
        code, products = self.run_main(fake)
        self.assertEqual(code, 1)
        products.assert_not_called()
        self.assertFalse([c for c in fake.calls if c[0] != "GET"])


if __name__ == "__main__":
    unittest.main()
