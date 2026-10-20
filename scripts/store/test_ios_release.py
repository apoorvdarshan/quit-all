#!/usr/bin/env python3
"""Offline tests for iOS release switches, build waiting, build selection, the asc runner and repo inputs.

No network: every asc call goes to an in-memory fake of App Store Connect.
Run: python3 -m unittest scripts/store/test_ios_release.py

A release run sets CHECK_ONLY_ENABLED_STORE_INPUTS=true: it then skips the
checks of committed store files no switch may be using (listing, What's New,
screenshots, creative assets, other releases' notes), because the release
checks exactly the inputs of its enabled switches in a separate step. Pull
requests and main run everything.
"""
from __future__ import annotations

import contextlib
import hashlib
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

import asc_cli  # noqa: E402
import asc_release  # noqa: E402
import ios_release  # noqa: E402
import print_gates  # noqa: E402
import redact_logs  # noqa: E402
from ios_release import ReleaseError, resolve_gates  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
RELEASE_RUN = os.environ.get("CHECK_ONLY_ENABLED_STORE_INPUTS", "").strip().lower() == "true"
skip_unused_inputs_on_release_runs = unittest.skipIf(
    RELEASE_RUN, "release run: the inputs of the enabled switches are checked in their own step"
)
TAG = "v1.2.2"
VERSION = "1.2.2"
ALL_ON = {
    "IOS_RELEASE_AUTOMATION": "true",
    "IOS_CREATE_VERSION": "true",
    "IOS_UPLOAD_BUILD": "true",
    "IOS_UPLOAD_LISTING": "true",
    "IOS_UPLOAD_WHATS_NEW": "true",
    "IOS_UPLOAD_SCREENSHOTS": "true",
    "IOS_UPLOAD_CREATIVE_ASSETS": "true",
    "IOS_SUBMIT_REVIEW": "true",
    "IOS_PUBLIC_RELEASE": "true",
}
OPS = ("create_version", "upload_build", "listing", "whats_new", "screenshots", "creative", "submit", "public_release")
ASC_FLAGS = {"UPLOAD_LISTING", "UPLOAD_WHATS_NEW", "UPLOAD_SCREENSHOTS", "UPLOAD_CREATIVE_ASSETS", "SUBMIT_IOS_REVIEW",
             "PUBLIC_RELEASE", "CREATE_IOS_VERSION"}


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

    def test_creative_assets_are_their_own_switch(self) -> None:
        result = gates({"IOS_RELEASE_AUTOMATION": "true", "IOS_UPLOAD_CREATIVE_ASSETS": "true"})
        self.assertTrue(result["creative"])
        self.assertTrue(result["asc"])
        self.assertFalse(result["screenshots"])
        self.assertFalse(result["build"])
        self.assertFalse(gates({"IOS_UPLOAD_CREATIVE_ASSETS": "true"})["creative"], "needs the master switch")
        with self.assertRaisesRegex(ReleaseError, "IOS_UPLOAD_CREATIVE_ASSETS"):
            gates({"IOS_UPLOAD_CREATIVE_ASSETS": "sometimes"})

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
                     "IOS_UPLOAD_WHATS_NEW", "IOS_UPLOAD_CREATIVE_ASSETS", "IOS_PUBLIC_RELEASE"):
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

    def test_create_version_needs_only_the_master_switch(self) -> None:
        result = gates({"IOS_RELEASE_AUTOMATION": "true", "IOS_CREATE_VERSION": "true"})
        self.assertTrue(result["create_version"])
        self.assertFalse(result["build"])
        self.assertFalse(result["asc"])
        self.assertFalse(gates({"IOS_CREATE_VERSION": "true"})["create_version"])
        self.assertFalse(gates({**ALL_ON}, event="workflow_dispatch", ref="main")["create_version"])

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
        self.assertIn("creative=false", written)
        self.assertIn("marketing_version=9.9.9", written)

    def test_gates_command_exits_non_zero_on_bad_switch(self) -> None:
        with mock.patch.dict(os.environ, {"GITHUB_EVENT_NAME": "push", "GITHUB_REF_NAME": TAG,
                                          "IOS_UPLOAD_BUILD": "sometimes"}, clear=True), \
                redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()) as err, \
                self.assertRaises(SystemExit) as raised:
            ios_release.main(["gates"])
        self.assertEqual(raised.exception.code, 1)
        self.assertIn("IOS_UPLOAD_BUILD", err.getvalue())


class ExportComplianceTests(unittest.TestCase):
    """ITSAppUsesNonExemptEncryption must be declared, or App Store Connect asks about every build."""

    @staticmethod
    def configuration(name: str, bundle_id: str, extra: str = "") -> str:
        return (
            f"\t\tAAA{name}{bundle_id[-4:]} /* {name} */ = {{\n"
            "\t\t\tisa = XCBuildConfiguration;\n"
            "\t\t\tbuildSettings = {\n"
            f"\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = \"{bundle_id}\";\n"
            f"{extra}"
            "\t\t\t};\n"
            f"\t\t\tname = {name};\n"
            "\t\t};\n"
        )

    def check(self, debug: str, release: str, others: str = "") -> str:
        app = ios_release.BUNDLE_ID
        text = "/* project */\n" + self.configuration("Debug", app, debug) + self.configuration("Release", app, release) + others
        with tempfile.NamedTemporaryFile("w", suffix=".pbxproj", delete=False) as handle:
            handle.write(text)
        self.addCleanup(os.unlink, handle.name)
        return ios_release.check_export_compliance(Path(handle.name))

    NO = "\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO;\n"
    YES = "\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = YES;\n"
    CODE = "\t\t\t\tINFOPLIST_KEY_ITSEncryptionExportComplianceCode = ABC123;\n"

    def test_the_app_declares_no_non_exempt_encryption(self) -> None:
        self.assertEqual(ios_release.check_export_compliance(), "NO")
        configurations = ios_release.app_build_configurations()
        self.assertEqual(sorted(configurations), ["Debug", "Release"])

    def test_no_in_every_configuration_passes(self) -> None:
        self.assertEqual(self.check(self.NO, self.NO), "NO")

    def test_a_configuration_without_the_key_fails_before_the_build(self) -> None:
        with self.assertRaisesRegex(ReleaseError, "Release configuration does not declare export compliance"):
            self.check(self.NO, "")
        with self.assertRaisesRegex(ReleaseError, "Debug configuration does not declare export compliance"):
            self.check("", self.NO)

    def test_a_value_on_another_target_does_not_count_for_the_app(self) -> None:
        widget = self.configuration("Release", ios_release.BUNDLE_ID + ".Widget", self.NO)
        with self.assertRaisesRegex(ReleaseError, "does not declare export compliance"):
            self.check("", "", widget)

    def test_yes_needs_the_compliance_code(self) -> None:
        with self.assertRaisesRegex(ReleaseError, "needs INFOPLIST_KEY_ITSEncryptionExportComplianceCode"):
            self.check(self.YES + self.CODE, self.YES)
        self.assertEqual(self.check(self.YES + self.CODE, self.YES + self.CODE), "YES")

    def test_mixed_or_unknown_values_fail(self) -> None:
        with self.assertRaisesRegex(ReleaseError, "in every app configuration alike"):
            self.check(self.NO, self.YES + self.CODE)
        with self.assertRaisesRegex(ReleaseError, "must be NO or YES"):
            self.check(self.NO, "\t\t\t\tINFOPLIST_KEY_ITSAppUsesNonExemptEncryption = maybe;\n")

    def test_missing_app_configurations_fail(self) -> None:
        with tempfile.NamedTemporaryFile("w", suffix=".pbxproj", delete=False) as handle:
            handle.write("/* project */\n" + self.configuration("Release", "com.example.Other", self.NO))
        self.addCleanup(os.unlink, handle.name)
        with self.assertRaisesRegex(ReleaseError, "could not find the Debug and Release configurations"):
            ios_release.check_export_compliance(Path(handle.name))

    def test_gates_check_it_only_when_this_run_builds(self) -> None:
        missing = mock.patch.object(ios_release, "check_export_compliance",
                                    side_effect=ReleaseError("does not declare export compliance"))
        for env, fails in (({"GITHUB_EVENT_NAME": "workflow_dispatch", "GITHUB_REF_NAME": "main"}, True),
                           ({"GITHUB_EVENT_NAME": "push", "GITHUB_REF_NAME": TAG}, False)):
            with self.subTest(env=env), missing, mock.patch.object(ios_release, "single_project_value",
                                                                   return_value=VERSION), \
                    mock.patch.dict(os.environ, env, clear=True), redirect_stdout(io.StringIO()), \
                    redirect_stderr(io.StringIO()) as err:
                if fails:
                    with self.assertRaises(SystemExit):
                        ios_release.main(["gates"])
                    self.assertIn("export compliance", err.getvalue())
                else:
                    ios_release.main(["gates"])


class BuildNumberTests(unittest.TestCase):
    def test_next_build_number(self) -> None:
        # Quit All's App Store Connect history restarts build numbers per version.
        self.assertEqual(ios_release.next_build_number(6, ["1", "1", "1", "2", "2", "3", "3", "4", "5"]), 6)
        self.assertEqual(ios_release.next_build_number(6, ["6", "2"]), 7)
        self.assertEqual(ios_release.next_build_number(1, []), 1)
        self.assertEqual(ios_release.next_build_number(5, ["7.1", "abc", "9"]), 10)
        self.assertEqual(ios_release.next_build_number(5, ["٩٩"]), 5)  # only ASCII digits count


APP = "APP1"
ASC_APP = asc_release.ASC_APP_ID
BUNDLE = asc_release.DEFAULT_BUNDLE_ID
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
    uploaded: float | str | None = STARTED + 60,
    app: str = APP,
    pre: str = "P1",
) -> dict:
    """An `asc builds list` row; uploaded=None leaves uploadedDate out, a string is used as is."""
    attributes = {"version": number, "processingState": state, "expired": expired}
    if uploaded is not None:
        attributes["uploadedDate"] = uploaded if isinstance(uploaded, str) else iso(uploaded)
    return {
        "type": "builds",
        "id": build_id,
        "attributes": attributes,
        "relationships": {
            "preReleaseVersion": {"data": {"type": "preReleaseVersions", "id": pre}},
            "app": {"data": {"type": "apps", "id": app}},
        },
    }


def pre_row(pre_id: str = "P1", version: str = VERSION, platform: str = "IOS") -> dict:
    return {"type": "preReleaseVersions", "id": pre_id, "attributes": {"version": version, "platform": platform}}


def asc_error(code: int) -> asc_cli.AscError:
    return asc_cli.AscError(("builds", "list"), code, "failed")


def png_header(color_type: int, *, trns: bool = False) -> bytes:
    """A PNG signature and IHDR (plus an optional tRNS chunk) with the given colour type."""
    import zlib

    def chunk(kind: bytes, body: bytes) -> bytes:
        return len(body).to_bytes(4, "big") + kind + body + zlib.crc32(kind + body).to_bytes(4, "big")

    ihdr = (16).to_bytes(4, "big") + (16).to_bytes(4, "big") + bytes([8, color_type, 0, 0, 0])
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + (chunk(b"tRNS", b"\x00\x00") if trns else b"") + chunk(b"IDAT", b"x")


def flag(call: tuple[str, ...], name: str) -> str:
    return call[call.index(name) + 1]


class FakeClock:
    def __init__(self, start: float) -> None:
        self.time = start
        self.sleeps: list[float] = []

    def now(self) -> float:
        return self.time

    def sleep(self, seconds: float) -> None:
        self.sleeps.append(seconds)
        self.time += seconds


class SequenceAsc:
    """Returns queued `asc builds list` payloads (or raises queued exceptions) per call."""

    def __init__(self, responses: list) -> None:
        self.responses = list(responses)
        self.calls: list[tuple[str, ...]] = []

    def run(self, *args: str, **_: object) -> dict:
        self.calls.append(args)
        item = self.responses.pop(0) if len(self.responses) > 1 else self.responses[0]
        if isinstance(item, BaseException):
            raise item
        return item


def wait(client: SequenceAsc, clock: FakeClock, *, minutes: int = 120, transient=None) -> dict:
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
        client = SequenceAsc(
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
        query = client.calls[0]
        self.assertEqual(query[:2], ("builds", "list"))
        self.assertEqual(flag(query, "--app"), APP)
        self.assertEqual(flag(query, "--build-number"), "6")
        self.assertEqual(flag(query, "--processing-state"), "all")
        self.assertEqual(flag(query, "--include"), "preReleaseVersion,app")

    def test_times_out_without_using_another_build(self) -> None:
        client = SequenceAsc([{"data": [build_row(state="PROCESSING")], "included": [pre_row()]}])
        clock = FakeClock(STARTED)
        with self.assertRaisesRegex(ReleaseError, "timed out"):
            wait(client, clock, minutes=10)
        self.assertLessEqual(clock.time, STARTED + 10 * 60 + 30)

    def test_ready_build_after_the_deadline_is_still_a_timeout(self) -> None:
        client = SequenceAsc([{"data": [build_row()], "included": [pre_row()]}])
        clock = FakeClock(STARTED + 121 * 60)  # job started after the 120-minute budget
        with self.assertRaisesRegex(ReleaseError, "timed out"):
            wait(client, clock)
        self.assertEqual(client.calls, [], "must not poll once the budget is spent")

    def test_processing_failure_stops(self) -> None:
        for state in ("FAILED", "INVALID"):
            client = SequenceAsc([{"data": [build_row(state=state)], "included": [pre_row()]}])
            with self.subTest(state=state), self.assertRaisesRegex(ReleaseError, state):
                wait(client, FakeClock(STARTED))

    def test_expired_build_is_rejected(self) -> None:
        client = SequenceAsc([{"data": [build_row(expired=True)], "included": [pre_row()]}])
        with self.assertRaisesRegex(ReleaseError, "expired"):
            wait(client, FakeClock(STARTED))

    def test_ambiguous_match_stops(self) -> None:
        client = SequenceAsc(
            [{"data": [build_row("B1"), build_row("B2")], "included": [pre_row()]}]
        )
        with self.assertRaisesRegex(ReleaseError, "ambiguous"):
            wait(client, FakeClock(STARTED))

    def test_older_upload_is_never_substituted(self) -> None:
        old = build_row(uploaded=STARTED - 3600)
        client = SequenceAsc([{"data": [old], "included": [pre_row()]}])
        with self.assertRaisesRegex(ReleaseError, "older build"):
            wait(client, FakeClock(STARTED))

    def test_build_without_a_readable_upload_time_is_never_used(self) -> None:
        # Fail closed: a missing or unreadable uploadedDate cannot prove the
        # build is this run's upload.
        for uploaded in (None, "", "yesterday"):
            client = SequenceAsc([{"data": [build_row(uploaded=uploaded)], "included": [pre_row()]}])
            with self.subTest(uploaded=uploaded), self.assertRaisesRegex(ReleaseError, "uploadedDate"):
                wait(client, FakeClock(STARTED))

    def test_upload_time_may_appear_while_the_build_processes(self) -> None:
        client = SequenceAsc(
            [
                {"data": [build_row(state="PROCESSING", uploaded=None)], "included": [pre_row()]},
                {"data": [build_row()], "included": [pre_row()]},
            ]
        )
        clock = FakeClock(STARTED)
        self.assertEqual(wait(client, clock)["id"], "B1")
        self.assertEqual(clock.sleeps, [30])

    def test_other_versions_and_platforms_are_ignored(self) -> None:
        other_version = build_row("BX", pre="P2")
        other_platform = build_row("BY", pre="P3")
        client = SequenceAsc(
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
        client = SequenceAsc([{"data": [build_row(app="OTHER")], "included": [pre_row()]}])
        with self.assertRaisesRegex(ReleaseError, "another app"):
            wait(client, FakeClock(STARTED))

    def test_transient_errors_are_retried_and_others_raise(self) -> None:
        client = SequenceAsc([asc_error(63), {"data": [build_row()], "included": [pre_row()]}])
        with redirect_stderr(io.StringIO()):
            build = wait(client, FakeClock(STARTED), transient=ios_release.is_transient_error)
        self.assertEqual(build["id"], "B1")
        fatal = SequenceAsc([asc_error(3)])
        with self.assertRaises(asc_cli.AscError):
            wait(fatal, FakeClock(STARTED), transient=ios_release.is_transient_error)


# asc commands that change App Store Connect.
MUTATIONS = {
    ("versions", "create"), ("versions", "update"), ("versions", "attach-build"), ("localizations", "update"),
    ("screenshots", "upload"), ("asset-library", "images", "upload"), ("localizations", "placements", "create"),
    ("localizations", "placements", "swap"), ("review", "submissions-create"), ("review", "items-add"),
    ("review", "submissions-submit"),
}


def is_write(call: tuple[str, ...]) -> bool:
    return call[:2] in MUTATIONS or call[:3] in MUTATIONS


def text_flags(call: tuple[str, ...]) -> set[str]:
    """The field flags of an `asc localizations update` call."""
    return {arg for arg in call if arg.startswith("--")} - {"--id"}


def version_item(version_id: str = "V1") -> dict:
    return {"id": f"ITEM-{version_id}", "relationships": {"appStoreVersion": {"data": {"id": version_id}}}}


LIVE_TEXT = {
    "description": "Quit everything.",
    "keywords": "quit,habits",
    "promotionalText": "Promo",
    "marketingUrl": "https://quit-all.com",
    "supportUrl": "https://quit-all.com/support",
    "whatsNew": "Fixes for 1.2.2.",
}


class FakeAsc:
    """A stateful App Store Connect behind `asc`, for asc_release (no network).

    The app version under test is V1 (VERSION); other_versions lists the app's
    other IOS versions as (versionString, appStoreState).
    """

    def __init__(
        self,
        *,
        state: str = "PREPARE_FOR_SUBMISSION",
        attached: str | None = "OLD",
        revert_after_select: bool = False,
        bundle: str = BUNDLE,
        record_id: str | None = None,
        has_version: bool = True,
        other_versions: list[tuple[str, str]] | None = None,
        listed_after_create: bool = True,
        localization: dict | None = None,
        other_locales: dict[str, dict] | None = None,
        screenshot_sets: dict[str, list[str]] | None = None,
        failed_delivery: set[str] | None = None,
        builds: list[dict] | None = None,
        included: list[dict] | None = None,
        subscriptions: list[dict] | None = None,
        iaps: list[dict] | None = None,
        drafts: list[str] | None = None,
        draft_items: dict[str, list[dict]] | None = None,
        refuse_items: set[str] | None = None,
        library: list[dict] | None = None,
        placements: list[dict] | None = None,
    ) -> None:
        self.state = state
        self.attached = attached
        self.revert_after_select = revert_after_select
        self.bundle = bundle
        self.record_id = record_id
        self.has_version = has_version
        self.other_versions = [("1.2.1", "READY_FOR_SALE")] if other_versions is None else other_versions
        self.listed_after_create = listed_after_create
        # Live en-US version localization (id LOC) attributes; {} = no such localization.
        self.localization = dict(LIVE_TEXT) if localization is None else localization
        # Other locales on the version (id LOC-<locale>) and their live attributes.
        self.other_locales = {k: dict(v) for k, v in (other_locales or {}).items()}
        # Live screenshot checksums per display type, in order.
        self.screenshot_sets = {k: list(v) for k, v in (screenshot_sets or {}).items()}
        self.failed_delivery = failed_delivery or set()
        self.builds = builds if builds is not None else [build_row("B9")]
        self.included = included if included is not None else [pre_row()]
        self.subscriptions = subscriptions or []
        self.iaps = iaps or []
        self.drafts = list(drafts or [])
        self.items = {k: list(v) for k, v in (draft_items or {}).items()}
        self.refuse_items = refuse_items or set()
        self.library = list(library or [])
        self.placements = list(placements or [])
        self.uploaded: list[tuple[str, list[str]]] = []
        self.submitted: list[str] = []
        self.read_only_modes: list[bool] = []
        self.calls: list[tuple[str, ...]] = []
        self.version_views = 0

    def connect(self, *, read_only: bool = False) -> "FakeAsc":
        """Stands in for asc_release.asc_from_environment."""
        self.read_only_modes.append(read_only)
        return self

    def writes(self) -> list[tuple[str, ...]]:
        return [c for c in self.calls if is_write(c)]

    def versions(self) -> list[dict]:
        rows = [{"id": f"V0-{i}", "attributes": {"versionString": number, "appStoreState": state}}
                for i, (number, state) in enumerate(self.other_versions)]
        if self.has_version:
            rows.append({"id": "V1", "attributes": {"versionString": VERSION, "appStoreState": self.state}})
        return rows

    def run(self, *args: str, **_: object):
        self.calls.append(args)
        head = args[:3] if args[:2] in {("localizations", "placements"), ("asset-library", "images"),
                                        ("subscriptions", "versions"), ("iap", "versions")} else args[:2]
        if head == ("apps", "view"):
            return {"data": {"type": "apps", "id": self.record_id or flag(args, "--id"),
                             "attributes": {"bundleId": self.bundle}}}
        if head == ("versions", "list"):
            return {"data": self.versions()}
        if head == ("versions", "create"):
            if self.listed_after_create:
                self.has_version = True
                self.state = "PREPARE_FOR_SUBMISSION"
            return {"data": {"id": "V1"}}
        if head == ("versions", "view"):
            self.version_views += 1
            build = self.attached
            if self.revert_after_select and self.version_views >= 2:
                build = "OLD"
            rel = {"build": {"data": {"type": "builds", "id": build} if build else None}}
            return {"data": {"id": flag(args, "--version-id"), "relationships": rel}}
        if head == ("versions", "attach-build"):
            self.attached = flag(args, "--build-id")
            return {"data": {}}
        if head == ("versions", "update"):
            return {"data": {}}
        if head == ("builds", "list"):
            return {"data": self.builds, "included": self.included}
        if head == ("localizations", "list"):
            locale = flag(args, "--locale")
            if locale in self.other_locales:
                return {"data": [{"id": f"LOC-{locale}", "attributes": {**self.other_locales[locale], "locale": locale}}]}
            if locale != "en-US" or self.localization == {}:
                return {"data": []}
            return {"data": [{"id": "LOC", "attributes": {"locale": locale, **self.localization}}]}
        if head == ("localizations", "update"):
            return {"data": {}}
        if head == ("screenshots", "list"):
            return {"versionLocalizationId": flag(args, "--version-localization"), "locale": "en-US", "sets": [
                {"set": {"id": f"SET-{kind}", "attributes": {"screenshotDisplayType": kind}},
                 "screenshots": [{"id": f"{kind}-{i}", "attributes": {
                     "sourceFileChecksum": checksum,
                     "assetDeliveryState": {"state": "FAILED" if kind in self.failed_delivery and i == 0 else "COMPLETE"},
                 }} for i, checksum in enumerate(checksums)]}
                for kind, checksums in self.screenshot_sets.items()
            ]}
        if head == ("screenshots", "upload"):
            # The set ends up holding exactly the files in --path, in file-name order.
            files = sorted(Path(flag(args, "--path")).glob("*.png"))
            display = "APP_" + flag(args, "--device-type")
            self.uploaded.append((display, [p.name for p in files]))
            self.screenshot_sets[display] = [hashlib.md5(p.read_bytes()).hexdigest() for p in files]
            return {}
        if head == ("asset-library", "view"):
            return {"data": {"id": "LIB1"}}
        if head == ("asset-library", "images", "list"):
            return {"data": self.library}
        if head == ("asset-library", "images", "upload"):
            path = Path(flag(args, "--file"))
            image_id = f"IMG{len(self.library) + 1}"
            self.library.append({"id": image_id, "attributes": {"fileName": path.name, "fileSize": path.stat().st_size,
                                                                "state": "PREPARE_FOR_SUBMISSION", "createdDate": "z"}})
            return {"imageId": image_id, "ready": True, "state": "PREPARE_FOR_SUBMISSION"}
        if head == ("localizations", "placements", "list"):
            # A placement without "localization" belongs to the en-US localization LOC.
            wanted, loc = flag(args, "--placement-type"), flag(args, "--localization-id")
            return {"data": [p for p in self.placements
                             if p["attributes"]["placementType"] == wanted and p.get("localization", "LOC") == loc]}
        if head in {("localizations", "placements", "create"), ("localizations", "placements", "swap")}:
            kind, loc = flag(args, "--placement-type"), flag(args, "--localization-id")
            self.placements = [p for p in self.placements
                               if not (p["attributes"]["placementType"] == kind and p.get("localization", "LOC") == loc)]
            self.placements.append({"id": f"PL-new-{loc}", "localization": loc, "attributes": {"placementType": kind},
                                    "relationships": {"image": {"data": {"id": flag(args, "--image-id")}}}})
            return {"data": {}}
        if head == ("review", "submissions-list"):
            return {"data": [{"id": d} for d in self.drafts]}
        if head == ("review", "submissions-create"):
            new = f"SUB{len(self.drafts) + len(self.submitted) + 1}"
            self.drafts.append(new)
            return {"data": {"id": new}}
        if head == ("review", "items-list"):
            return {"data": self.items.get(flag(args, "--submission"), [])}
        if head == ("review", "items-add"):
            item_type, item_id = flag(args, "--item-type"), flag(args, "--item-id")
            if item_id in self.refuse_items:
                raise asc_cli.AscError(args, 5, "conflict")
            relation = {"appStoreVersions": "appStoreVersion", "subscriptionVersions": "subscriptionVersion",
                        "inAppPurchaseVersions": "inAppPurchaseVersion",
                        "appAssetLibraryImages": "appAssetLibraryImage"}[item_type]
            held = self.items.setdefault(flag(args, "--submission"), [])
            if any(((item.get("relationships") or {}).get(relation) or {}).get("data", {}).get("id") == item_id
                   for item in held):
                if flag(args, "--if-exists") != "skip":
                    raise asc_cli.AscError(args, 5, "already on the submission")
                return {"data": {}}
            held.append({"id": f"ITEM-{item_id}", "relationships": {relation: {"data": {"id": item_id}}}})
            return {"data": {}}
        if head == ("review", "submissions-submit"):
            submission = flag(args, "--id")
            self.submitted.append(submission)
            if submission in self.drafts:
                self.drafts.remove(submission)
            return {"data": {}}
        if head == ("subscriptions", "list"):
            return {"data": self.subscriptions}
        if head == ("subscriptions", "versions", "list"):
            sub = flag(args, "--subscription-id")
            return {"data": [{"id": f"{sub}v2", "attributes": {"version": 2}},
                             {"id": f"{sub}v1", "attributes": {"version": 1}}]}
        if head == ("iap", "list"):
            return {"data": self.iaps}
        if head == ("iap", "versions", "list"):
            iap = flag(args, "--iap-id")
            return {"data": [{"id": f"{iap}v1", "attributes": {"version": 1, "state": "APPROVED"}},
                             {"id": f"{iap}v2", "attributes": {"version": 2, "state": "PREPARE_FOR_SUBMISSION"}}]}
        raise AssertionError(f"unexpected asc call {args}")


def quiet(fn, *args, **kwargs):
    with redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
        return fn(*args, **kwargs)


class BuildSelectionTests(unittest.TestCase):
    def test_selects_and_reads_back_this_runs_build(self) -> None:
        fake = FakeAsc()
        quiet(asc_release.select_build, fake, "V1", "B9", VERSION, "6")
        self.assertEqual(fake.attached, "B9")
        self.assertEqual([c[:2] for c in fake.calls],
                         [("builds", "list"), ("versions", "attach-build"), ("versions", "view")])
        check = fake.calls[0]
        self.assertEqual((flag(check, "--app"), flag(check, "--build-number"), flag(check, "--version")),
                         (ASC_APP, "6", VERSION))
        self.assertEqual(flag(fake.calls[1], "--build-id"), "B9")

    def test_selection_that_does_not_stick_fails(self) -> None:
        fake = FakeAsc(revert_after_select=True)
        quiet(asc_release.confirm_selected_build, fake, "V1", "OLD")
        with self.assertRaises(SystemExit):
            quiet(asc_release.select_build, fake, "V1", "B9", VERSION, "6")

    def test_unprocessed_expired_or_wrong_build_is_refused(self) -> None:
        cases = {
            "processing": ([build_row("B9", state="PROCESSING")], [pre_row()]),
            "expired": ([build_row("B9", expired=True)], [pre_row()]),
            "number": ([build_row("B9", number="7")], [pre_row()]),
            "version": ([build_row("B9")], [pre_row(version="1.2.1")]),
            "platform": ([build_row("B9")], [pre_row(platform="TV_OS")]),
            "missing": ([build_row("B8")], [pre_row()]),
        }
        for label, (builds, included) in cases.items():
            fake = FakeAsc(builds=builds, included=included, attached=None)
            with self.subTest(label), self.assertRaises(SystemExit):
                quiet(asc_release.select_build, fake, "V1", "B9", VERSION, "6")
            self.assertEqual(fake.writes(), [], label)

    def test_release_type(self) -> None:
        for public, expected in ((True, "AFTER_APPROVAL"), (False, "MANUAL")):
            fake = FakeAsc()
            quiet(asc_release.set_release_type, fake, "V1", public_release=public)
            self.assertEqual(fake.calls[-1][:2], ("versions", "update"))
            self.assertEqual(flag(fake.calls[-1], "--release-type"), expected)


class AscRunnerTests(unittest.TestCase):
    ENV = {
        "APP_STORE_CONNECT_API_KEY_ID": "TESTKEY0001",
        "APP_STORE_CONNECT_ISSUER_ID": "00000000-test-4000-8000-issuer000001",
        "APP_STORE_CONNECT_API_KEY_P8": "-----BEGIN PRIVATE KEY-----\\nabc\\n-----END PRIVATE KEY-----",
        "ASC_PROFILE": "personal",
        "ASC_CONFIG_PATH": "/home/me/.asc/config.json",
    }

    def run_once(self, *, returncode: int = 0, stdout: str = '{"data": []}', stderr: str = "", read_only=False, env=None):
        seen: dict = {}

        def runner(argv, **kwargs):
            seen["argv"], seen["env"] = argv, kwargs["env"]
            return mock.Mock(returncode=returncode, stdout=stdout, stderr=stderr)

        with mock.patch.dict(os.environ, env or self.ENV, clear=True):
            result = asc_cli.Asc(binary="asc", read_only=read_only, runner=runner).run("apps", "view", "--id", ASC_APP)
        return result, seen

    def test_credentials_come_from_the_release_secrets_and_nothing_else(self) -> None:
        result, seen = self.run_once()
        self.assertEqual(result, {"data": []})
        self.assertEqual(seen["argv"], ["asc", "apps", "view", "--id", ASC_APP, "--output", "json"])
        env = seen["env"]
        self.assertEqual(env["ASC_KEY_ID"], "TESTKEY0001")
        self.assertEqual(env["ASC_ISSUER_ID"], self.ENV["APP_STORE_CONNECT_ISSUER_ID"])
        self.assertIn("\nabc\n", env["ASC_PRIVATE_KEY"])
        for name in ("ASC_PROFILE", "ASC_CONFIG_PATH"):
            self.assertNotIn(name, env)
        for name, value in (("ASC_BYPASS_KEYCHAIN", "1"), ("ASC_TELEMETRY_DISABLED", "1"), ("DO_NOT_TRACK", "1"),
                            ("ASC_SKILLS_AUTO_CHECK", "0"), ("ASC_STRICT_AUTH", "1"), ("ASC_MAX_RETRIES", "5")):
            self.assertEqual(env[name], value, name)
        self.assertNotIn("ASC_READ_ONLY", env)

    def test_read_only_from_the_caller_or_the_job(self) -> None:
        _, seen = self.run_once(read_only=True)
        self.assertEqual(seen["env"]["ASC_READ_ONLY"], "1")
        _, seen = self.run_once(env={**self.ENV, "ASC_READ_ONLY": "1"})
        self.assertEqual(seen["env"]["ASC_READ_ONLY"], "1")

    def test_failures_keep_the_exit_code_and_hide_the_ids(self) -> None:
        stderr = f"401 for key {self.ENV['APP_STORE_CONNECT_API_KEY_ID']} issuer {self.ENV['APP_STORE_CONNECT_ISSUER_ID']}"
        with self.assertRaises(asc_cli.AscError) as caught:
            self.run_once(returncode=3, stderr=stderr)
        self.assertEqual(caught.exception.exit_code, 3)
        self.assertNotIn("TESTKEY0001", str(caught.exception))
        self.assertNotIn("issuer000001", str(caught.exception))
        with self.assertRaises(asc_cli.AscError):
            self.run_once(stdout="not json")

    def test_install_accepts_only_the_pinned_binary(self) -> None:
        good = b"pinned-binary"
        with mock.patch.dict(asc_cli.ASC_SHA256, {"linux_amd64": hashlib.sha256(good).hexdigest()}):
            with tempfile.TemporaryDirectory() as tmp:
                opener = lambda url, timeout: io.BytesIO(good)  # noqa: E731
                target = quiet(asc_cli.install, Path(tmp), key="linux_amd64", opener=opener)
                self.assertEqual(target.read_bytes(), good)
                self.assertTrue(os.access(target, os.X_OK))
                bad = lambda url, timeout: io.BytesIO(b"tampered")  # noqa: E731
                with self.assertRaises(SystemExit):
                    quiet(asc_cli.install, Path(tmp) / "other", key="linux_amd64", opener=bad)
                self.assertFalse((Path(tmp) / "other" / "asc").exists())

    def test_the_pin_is_one_exact_release_with_both_ci_platforms(self) -> None:
        self.assertRegex(asc_cli.ASC_VERSION, r"^[0-9]+\.[0-9]+\.[0-9]+$")
        self.assertEqual(set(asc_cli.ASC_SHA256), {"linux_amd64", "macOS_arm64"})
        for digest in asc_cli.ASC_SHA256.values():
            self.assertRegex(digest, r"^[0-9a-f]{64}$")
        self.assertEqual(asc_cli.platform_key("Linux", "x86_64"), "linux_amd64")
        self.assertEqual(asc_cli.platform_key("Darwin", "arm64"), "macOS_arm64")
        with self.assertRaises(SystemExit):
            asc_cli.platform_key("Windows", "x86_64")

    def test_only_the_pinned_binary_receives_credentials(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            binary = Path(tmp) / "asc"
            binary.write_bytes(b"pinned-binary")
            pinned = {asc_cli.platform_key(): hashlib.sha256(b"pinned-binary").hexdigest()}
            with mock.patch.dict(asc_cli.ASC_SHA256, pinned), mock.patch.object(asc_cli.shutil, "which", return_value=str(binary)):
                self.assertEqual(asc_cli.verified_binary("asc"), str(binary))
                binary.write_bytes(b"something else")
                with self.assertRaises(asc_cli.AscError) as caught:
                    asc_cli.verified_binary("asc")
                self.assertEqual(caught.exception.exit_code, 126)
                # A real run checks the binary before anything is executed.
                with mock.patch.object(asc_cli.subprocess, "run") as run, self.assertRaises(asc_cli.AscError):
                    asc_cli.Asc().run("apps", "view", "--id", ASC_APP)
                run.assert_not_called()
            with mock.patch.object(asc_cli.shutil, "which", return_value=None), self.assertRaises(asc_cli.AscError):
                asc_cli.verified_binary("asc")
        # No environment variable can point the release at another executable.
        with mock.patch.dict(os.environ, {"ASC_BIN": "/tmp/evil"}):
            self.assertEqual(asc_cli.Asc().binary, "asc")

    def test_alpha_is_detected_the_way_asc_refuses_it(self) -> None:
        cases = {"rgb": (png_header(2), False), "rgba": (png_header(6), True), "gray-alpha": (png_header(4), True),
                 "rgb-trns": (png_header(2, trns=True), True), "jpeg": (b"\xff\xd8\xff\xe0rest", False)}
        with tempfile.TemporaryDirectory() as tmp:
            for name, (content, expected) in cases.items():
                path = Path(tmp) / name
                path.write_bytes(content)
                with self.subTest(name=name):
                    self.assertEqual(asc_cli.image_has_alpha(path), expected)

    def test_a_leading_at_sign_is_escaped(self) -> None:
        self.assertEqual(asc_release.asc_value("@apoorvcodes on Instagram"), "@@apoorvcodes on Instagram")
        self.assertEqual(asc_release.asc_value("Quit everything"), "Quit everything")

    def test_missing_credentials_stop_before_asc_runs(self) -> None:
        with mock.patch.dict(os.environ, {}, clear=True), redirect_stderr(io.StringIO()) as err, \
                self.assertRaises(SystemExit):
            asc_release.asc_from_environment(read_only=True)
        self.assertIn("APP_STORE_CONNECT_API_KEY_ID", err.getvalue())


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
            for flags in ({"UPLOAD_LISTING": "true"}, {"UPLOAD_CREATIVE_ASSETS": "true"}):
                with self.subTest(flags=flags):
                    code, output = self.run_cli(flags, "--metadata-dir", tmp)
                    self.assertEqual(code, 1)
                    self.assertIn("no listing locales", output)

    def test_listing_excludes_whats_new_unless_enabled(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            loc = Path(tmp) / "ios" / "en-US"
            loc.mkdir(parents=True)
            (loc / "description.txt").write_text("Desc")
            (loc / "whats_new.txt").write_text("New")
            for whats_new, expected in ((False, {"--description"}), (True, {"--description", "--whats-new"})):
                fake = FakeAsc(localization={"locale": "en-US"})
                plans = asc_release.plan_metadata(
                    fake,
                    version_id="V1",
                    locales=["en-US"],
                    metadata_dir=Path(tmp),
                    include_listing=True,
                    include_whats_new=whats_new,
                    screenshot_sets={},
                )
                quiet(asc_release.apply_metadata, fake, plans)
                update = [c for c in fake.writes() if c[:2] == ("localizations", "update")][0]
                self.assertEqual(text_flags(update), expected)
                self.assertEqual(flag(update, "--id"), "LOC")

    def test_dry_run_submit_exercises_product_selection(self) -> None:
        code, output = self.run_cli({"SUBMIT_IOS_REVIEW": "true"}, "--build-id", "B9", "--build-number", "6")
        self.assertEqual(code, 0, output)
        self.assertIn("product submission selection OK", output)

    def test_creative_assets_need_one_image_per_slot(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            code, output = self.run_cli({"UPLOAD_CREATIVE_ASSETS": "true"}, "--creative-dir", tmp)
            self.assertEqual(code, 1)
            self.assertIn("no header or search results image", output)
            (Path(tmp) / "header").mkdir()
            (Path(tmp) / "header" / "a.png").write_bytes(b"x")
            (Path(tmp) / "header" / "b.png").write_bytes(b"y")
            code, output = self.run_cli({"UPLOAD_CREATIVE_ASSETS": "true"}, "--creative-dir", tmp)
            self.assertEqual(code, 1)
            self.assertIn("takes one image", output)
            (Path(tmp) / "header" / "b.png").unlink()
            code, output = self.run_cli({"UPLOAD_CREATIVE_ASSETS": "true"}, "--creative-dir", tmp)
            self.assertEqual(code, 0, output)
            self.assertIn("creative=True", output)

    @skip_unused_inputs_on_release_runs
    def test_the_repository_creative_folders_are_valid(self) -> None:
        creative = asc_release.CREATIVE_DIR
        images = [p for p in creative.rglob("*") if p.suffix.lower() in asc_release.CREATIVE_EXTENSIONS] \
            if creative.is_dir() else []
        if images:
            asc_release.creative_sources(creative)
        else:
            # No images yet: turning IOS_UPLOAD_CREATIVE_ASSETS on stops before any asc call.
            code, output = self.run_cli({"UPLOAD_CREATIVE_ASSETS": "true"})
            self.assertEqual(code, 1)
            self.assertIn("no header or search results image", output)


def png(path: Path, width: int, height: int, color_type: int = 2) -> None:
    """Writes a PNG signature and IHDR header (RGB unless color_type says otherwise); enough for the checks."""
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" + width.to_bytes(4, "big")
                     + height.to_bytes(4, "big") + bytes([8, color_type, 0, 0, 0]))


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
        png(self.root / "shots/65.png", 1284, 2778)
        (self.root / "shots/fake.png").write_bytes(b"GIF89a not a png at all......")
        cases = {
            "unknown display type": ({"APP_IPAD_PRO_129": ["shots/ok.png"]}, "unsupported display type"),
            "wrong size": ({"APP_IPHONE_67": ["shots/small.png"]}, "1179x2556"),
            "size for another slot": ({"APP_IPHONE_65": ["shots/ok.png"]}, "1260x2736"),
            "6.5-inch size asc refuses for 6.7": ({"APP_IPHONE_67": ["shots/65.png"]}, "1284x2778"),
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

    def test_replacing_a_set_uploads_the_manifest_order_and_reads_it_back(self) -> None:
        pngs = []
        for name in ("3.png", "1.png", "2.png"):
            png(self.root / "shots" / name, 1260, 2736)
            with (self.root / "shots" / name).open("ab") as handle:
                handle.write(name.encode())  # distinct contents
            pngs.append(self.root / "shots" / name)
        fake = FakeAsc(screenshot_sets={"APP_IPHONE_67": ["0" * 32] * 10})
        quiet(asc_release.replace_screenshot_set, fake, "LOC", "APP_IPHONE_67", pngs)
        upload = [c for c in fake.writes() if c[:2] == ("screenshots", "upload")][0]
        self.assertEqual(flag(upload, "--version-localization"), "LOC")
        self.assertEqual(flag(upload, "--device-type"), "IPHONE_67")
        self.assertIn("--replace", upload)
        self.assertIn("--confirm", upload)
        # asc uploads a folder in file-name order, so the copies carry the manifest position.
        self.assertEqual(fake.uploaded, [("APP_IPHONE_67", ["01-3.png", "02-1.png", "03-2.png"])])
        self.assertEqual(fake.screenshot_sets["APP_IPHONE_67"], [asc_release.file_md5(p) for p in pngs])
        self.assertFalse(Path(flag(upload, "--path")).exists(), "the staged copies are removed")
        self.assertEqual(fake.calls[-1][:2], ("screenshots", "list"), "the set is read back")

    def test_an_upload_that_does_not_land_fails(self) -> None:
        png(self.root / "shots/1.png", 1260, 2736)
        fake = FakeAsc()
        fake_run = fake.run
        fake.run = lambda *a, **k: {} if a[:2] == ("screenshots", "upload") else fake_run(*a, **k)  # type: ignore[method-assign]
        with self.assertRaises(SystemExit):
            quiet(asc_release.replace_screenshot_set, fake, "LOC", "APP_IPHONE_67", [self.root / "shots/1.png"])


class RepoInputTests(unittest.TestCase):
    """The committed listing, screenshots and catalog are valid release inputs."""

    # A release run checks only what its enabled switches upload, so an unused
    # listing or screenshot file never blocks a build-only release.
    @skip_unused_inputs_on_release_runs
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

    def test_one_pinned_app_record(self) -> None:
        self.assertEqual(asc_release.ASC_APP_ID, ios_release.ASC_APP_ID)
        self.assertEqual(asc_release.DEFAULT_BUNDLE_ID, ios_release.BUNDLE_ID)


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

    def test_duplicate_sections_for_the_tag_fail(self) -> None:
        result = self.run_notes("## v1.2.2\n\n- First\n\n## v1.2.1\n\nOld\n\n## v1.2.2\n\n- Second\n", "v1.2.2")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "", "neither copy may be published")
        self.assertIn('has 2 "## v1.2.2" sections', result.stderr)
        # Another tag's duplicate does not affect this release.
        result = self.run_notes("## v1.2.3\n\n- New\n\n## v1.2.2\n\nA\n\n## v1.2.2\n\nB\n", "v1.2.3")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "- New")

    def test_missing_notes_file_means_generated_notes(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = subprocess.run(
                [sys.executable, str(ROOT / "scripts" / "release_notes.py"), "v1.2.2",
                 "--file", str(Path(tmp) / "RELEASE_NOTES.md")],
                capture_output=True, text=True,
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
        self.assertIn("generate", result.stderr)

    @skip_unused_inputs_on_release_runs
    def test_committed_notes_parse(self) -> None:
        result = subprocess.run([sys.executable, str(ROOT / "scripts" / "release_notes.py"), "v1.2.1"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(result.stdout.strip())

    @skip_unused_inputs_on_release_runs
    def test_committed_notes_have_one_section_per_tag(self) -> None:
        text = (ROOT / "RELEASE_NOTES.md").read_text(encoding="utf-8")
        titles = [line[3:].strip() for line in text.splitlines() if line.startswith("## ")]
        self.assertTrue(titles)
        self.assertEqual(sorted(titles), sorted(set(titles)), "duplicate ## sections in RELEASE_NOTES.md")


class TransientErrorTests(unittest.TestCase):
    def test_retry_rule_follows_asc_exit_codes(self) -> None:
        # 408, 429, any 5xx and a call that ran out of time are retried.
        for code in (18, 39, 60, 62, 63, 99, 124):
            with self.subTest(code=code):
                self.assertTrue(ios_release.is_transient_error(asc_error(code)))
        # Generic, usage, auth, not found, conflict, read-only refusal, other 4xx, not found on PATH.
        for code in (1, 2, 3, 4, 5, 6, 10, 32, 126, 127):
            with self.subTest(code=code):
                self.assertFalse(ios_release.is_transient_error(asc_error(code)))
        for exc in (ValueError("bad"), ReleaseError("mismatch"), SystemExit(1), ConnectionResetError("reset")):
            with self.subTest(exc=repr(exc)):
                self.assertFalse(ios_release.is_transient_error(exc))

    def test_network_drops_reported_as_exit_1_are_retried(self) -> None:
        for detail in ('Get "https://api.appstoreconnect.apple.com/v1/builds": read tcp: connection reset by peer',
                       "dial tcp: lookup api.appstoreconnect.apple.com: no such host",
                       "net/http: TLS handshake timeout", "unexpected EOF",
                       'Get "https://api.appstoreconnect.apple.com/v1/builds": EOF'):
            with self.subTest(detail=detail):
                self.assertTrue(ios_release.is_transient_error(asc_cli.AscError(("builds", "list"), 1, detail)))
        for detail in ("invalid character '<' looking for beginning of value", "build not found",
                       "the GEOFENCE attribute is invalid"):
            with self.subTest(detail=detail):
                self.assertFalse(ios_release.is_transient_error(asc_cli.AscError(("builds", "list"), 1, detail)))
        # The same message with another exit code keeps that code's rule.
        self.assertFalse(ios_release.is_transient_error(asc_cli.AscError(("builds", "list"), 3, "connection reset")))


class CmdWaitBuildTests(unittest.TestCase):
    def test_deadline_counts_from_upload_start_and_app_lookup_is_retried(self) -> None:
        import argparse

        lookups = []

        class Lookup:
            def run(self, *args: str, **_: object):
                lookups.append(args)
                if len(lookups) == 1:
                    raise asc_error(63)
                return {"data": {"id": ios_release.ASC_APP_ID, "attributes": {"bundleId": ios_release.BUNDLE_ID}}}

        captured = {}

        def fake_wait(client, **kwargs):
            captured.update(kwargs)
            return {"id": "B9"}

        args = argparse.Namespace(
            version=VERSION, build=6, started_at=STARTED, wait_minutes=120, poll_seconds=30
        )
        with tempfile.NamedTemporaryFile("r", suffix=".out") as out, mock.patch.object(
            ios_release, "asc_client", return_value=(asc_release, Lookup())
        ), mock.patch.object(ios_release, "wait_for_build", side_effect=fake_wait), mock.patch.object(
            ios_release.time, "sleep"
        ), mock.patch.object(
            ios_release.time, "time", return_value=STARTED + 30
        ), mock.patch.dict(os.environ, {"GITHUB_OUTPUT": out.name}), redirect_stdout(io.StringIO()):
            ios_release.cmd_wait_build(args)
            written = Path(out.name).read_text()
        self.assertEqual(lookups, [("apps", "view", "--id", ios_release.ASC_APP_ID)] * 2)
        self.assertEqual(captured["app_id"], ios_release.ASC_APP_ID)
        self.assertEqual(captured["deadline"], STARTED + 120 * 60)
        self.assertEqual(captured["uploaded_after"], STARTED)
        self.assertEqual(captured["build_number"], "6")
        self.assertIs(captured["is_transient"], ios_release.is_transient_error)
        self.assertIn("build_id=B9", written)

    def test_another_app_record_stops(self) -> None:
        for record in ({"id": ios_release.ASC_APP_ID, "attributes": {"bundleId": "com.example.other"}},
                       {"id": "999", "attributes": {"bundleId": ios_release.BUNDLE_ID}}):
            client = mock.Mock(run=mock.Mock(return_value={"data": record}))
            with self.subTest(record=record), self.assertRaisesRegex(ReleaseError, "6760978934 is not"):
                ios_release.find_this_app(asc_release, client)

    def test_app_lookup_gives_up_at_the_deadline(self) -> None:
        def boom():
            raise asc_error(63)

        clock = FakeClock(STARTED)
        with redirect_stdout(io.StringIO()), self.assertRaises(asc_cli.AscError):
            ios_release.call_with_retries(
                boom, deadline=STARTED + 90, poll_seconds=30, now=clock.now, sleep=clock.sleep
            )
        self.assertEqual(clock.sleeps, [30, 30, 30])

    def test_checks_run_asc_read_only(self) -> None:
        env = {"APP_STORE_CONNECT_API_KEY_ID": "K", "APP_STORE_CONNECT_ISSUER_ID": "I", "APP_STORE_CONNECT_API_KEY_P8": "P"}
        with mock.patch.dict(os.environ, env, clear=True):
            _, client = ios_release.asc_client()
        self.assertTrue(client.read_only)

    def test_build_number_counts_every_build_of_the_pinned_app(self) -> None:
        fake = FakeAsc(builds=[build_row("B1", number="7"), build_row("B2", number="3", state="PROCESSING")])
        with tempfile.NamedTemporaryFile("r", suffix=".out") as out, mock.patch.object(
            ios_release, "asc_client", return_value=(asc_release, fake)
        ), mock.patch.object(ios_release, "single_project_value", return_value="6"), mock.patch.dict(
            os.environ, {"GITHUB_OUTPUT": out.name}
        ), redirect_stdout(io.StringIO()):
            ios_release.main(["build-number"])
            written = Path(out.name).read_text()
        self.assertIn("build_number=8", written)
        listing = [c for c in fake.calls if c[:2] == ("builds", "list")][0]
        self.assertEqual((flag(listing, "--app"), flag(listing, "--processing-state")), (ASC_APP, "all"))
        self.assertIn("--paginate", listing)
        self.assertEqual(fake.writes(), [])


LISTING_FILES = {
    "description": "description.txt",
    "keywords": "keywords.txt",
    "promotionalText": "promotional_text.txt",
    "marketingUrl": "marketing_url.txt",
    "supportUrl": "support_url.txt",
    "whatsNew": "whats_new.txt",
}


SHOT_SIZES = {"APP_IPHONE_67": (1260, 2736), "APP_IPHONE_65": (1242, 2688)}


def write_metadata(tmp: Path, *, screenshots: bool = False, color_type: int = 2, **overrides: str) -> Path:
    """An en-US listing under tmp whose text equals LIVE_TEXT unless overridden.

    What's New is marked for VERSION. With screenshots, three distinct synthetic
    PNGs per display type are listed in screenshots.json, relative to tmp (the
    tests use tmp as the repository root), so the committed images never matter.
    """
    loc = tmp / "ios" / "en-US"
    loc.mkdir(parents=True, exist_ok=True)
    for field, filename in LISTING_FILES.items():
        (loc / filename).write_text(overrides.get(field, LIVE_TEXT[field]) + "\n")
    (tmp / "ios" / "whats_new_version.txt").write_text(VERSION + "\n")
    if screenshots:
        manifest: dict[str, list[str]] = {}
        for display_type, (width, height) in SHOT_SIZES.items():
            manifest[display_type] = []
            for number in range(1, 4):
                entry = f"shots/{display_type}/{number}.png"
                png(tmp / entry, width, height, color_type)
                with (tmp / entry).open("ab") as handle:
                    handle.write(f"{display_type}-{number}".encode())  # distinct contents
                manifest[display_type].append(entry)
        (loc / "screenshots.json").write_text(json.dumps(manifest))
    return tmp


def shot_checksums(tmp: Path) -> dict[str, list[str]]:
    """MD5s of the screenshots write_metadata listed, per display type, in order."""
    manifest = json.loads((tmp / "ios" / "en-US" / "screenshots.json").read_text())
    return {
        display_type: [hashlib.md5((tmp / entry).read_bytes()).hexdigest() for entry in entries]
        for display_type, entries in manifest.items()
    }


def run_asc_main(fake: FakeAsc, env_flags: dict[str, str], *args: str,
                 products: mock.Mock | None = None, root: Path | None = None) -> tuple[int, str]:
    """Run asc_release.main() against a fake; products=None uses the real product code.

    root replaces the repository root that screenshot paths are resolved against.
    """
    env = {k: v for k, v in os.environ.items() if k not in ASC_FLAGS}
    env.update(env_flags)
    out = io.StringIO()
    code = 0
    with contextlib.ExitStack() as stack:
        stack.enter_context(mock.patch.dict(os.environ, env, clear=True))
        stack.enter_context(mock.patch.object(asc_release, "asc_from_environment", side_effect=fake.connect))
        if root is not None:
            stack.enter_context(mock.patch.object(asc_release, "ROOT", root))
        if products is not None:
            stack.enter_context(mock.patch.object(asc_release, "submit_in_app_purchases", products))
        stack.enter_context(redirect_stdout(out))
        stack.enter_context(redirect_stderr(out))
        try:
            asc_release.main(list(args))
        except SystemExit as exc:
            code = exc.code if isinstance(exc.code, int) else 1
    return code, out.getvalue()


SUBMIT = {"SUBMIT_IOS_REVIEW": "true"}
SUBMIT_ARGS = ("--version", VERSION, "--build-id", "B9", "--build-number", "6")
LIFETIME = "com.quitall.premium.lifetime"
WEEKLY = "com.quitall.premium.weekly"


def submits(fake: FakeAsc) -> list[str]:
    """Review submissions sent to App Review, in order."""
    return [flag(c, "--id") for c in fake.writes() if c[:2] == ("review", "submissions-submit")]


class LiveSubmitFlowTests(unittest.TestCase):
    def run_main(self, fake: FakeAsc) -> tuple[int, mock.Mock]:
        products = mock.Mock(return_value=asc_release.ProductSubmitResult("SUB1", 0, False))
        code, _ = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS, products=products)
        return code, products

    def test_selects_rechecks_then_submits(self) -> None:
        fake = FakeAsc()
        code, products = self.run_main(fake)
        self.assertEqual(code, 0)
        calls = [c[:2] for c in fake.calls]
        select = calls.index(("versions", "attach-build"))
        submit = calls.index(("review", "submissions-submit"))
        reads = [i for i, c in enumerate(calls) if c == ("versions", "view")]
        build_checks = [i for i, c in enumerate(calls) if c == ("builds", "list")]
        self.assertEqual(len(reads), 2, "selection must be read back and rechecked")
        self.assertTrue(select < reads[0] < reads[1] < submit)
        self.assertEqual(len(build_checks), 2)
        self.assertTrue(build_checks[1] < reads[1] < submit, "build must be re-verified just before submit")
        self.assertIn(("versions", "update"), calls)  # release type
        self.assertEqual(flag([c for c in fake.calls if c[:2] == ("versions", "update")][0], "--release-type"), "MANUAL")
        added = [c for c in fake.writes() if c[:2] == ("review", "items-add")]
        self.assertEqual([(flag(c, "--item-type"), flag(c, "--item-id")) for c in added], [("appStoreVersions", "V1")])
        self.assertEqual(fake.read_only_modes, [False])
        products.assert_called_once()

    def test_selection_changed_before_submit_aborts(self) -> None:
        fake = FakeAsc(revert_after_select=True)
        code, _ = self.run_main(fake)
        self.assertEqual(code, 1)
        self.assertEqual(submits(fake), [])

    def test_waiting_for_review_with_another_build_aborts(self) -> None:
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="OTHER")
        code, products = self.run_main(fake)
        self.assertEqual(code, 1)
        products.assert_not_called()
        self.assertEqual(fake.writes(), [])

    def test_waiting_for_review_with_this_build_is_idempotent(self) -> None:
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9")
        code, products = self.run_main(fake)
        self.assertEqual(code, 0)
        products.assert_called_once()
        self.assertEqual(fake.writes(), [])

    def test_live_version_is_not_submittable(self) -> None:
        fake = FakeAsc(state="READY_FOR_SALE")
        code, products = self.run_main(fake)
        self.assertEqual(code, 1)
        products.assert_not_called()
        self.assertEqual(fake.writes(), [])

    def test_another_app_record_stops_before_any_change(self) -> None:
        for fake in (FakeAsc(bundle="com.example.other"), FakeAsc(record_id="1234567890")):
            code, products = self.run_main(fake)
            self.assertEqual(code, 1)
            products.assert_not_called()
            self.assertFalse(fake.writes())
            self.assertEqual(fake.calls[0], ("apps", "view", "--id", ASC_APP))

    def test_a_reused_draft_with_items_this_release_did_not_choose_is_not_submitted(self) -> None:
        stray = [{"id": "STRAY", "relationships": {"inAppPurchaseVersion": {"data": {"id": "OTHER-IAPv1"}}}}]
        fake = FakeAsc(drafts=["D1"], draft_items={"D1": stray})
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 1, output)
        self.assertIn("did not choose", output)
        self.assertEqual(submits(fake), [])
        # A catalog product's version (in any state) and this version are fine.
        iaps = [{"id": "IAP1", "attributes": {"name": "Lifetime", "productId": LIFETIME, "state": "APPROVED"}}]
        held = [{"id": "OK", "relationships": {"inAppPurchaseVersion": {"data": {"id": "IAP1v1"}}}}]
        fake = FakeAsc(iaps=iaps, drafts=["D1"], draft_items={"D1": held})
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        self.assertEqual(submits(fake), ["D1"])

    def test_a_creative_draft_is_never_used_for_the_version(self) -> None:
        creative = [{"id": "IMG", "relationships": {"appAssetLibraryImage": {"data": {"id": "H"}}}}]
        fake = FakeAsc(drafts=["CREATIVE"], draft_items={"CREATIVE": creative})
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        self.assertIn(("review", "submissions-create"), [c[:2] for c in fake.writes()])
        self.assertEqual(len(submits(fake)), 1)
        self.assertNotEqual(submits(fake)[0], "CREATIVE")

    def test_a_ready_for_review_version_with_no_draft_holding_it_stops_before_any_write(self) -> None:
        # READY_FOR_REVIEW says a draft holds the version; the only draft here does not.
        held = [{"id": "P", "relationships": {"subscriptionVersion": {"data": {"id": "S1v2"}}}}]
        subs = [{"id": "S1", "attributes": {"name": "Weekly", "productId": WEEKLY, "state": "READY_TO_SUBMIT"}}]
        for drafts, items in ((["D1"], {"D1": held}), ([], {})):
            fake = FakeAsc(state="READY_FOR_REVIEW", subscriptions=subs, drafts=drafts, draft_items=items)
            with self.subTest(drafts=drafts):
                code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
                self.assertEqual(code, 1, output)
                self.assertIn("no draft review submission holds it", output)
                self.assertEqual(fake.writes(), [])

    def test_a_draft_that_lost_this_version_is_never_submitted(self) -> None:
        # The version leaves the draft between the start of the run and the submit.
        fake = FakeAsc(state="READY_FOR_REVIEW", drafts=["D1"], draft_items={"D1": [version_item()]})
        fake_run = fake.run

        def run(*args, **kwargs):
            if args[:2] == ("versions", "update"):
                fake.items["D1"] = []
            return fake_run(*args, **kwargs)

        fake.run = run  # type: ignore[method-assign]
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 1, output)
        self.assertIn("does not hold App Store version V1", output)
        self.assertEqual(submits(fake), [])

    def test_the_draft_holding_this_version_is_chosen_over_others(self) -> None:
        other = [{"id": "P", "relationships": {"subscriptionVersion": {"data": {"id": "S1v2"}}}}]
        subs = [{"id": "S1", "attributes": {"name": "Weekly", "productId": WEEKLY, "state": "READY_TO_SUBMIT"}}]
        fake = FakeAsc(state="READY_FOR_REVIEW", subscriptions=subs, drafts=["OTHER", "MINE"],
                       draft_items={"OTHER": other, "MINE": [version_item()]})
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        self.assertEqual({flag(c, "--submission") for c in fake.writes() if c[:2] == ("review", "items-add")}, {"MINE"})
        self.assertEqual(submits(fake), ["MINE"])

    def test_another_versions_draft_is_never_reused(self) -> None:
        theirs = [version_item("V0")]
        fake = FakeAsc(drafts=["THEIRS"], draft_items={"THEIRS": theirs})
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        self.assertIn(("review", "submissions-create"), [c[:2] for c in fake.writes()])
        self.assertNotIn("THEIRS", [flag(c, "--submission") for c in fake.writes() if c[:2] == ("review", "items-add")])
        self.assertEqual(len(submits(fake)), 1)
        self.assertNotEqual(submits(fake)[0], "THEIRS")


LISTING_ON = {"UPLOAD_LISTING": "true", "UPLOAD_WHATS_NEW": "true"}


class MetadataRerunTests(unittest.TestCase):
    """Reruns with the listing switches on after a submission was started or completed."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)

    def run_live(self, fake: FakeAsc, flags: dict[str, str], **text: str) -> tuple[int, str, mock.Mock]:
        write_metadata(self.tmp, screenshots="UPLOAD_SCREENSHOTS" in flags, **text)
        products = mock.Mock(return_value=asc_release.ProductSubmitResult("SUB1", 0, False))
        code, output = run_asc_main(fake, flags, "--metadata-dir", str(self.tmp), *SUBMIT_ARGS,
                                    products=products, root=self.tmp)
        return code, output, products

    def checksums(self) -> dict[str, list[str]]:
        write_metadata(self.tmp, screenshots=True)
        return shot_checksums(self.tmp)

    def updates(self, fake: FakeAsc) -> list[set[str]]:
        return [text_flags(c) for c in fake.writes() if c[:2] == ("localizations", "update")]

    def test_ready_for_review_rerun_updates_text_and_submits(self) -> None:
        # Before: "version '1.2.2' is not editable for metadata (state=READY_FOR_REVIEW)".
        fake = FakeAsc(state="READY_FOR_REVIEW", drafts=["D1"], draft_items={"D1": [version_item()]})
        code, output, _ = self.run_live(fake, {**LISTING_ON, "SUBMIT_IOS_REVIEW": "true"}, whatsNew="New text")
        self.assertEqual(code, 0, output)
        self.assertEqual(self.updates(fake), [{"--whats-new"}], "only the field that differs is written")
        update = [c for c in fake.writes() if c[:2] == ("localizations", "update")][0]
        self.assertEqual(flag(update, "--whats-new"), "New text")
        self.assertEqual(submits(fake), ["D1"])
        # The version already sits in the draft, so it is not added again.
        self.assertFalse([c for c in fake.writes() if c[:2] == ("review", "items-add")])

    def test_ready_for_review_rerun_does_not_replace_screenshots(self) -> None:
        stale = self.checksums()
        stale["APP_IPHONE_65"] = ["0" * 32] * 3
        fake = FakeAsc(state="READY_FOR_REVIEW", screenshot_sets=stale)
        code, output, products = self.run_live(
            fake, {**LISTING_ON, "UPLOAD_SCREENSHOTS": "true", "SUBMIT_IOS_REVIEW": "true"}, whatsNew="New text")
        self.assertEqual(code, 1)
        self.assertIn("APP_IPHONE_65", output)
        self.assertFalse(fake.writes(), "nothing is written when any change cannot be applied")
        products.assert_not_called()

    def test_ready_for_review_rerun_with_matching_screenshots_submits(self) -> None:
        fake = FakeAsc(state="READY_FOR_REVIEW", screenshot_sets=self.checksums(), drafts=["D1"],
                       draft_items={"D1": [version_item()]})
        code, output, _ = self.run_live(fake, {**LISTING_ON, "UPLOAD_SCREENSHOTS": "true", "SUBMIT_IOS_REVIEW": "true"})
        self.assertEqual(code, 0, output)
        self.assertIn("already up to date", output)
        self.assertFalse([c for c in fake.writes() if c[:2] in {("localizations", "update"), ("screenshots", "upload")}])
        self.assertEqual(submits(fake), ["D1"])

    def test_waiting_for_review_rerun_with_matching_metadata_is_idempotent(self) -> None:
        # Before: "cannot update listing/What's New/screenshots while version '1.2.2' is WAITING_FOR_REVIEW".
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9", screenshot_sets=self.checksums())
        code, output, products = self.run_live(
            fake, {**LISTING_ON, "UPLOAD_SCREENSHOTS": "true", "SUBMIT_IOS_REVIEW": "true"})
        self.assertEqual(code, 0, output)
        self.assertFalse(fake.writes(), "nothing to change and nothing to submit again")
        products.assert_called_once()

    def test_waiting_for_review_rerun_that_needs_a_change_fails_before_any_write(self) -> None:
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9")
        code, output, products = self.run_live(fake, {**LISTING_ON, "SUBMIT_IOS_REVIEW": "true"}, keywords="new,words")
        self.assertEqual(code, 1)
        self.assertIn("keywords", output)
        self.assertFalse(fake.writes())
        products.assert_not_called()

    def test_waiting_for_review_with_another_build_fails_even_if_metadata_matches(self) -> None:
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="OTHER")
        code, _, products = self.run_live(fake, {**LISTING_ON, "SUBMIT_IOS_REVIEW": "true"})
        self.assertEqual(code, 1)
        self.assertFalse(fake.writes())
        products.assert_not_called()

    def test_metadata_switches_on_a_live_version_still_fail(self) -> None:
        fake = FakeAsc(state="READY_FOR_SALE")
        code, output, _ = self.run_live(fake, {"UPLOAD_LISTING": "true"})
        self.assertEqual(code, 1)
        self.assertIn("not editable", output)
        self.assertFalse(fake.writes())

    def test_editable_version_writes_only_what_differs(self) -> None:
        stale = self.checksums()
        stale["APP_IPHONE_67"] = list(reversed(stale["APP_IPHONE_67"]))  # same files, wrong order
        fake = FakeAsc(screenshot_sets=stale)
        code, output, _ = self.run_live(fake, {**LISTING_ON, "UPLOAD_SCREENSHOTS": "true"}, description="New")
        self.assertEqual(code, 0, output)
        self.assertEqual(self.updates(fake), [{"--description"}])
        self.assertEqual([display for display, _ in fake.uploaded], ["APP_IPHONE_67"])
        # The set now holds the manifest's files in the manifest's order.
        self.assertEqual(fake.screenshot_sets["APP_IPHONE_67"], shot_checksums(self.tmp)["APP_IPHONE_67"])

    def test_missing_locale_fails_before_any_write(self) -> None:
        fake = FakeAsc(localization={})
        code, output, _ = self.run_live(fake, LISTING_ON)
        self.assertEqual(code, 1)
        self.assertIn("no en-US localization", output)
        self.assertFalse(fake.writes())

    def test_a_leading_at_sign_reaches_app_store_connect_as_text(self) -> None:
        fake = FakeAsc()
        code, output, _ = self.run_live(fake, {"UPLOAD_LISTING": "true"}, promotionalText="@quitall is here")
        self.assertEqual(code, 0, output)
        update = [c for c in fake.writes() if c[:2] == ("localizations", "update")][0]
        self.assertEqual(flag(update, "--promotional-text"), "@@quitall is here")


class MultiLocaleTests(unittest.TestCase):
    """Every listing locale is compared and written on its own localization."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.meta = write_metadata(Path(tmp.name) / "meta")
        german = dict(LIVE_TEXT, description="Hör mit allem auf.", keywords="aufhören,gewohnheiten")
        loc = self.meta / "ios" / "de-DE"
        loc.mkdir(parents=True)
        for field, filename in LISTING_FILES.items():
            (loc / filename).write_text(german[field] + "\n")
        self.creative = Path(tmp.name) / "creative"
        (self.creative / "header").mkdir(parents=True)
        (self.creative / "header" / "header.png").write_bytes(b"header-image")

    def run_locales(self, fake: FakeAsc, flags: dict[str, str]) -> tuple[int, str]:
        return run_asc_main(fake, flags, "--version", VERSION, "--metadata-dir", str(self.meta),
                            "--creative-dir", str(self.creative))

    def test_text_goes_to_the_localization_of_its_own_locale(self) -> None:
        fake = FakeAsc(other_locales={"de-DE": dict(LIVE_TEXT)})
        code, output = self.run_locales(fake, {"UPLOAD_LISTING": "true"})
        self.assertEqual(code, 0, output)
        updates = [c for c in fake.writes() if c[:2] == ("localizations", "update")]
        self.assertEqual([flag(c, "--id") for c in updates], ["LOC-de-DE"], "en-US already matches")
        self.assertEqual((flag(updates[0], "--description"), flag(updates[0], "--keywords")),
                         ("Hör mit allem auf.", "aufhören,gewohnheiten"))

    def test_a_locale_missing_on_the_version_stops_every_write(self) -> None:
        fake = FakeAsc(localization=dict(LIVE_TEXT, description="Old"))
        code, output = self.run_locales(fake, {"UPLOAD_LISTING": "true"})
        self.assertEqual(code, 1)
        self.assertIn("no de-DE localization", output)
        self.assertEqual(fake.writes(), [])

    def test_an_approved_image_is_placed_on_every_locale(self) -> None:
        size = (self.creative / "header" / "header.png").stat().st_size
        library = [{"id": "H", "attributes": {"fileName": "header.png", "fileSize": size, "state": "APPROVED",
                                              "createdDate": "2026-10-20"}}]
        old = {"id": "PL-old", "attributes": {"placementType": "PRODUCT_PAGE_HEADER_ASSET"},
               "relationships": {"image": {"data": {"id": "OLDIMG"}}}}
        fake = FakeAsc(other_locales={"de-DE": dict(LIVE_TEXT)}, library=library, placements=[old])
        code, output = self.run_locales(fake, {"UPLOAD_CREATIVE_ASSETS": "true"})
        self.assertEqual(code, 0, output)
        placed = {(c[2], flag(c, "--localization-id")) for c in fake.writes() if c[:2] == ("localizations", "placements")}
        self.assertEqual(placed, {("swap", "LOC"), ("create", "LOC-de-DE")})
        # A second run finds the image on both and writes nothing.
        writes = len(fake.writes())
        self.assertEqual(self.run_locales(fake, {"UPLOAD_CREATIVE_ASSETS": "true"})[0], 0)
        self.assertEqual(len(fake.writes()), writes)


class MetadataPlanTests(unittest.TestCase):
    def plan(self, client, tmp: Path, sets: dict | None = None) -> list:
        return asc_release.plan_metadata(
            client, version_id="V1", locales=["en-US"], metadata_dir=tmp,
            include_listing=True, include_whats_new=True, screenshot_sets=sets or {},
        )

    def test_text_is_compared_without_outer_whitespace_or_line_ending_noise(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            write_metadata(Path(tmp), description="Line one\nLine two")
            live = dict(LIVE_TEXT, description="  Line one\r\nLine two\n")
            plans = self.plan(FakeAsc(localization=live), Path(tmp))
        self.assertEqual(plans[0].text_changes, {})
        self.assertEqual(len(plans[0].text_fields), 6)

    def test_state_rules(self) -> None:
        plan = asc_release.LocalePlan("en-US", "LOC")
        plan.text_changes = {"whatsNew": "x"}
        plan.stale_screenshots = ["APP_IPHONE_67"]
        problems = asc_release.metadata_problems
        self.assertEqual(problems([plan], version=VERSION, state="PREPARE_FOR_SUBMISSION"), [])
        ready = problems([plan], version=VERSION, state="READY_FOR_REVIEW")
        self.assertEqual(len(ready), 1)
        self.assertIn("screenshots", ready[0])
        self.assertEqual(len(problems([plan], version=VERSION, state="WAITING_FOR_REVIEW")), 2)
        plan.stale_screenshots = []
        self.assertEqual(problems([plan], version=VERSION, state="READY_FOR_REVIEW"), [])
        plan.text_changes = {}
        self.assertEqual(problems([plan], version=VERSION, state="WAITING_FOR_REVIEW"), [])

    def test_failed_or_missing_screenshots_are_never_up_to_date(self) -> None:
        tmp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(tmp_dir.cleanup)
        tmp = write_metadata(Path(tmp_dir.name), screenshots=True)
        manifest = json.loads((tmp / "ios" / "en-US" / "screenshots.json").read_text())
        pngs = [tmp / entry for entry in manifest["APP_IPHONE_67"]]
        checksums = shot_checksums(tmp)["APP_IPHONE_67"]
        fake = FakeAsc(screenshot_sets={"APP_IPHONE_67": checksums})
        self.assertTrue(asc_release.screenshots_up_to_date(fake, "LOC", "APP_IPHONE_67", pngs))
        self.assertFalse(asc_release.screenshots_up_to_date(fake, "LOC", "APP_IPHONE_67", pngs[:-1]))
        self.assertFalse(asc_release.screenshots_up_to_date(fake, "LOC", "APP_IPHONE_67", list(reversed(pngs))))
        self.assertFalse(asc_release.screenshots_up_to_date(fake, "LOC", "APP_IPHONE_65", pngs))
        failed = FakeAsc(screenshot_sets={"APP_IPHONE_67": checksums}, failed_delivery={"APP_IPHONE_67"})
        self.assertFalse(asc_release.screenshots_up_to_date(failed, "LOC", "APP_IPHONE_67", pngs))

    def test_one_listing_per_localization_covers_every_set(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            write_metadata(Path(tmp), screenshots=True)
            sets = {"en-US": asc_release.load_screenshot_sets(Path(tmp), "en-US", Path(tmp))}
            fake = FakeAsc()
            plans = self.plan(fake, Path(tmp), sets)
        self.assertEqual(sorted(plans[0].stale_screenshots), ["APP_IPHONE_65", "APP_IPHONE_67"])
        self.assertEqual([c[:2] for c in fake.calls].count(("screenshots", "list")), 1)
        self.assertEqual(flag([c for c in fake.calls if c[:2] == ("screenshots", "list")][0],
                              "--version-localization"), "LOC")


class AlphaChannelTests(unittest.TestCase):
    """asc refuses PNGs with an alpha channel, so a set that must be replaced needs RGB files."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)

    def chunk(self, kind: bytes, payload: bytes) -> bytes:
        return len(payload).to_bytes(4, "big") + kind + payload + b"\x00" * 4

    def test_alpha_is_read_like_asc_reads_it(self) -> None:
        for color_type, alpha in ((2, False), (0, False), (6, True), (4, True)):
            path = self.tmp / f"{color_type}.png"
            png(path, 1260, 2736, color_type)
            with self.subTest(color_type=color_type):
                self.assertIs(asc_cli.image_has_alpha(path), alpha)
        palette = self.tmp / "palette.png"
        header = (1260).to_bytes(4, "big") + (2736).to_bytes(4, "big") + bytes([8, 3, 0, 0, 0])
        palette.write_bytes(b"\x89PNG\r\n\x1a\n" + self.chunk(b"IHDR", header) + self.chunk(b"PLTE", b"\x00" * 3)
                            + self.chunk(b"tRNS", b"\x00") + self.chunk(b"IDAT", b"\x00") + self.chunk(b"IEND", b""))
        self.assertTrue(asc_cli.image_has_alpha(palette), "a tRNS chunk is transparency")
        opaque = self.tmp / "opaque.png"
        opaque.write_bytes(palette.read_bytes().replace(self.chunk(b"tRNS", b"\x00"), b""))
        self.assertFalse(asc_cli.image_has_alpha(opaque))
        (self.tmp / "gif.png").write_bytes(b"GIF89a")
        self.assertFalse(asc_cli.image_has_alpha(self.tmp / "gif.png"))

    def run_screenshots(self, fake: FakeAsc, *extra: str) -> tuple[int, str]:
        write_metadata(self.tmp, screenshots=True, color_type=6)
        return run_asc_main(fake, {"UPLOAD_SCREENSHOTS": "true"}, *extra, "--metadata-dir", str(self.tmp),
                            "--version", VERSION, root=self.tmp)

    def test_a_set_that_must_be_replaced_with_alpha_files_stops_before_any_write(self) -> None:
        for extra in ((), ("--preflight",)):
            fake = FakeAsc()
            with self.subTest(extra=extra):
                code, output = self.run_screenshots(fake, *extra)
                self.assertEqual(code, 1)
                self.assertIn("alpha channel", output)
                self.assertEqual(fake.writes(), [])

    def test_alpha_files_already_in_app_store_connect_pass(self) -> None:
        write_metadata(self.tmp, screenshots=True, color_type=6)
        fake = FakeAsc(screenshot_sets=shot_checksums(self.tmp))
        code, output = self.run_screenshots(fake)
        self.assertEqual(code, 0, output)
        self.assertIn("alpha channel", output, "the dry-run style note still names the limit")
        self.assertEqual(fake.writes(), [])


class PreflightTests(unittest.TestCase):
    """--preflight: read-only checks before the build, never on validation runs (workflow)."""

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.tmp = write_metadata(Path(tmp.name), screenshots=True)

    def preflight(self, fake: FakeAsc, flags: dict[str, str], *extra: str) -> tuple[int, str]:
        code, output = run_asc_main(fake, flags, "--preflight", "--metadata-dir", str(self.tmp), "--version", VERSION,
                                    *extra, root=self.tmp)
        self.assertFalse(fake.writes(), "the preflight must only read")
        self.assertEqual(fake.read_only_modes, [True], "the preflight runs asc read-only")
        return code, output

    def test_passes_for_an_editable_version_without_a_build(self) -> None:
        flags = {**LISTING_ON, "UPLOAD_SCREENSHOTS": "true", "SUBMIT_IOS_REVIEW": "true", "PUBLIC_RELEASE": "true"}
        code, output = self.preflight(FakeAsc(), flags)
        self.assertEqual(code, 0, output)
        self.assertIn("preflight passed", output)
        self.assertIn("will update", output)

    def test_missing_app_store_version_fails_early(self) -> None:
        code, output = self.preflight(FakeAsc(has_version=False), {"SUBMIT_IOS_REVIEW": "true"})
        self.assertEqual(code, 1)
        self.assertIn("create the version in App Store Connect first", output)

    def test_locked_version_fails_for_metadata_and_for_submit(self) -> None:
        for flags in ({"UPLOAD_LISTING": "true"}, {"SUBMIT_IOS_REVIEW": "true"}):
            with self.subTest(flags=flags):
                code, _ = self.preflight(FakeAsc(state="READY_FOR_SALE"), flags)
                self.assertEqual(code, 1)

    def test_submit_while_waiting_for_review_fails_before_the_build(self) -> None:
        code, output = self.preflight(FakeAsc(state="WAITING_FOR_REVIEW"), {"SUBMIT_IOS_REVIEW": "true"})
        self.assertEqual(code, 1)
        self.assertIn("could never be selected", output)

    def test_needed_change_the_state_cannot_take_fails(self) -> None:
        live = dict(LIVE_TEXT, whatsNew="Old text")
        code, output = self.preflight(FakeAsc(state="WAITING_FOR_REVIEW", localization=live), LISTING_ON)
        self.assertEqual(code, 1)
        self.assertIn("whatsNew", output)
        code, output = self.preflight(FakeAsc(state="READY_FOR_REVIEW", localization=live), LISTING_ON)
        self.assertEqual(code, 0, output)

    def test_missing_locale_fails(self) -> None:
        code, output = self.preflight(FakeAsc(localization={}), LISTING_ON)
        self.assertEqual(code, 1)
        self.assertIn("no en-US localization", output)

    def test_other_app_fails(self) -> None:
        code, output = self.preflight(FakeAsc(bundle="com.example.other"), {"SUBMIT_IOS_REVIEW": "true"})
        self.assertEqual(code, 1)
        self.assertIn("expected com.apoorvdarshan.Quit-All", output)

    def test_creative_assets_are_checked_without_writing(self) -> None:
        creative = self.tmp / "creative"
        (creative / "header").mkdir(parents=True)
        (creative / "header" / "header.png").write_bytes(b"header-image")
        flags = {"UPLOAD_CREATIVE_ASSETS": "true"}
        code, output = self.preflight(FakeAsc(), flags, "--creative-dir", str(creative))
        self.assertEqual(code, 0, output)
        self.assertIn("will upload header.png and send it to App Review", output)
        code, output = self.preflight(FakeAsc(state="WAITING_FOR_REVIEW"), flags, "--creative-dir", str(creative))
        self.assertEqual(code, 1)
        self.assertIn("not in the Asset Library yet", output)
        code, output = self.preflight(FakeAsc(state="READY_FOR_SALE"), flags, "--creative-dir", str(creative))
        self.assertEqual(code, 1)
        self.assertIn("not editable", output)


class CreateVersionTests(unittest.TestCase):
    """--create-version (IOS_CREATE_VERSION): add the tag's App Store version only when it is missing."""

    ON = {"CREATE_IOS_VERSION": "true"}

    def create(self, fake: FakeAsc, flags: dict[str, str] | None = None, version: str = VERSION) -> tuple[int, str]:
        return run_asc_main(fake, self.ON if flags is None else flags, "--create-version", "--version", version)

    def test_switch_off_makes_no_calls(self) -> None:
        fake = FakeAsc(has_version=False)
        code, output = self.create(fake, {})
        self.assertEqual(code, 0, output)
        self.assertIn("skipped", output)
        self.assertEqual(fake.calls, [])

    def test_existing_version_is_left_alone(self) -> None:
        fake = FakeAsc(state="READY_FOR_REVIEW")
        code, output = self.create(fake)
        self.assertEqual(code, 0, output)
        self.assertIn("already exists (READY_FOR_REVIEW)", output)
        self.assertEqual(fake.writes(), [])

    def test_missing_version_is_created_for_this_app_and_read_back(self) -> None:
        fake = FakeAsc(has_version=False)
        code, output = self.create(fake)
        self.assertEqual(code, 0, output)
        self.assertEqual([c[:2] for c in fake.writes()], [("versions", "create")])
        create = fake.writes()[0]
        self.assertEqual((flag(create, "--app"), flag(create, "--version"), flag(create, "--platform")),
                         (ASC_APP, VERSION, "IOS"))
        self.assertEqual(fake.calls[-1][:2], ("versions", "list"), "the created version must be read back")
        self.assertIn(f"created App Store version {VERSION} (PREPARE_FOR_SUBMISSION)", output)
        self.assertEqual(fake.read_only_modes, [False])

    def test_another_version_on_its_way_blocks_creation(self) -> None:
        for state in ("PREPARE_FOR_SUBMISSION", "WAITING_FOR_REVIEW", "PENDING_DEVELOPER_RELEASE"):
            with self.subTest(state=state):
                fake = FakeAsc(has_version=False, other_versions=[("1.2.1", "READY_FOR_SALE"), ("1.1", state)])
                code, output = self.create(fake)
                self.assertEqual(code, 1)
                self.assertIn(f"is still {state}", output)
                self.assertEqual(fake.writes(), [])

    def test_version_not_newer_than_an_existing_one_is_refused(self) -> None:
        for existing in ("1.3", "1.2.10", "2"):
            with self.subTest(existing=existing):
                fake = FakeAsc(has_version=False, other_versions=[(existing, "READY_FOR_SALE")])
                code, output = self.create(fake)
                self.assertEqual(code, 1)
                self.assertEqual(fake.writes(), [])

    def test_older_finished_versions_allow_creation(self) -> None:
        fake = FakeAsc(has_version=False, other_versions=[("1.0", "REPLACED_WITH_NEW_VERSION"), ("1.2.1", "READY_FOR_SALE")])
        code, output = self.create(fake)
        self.assertEqual(code, 0, output)
        self.assertEqual([c[:2] for c in fake.writes()], [("versions", "create")])

    def test_other_app_or_bad_version_fails_without_writing(self) -> None:
        fake = FakeAsc(bundle="com.example.other", has_version=False)
        code, output = self.create(fake)
        self.assertEqual(code, 1)
        self.assertIn("expected com.apoorvdarshan.Quit-All", output)
        self.assertEqual(fake.writes(), [])
        fake = FakeAsc(has_version=False)
        code, output = self.create(fake, version="1.2.2-beta")
        self.assertEqual(code, 1)
        self.assertEqual(fake.calls, [])

    def test_dry_run_makes_no_calls(self) -> None:
        fake = FakeAsc(has_version=False)
        code, output = run_asc_main(fake, self.ON, "--create-version", "--dry-run", "--version", VERSION)
        self.assertEqual(code, 0, output)
        self.assertEqual(fake.calls, [])

    def test_dry_run_rejects_a_bad_version_like_a_live_run(self) -> None:
        fake = FakeAsc(has_version=False)
        code, output = run_asc_main(fake, self.ON, "--create-version", "--dry-run", "--version", "1.2.2-beta")
        self.assertEqual(code, 1)
        self.assertIn("must look like", output)
        self.assertEqual(fake.calls, [])

    def test_create_version_never_runs_together_with_the_preflight(self) -> None:
        fake = FakeAsc(has_version=False)
        code, output = run_asc_main(fake, {**self.ON, "SUBMIT_IOS_REVIEW": "true"},
                                    "--create-version", "--preflight", "--version", VERSION)
        self.assertEqual(code, 1)
        self.assertIn("separate steps", output)
        self.assertEqual(fake.calls, [])

    def test_a_created_version_that_does_not_read_back_fails_naming_it(self) -> None:
        fake = FakeAsc(has_version=False, listed_after_create=False)  # App Store Connect does not list it yet
        code, output = self.create(fake)
        self.assertEqual(code, 1)
        self.assertIn(f"created App Store version {VERSION}, but reading it back found 0 records", output)
        self.assertNotIn("turn on IOS_CREATE_VERSION", output)


LIFETIME_READY = [{"id": "IAP1", "attributes": {"name": "Lifetime", "productId": LIFETIME, "state": "READY_TO_SUBMIT"}}]


class ProductSubmissionTests(unittest.TestCase):
    """Products are attached to the draft and reach App Review only with the version."""

    def test_products_go_out_with_the_version_in_one_submit(self) -> None:
        fake = FakeAsc(iaps=LIFETIME_READY)
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        items = [(flag(c, "--item-type"), flag(c, "--item-id")) for c in fake.writes() if c[:2] == ("review", "items-add")]
        self.assertEqual(items, [("inAppPurchaseVersions", "IAP1v2"), ("appStoreVersions", "V1")],
                         "the purchase's current version, then the app version")
        calls = [c[:2] for c in fake.calls]
        last_item = max(i for i, c in enumerate(calls) if c == ("review", "items-add"))
        recheck = max(i for i, c in enumerate(calls) if c == ("versions", "view"))
        submit = [i for i, c in enumerate(calls) if c == ("review", "submissions-submit")]
        self.assertEqual(len(submit), 1, "one submit carries the version and its products")
        self.assertTrue(recheck < submit[0] and last_item < submit[0])

    def test_failed_recheck_sends_nothing_to_review(self) -> None:
        fake = FakeAsc(iaps=LIFETIME_READY, revert_after_select=True)
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 1)
        self.assertIn("not submitting", output)
        self.assertEqual(submits(fake), [])

    def test_subscriptions_attach_their_current_version_and_rejected_ones_are_retried(self) -> None:
        subs = [{"id": "S1", "attributes": {"name": "Weekly", "productId": WEEKLY, "state": "DEVELOPER_REJECTED"}},
                {"id": "S9", "attributes": {"name": "Legacy", "productId": "com.example.legacy", "state": "READY_TO_SUBMIT"}}]
        fake = FakeAsc(subscriptions=subs)
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        items = [(flag(c, "--item-type"), flag(c, "--item-id")) for c in fake.writes() if c[:2] == ("review", "items-add")]
        self.assertEqual(items, [("subscriptionVersions", "S1v2"), ("appStoreVersions", "V1")])
        self.assertFalse([c for c in fake.calls if "S9" in c], "a product outside the catalog was read")

    def test_a_product_that_cannot_be_added_keeps_the_version_out_of_review(self) -> None:
        fake = FakeAsc(iaps=LIFETIME_READY, refuse_items={"IAP1v2"})
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 1)
        self.assertIn("Not submitting the app version", output)
        added = [flag(c, "--item-type") for c in fake.writes() if c[:2] == ("review", "items-add")]
        self.assertNotIn("appStoreVersions", added)
        self.assertEqual(submits(fake), [])

    def test_late_products_go_out_in_a_product_only_draft(self) -> None:
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9", iaps=LIFETIME_READY)
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        items = [(flag(c, "--item-type"), flag(c, "--item-id")) for c in fake.writes() if c[:2] == ("review", "items-add")]
        self.assertEqual(items, [("inAppPurchaseVersions", "IAP1v2")])
        self.assertEqual(fake.writes()[-1][:2], ("review", "submissions-submit"))
        # A draft that holds an app version is never touched from here: the
        # products go out in a new product-only draft instead.
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9", iaps=LIFETIME_READY, drafts=["D1"],
                       draft_items={"D1": [version_item("V0")]})
        self.assertEqual(run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)[0], 0)
        self.assertNotIn("D1", [flag(c, "--submission") for c in fake.writes() if c[:2] == ("review", "items-add")])
        self.assertEqual(len(submits(fake)), 1)
        self.assertNotEqual(submits(fake)[0], "D1")
        # A product-only draft holding anything else this release did not choose
        # is never submitted.
        stray = [{"id": "X", "relationships": {"subscriptionVersion": {"data": {"id": "OTHER-SUBv1"}}}}]
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9", iaps=LIFETIME_READY, drafts=["D1"],
                       draft_items={"D1": stray})
        self.assertEqual(run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)[0], 1)
        self.assertEqual(submits(fake), [])

    def test_a_rerun_with_nothing_to_send_leaves_no_empty_draft(self) -> None:
        # Every catalog product approved, the version already in review: nothing is written.
        approved = [{"id": "IAP1", "attributes": {"name": "Lifetime", "productId": LIFETIME, "state": "APPROVED"}}]
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9", iaps=approved)
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        self.assertEqual(fake.writes(), [])
        # An earlier attempt's product draft is still finished.
        held = [{"id": "I1", "relationships": {"inAppPurchaseVersion": {"data": {"id": "IAP1v2"}}}}]
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9", iaps=LIFETIME_READY, drafts=["D1"],
                       draft_items={"D1": held})
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        self.assertEqual([c[:2] for c in fake.writes()], [("review", "submissions-submit")])
        self.assertEqual(submits(fake), ["D1"])

    def test_a_reused_draft_skips_what_it_already_holds(self) -> None:
        held = [{"id": "I1", "relationships": {"inAppPurchaseVersion": {"data": {"id": "IAP1v2"}}}}, version_item()]
        fake = FakeAsc(iaps=LIFETIME_READY, drafts=["D1"], draft_items={"D1": held})
        code, output = run_asc_main(fake, SUBMIT, *SUBMIT_ARGS)
        self.assertEqual(code, 0, output)
        self.assertEqual([c[:2] for c in fake.writes() if c[:1] == ("review",)], [("review", "submissions-submit")])
        self.assertEqual(submits(fake), ["D1"])


class FindAppTests(unittest.TestCase):
    def test_the_pinned_app_must_carry_the_bundle_id(self) -> None:
        fake = FakeAsc()
        self.assertEqual(quiet(asc_release.find_app, fake, BUNDLE), ASC_APP)
        self.assertEqual(fake.calls, [("apps", "view", "--id", ASC_APP)])
        for other in (FakeAsc(bundle="com.apoorvdarshan.Quit-All.beta"), FakeAsc(bundle=None),
                      FakeAsc(record_id="1234567890")):
            with self.subTest(bundle=other.bundle, record=other.record_id), self.assertRaises(SystemExit):
                quiet(asc_release.find_app, other, BUNDLE)

    def test_asc_failures_stop_with_a_readable_error(self) -> None:
        class Broken:
            def run(self, *args: str, **_: object):
                raise asc_cli.AscError(args, 3, "unauthorized")

        err = io.StringIO()
        with redirect_stderr(err), self.assertRaises(SystemExit):
            asc_release.find_app(Broken(), BUNDLE)
        self.assertIn("exit 3", err.getvalue())


class CreativeAssetTests(unittest.TestCase):
    ENV = {"UPLOAD_CREATIVE_ASSETS": "true"}

    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name) / "creative"
        for folder, contents in (("header", b"header-image"), ("search-results", b"search-image")):
            (self.dir / folder).mkdir(parents=True)
            (self.dir / folder / f"{folder}.png").write_bytes(contents)
        self.meta = write_metadata(Path(tmp.name) / "meta")

    def image(self, image_id: str, folder: str, state: str) -> dict:
        path = self.dir / folder / f"{folder}.png"
        return {"id": image_id, "attributes": {"fileName": path.name, "fileSize": path.stat().st_size, "state": state,
                                               "createdDate": "2026-10-20"}}

    def run_creative(self, fake: FakeAsc, flags: dict[str, str] | None = None) -> int:
        code, _ = run_asc_main(fake, {**self.ENV, **(flags or {})}, *SUBMIT_ARGS, "--creative-dir",
                               str(self.dir), "--metadata-dir", str(self.meta))
        return code

    def test_new_images_are_uploaded_and_reviewed_on_their_own(self) -> None:
        fake = FakeAsc()
        self.assertEqual(self.run_creative(fake), 0)
        uploads = [Path(flag(c, "--file")).name for c in fake.writes() if c[:3] == ("asset-library", "images", "upload")]
        self.assertEqual(uploads, ["header.png", "search-results.png"])
        review = [c for c in fake.writes() if c[:1] == ("review",)]
        self.assertEqual([c[:2] for c in review], [("review", "submissions-create"), ("review", "items-add"),
                                                   ("review", "items-add"), ("review", "submissions-submit")])
        self.assertEqual({flag(c, "--item-type") for c in review if c[:2] == ("review", "items-add")}, {"appAssetLibraryImages"})
        self.assertFalse([c for c in fake.writes() if c[:2] == ("localizations", "placements")])

    def test_images_in_review_are_neither_reuploaded_nor_placed(self) -> None:
        fake = FakeAsc(library=[self.image("H", "header", "WAITING_FOR_REVIEW"), self.image("S", "search-results", "IN_REVIEW")])
        self.assertEqual(self.run_creative(fake), 0)
        self.assertEqual(fake.writes(), [])

    def test_approved_images_are_placed_and_existing_ones_swapped(self) -> None:
        old = {"id": "PL-old", "attributes": {"placementType": "PRODUCT_PAGE_HEADER_ASSET"},
               "relationships": {"image": {"data": {"id": "OLDIMG"}}}}
        fake = FakeAsc(library=[self.image("H", "header", "APPROVED"), self.image("S", "search-results", "APPROVED")],
                       placements=[old])
        self.assertEqual(self.run_creative(fake), 0)
        swap = [c for c in fake.writes() if c[:3] == ("localizations", "placements", "swap")][0]
        self.assertEqual((flag(swap, "--image-id"), flag(swap, "--placement-id"), flag(swap, "--localization-id")),
                         ("H", "PL-old", "LOC"))
        self.assertIn("--confirm", swap)
        create = [c for c in fake.writes() if c[:3] == ("localizations", "placements", "create")][0]
        self.assertEqual((flag(create, "--image-id"), flag(create, "--placement-type"), flag(create, "--placement-group")),
                         ("S", "APP_STORE_SEARCH_RESULTS_ASSET", "DEFAULT_PROFILE"))
        # A second run finds both placed and writes nothing.
        writes = len(fake.writes())
        self.assertEqual(self.run_creative(fake), 0)
        self.assertEqual(len(fake.writes()), writes)

    def test_an_image_with_alpha_fails_before_any_call(self) -> None:
        (self.dir / "header" / "header.png").write_bytes(png_header(6))
        fake = FakeAsc()
        self.assertEqual(self.run_creative(fake), 1)
        self.assertEqual(fake.calls, [])

    def test_an_interrupted_upload_is_uploaded_again(self) -> None:
        # asc never deletes the reservation a failed upload leaves behind.
        fake = FakeAsc(library=[self.image("H0", "header", "AWAITING_UPLOAD"),
                                self.image("S", "search-results", "WAITING_FOR_REVIEW")])
        self.assertEqual(self.run_creative(fake), 0)
        uploads = [Path(flag(c, "--file")).name for c in fake.writes() if c[:3] == ("asset-library", "images", "upload")]
        self.assertEqual(uploads, ["header.png"])
        self.assertEqual(len(submits(fake)), 1)

    def test_a_rejected_image_stops_the_run(self) -> None:
        fake = FakeAsc(library=[self.image("H", "header", "REJECTED")])
        self.assertEqual(self.run_creative(fake), 1)
        self.assertEqual(fake.writes(), [])

    def test_a_locked_version_takes_no_new_images(self) -> None:
        fake = FakeAsc(state="WAITING_FOR_REVIEW", attached="B9")
        self.assertEqual(self.run_creative(fake), 1)
        self.assertEqual(fake.writes(), [])

    def test_a_locked_version_sends_nothing_to_review(self) -> None:
        for state in ("WAITING_FOR_REVIEW", "READY_FOR_REVIEW"):
            for image_state in ("UPLOAD_COMPLETE", "PREPARE_FOR_SUBMISSION"):
                fake = FakeAsc(state=state, attached="B9", library=[self.image("H", "header", image_state)])
                with self.subTest(state=state, image_state=image_state):
                    self.assertEqual(self.run_creative(fake), 1)
                    self.assertEqual(fake.writes(), [])

    def test_a_locked_version_takes_no_new_placements(self) -> None:
        library = [self.image("H", "header", "APPROVED"), self.image("S", "search-results", "WAITING_FOR_REVIEW")]
        fake = FakeAsc(state="READY_FOR_REVIEW", library=library)
        self.assertEqual(self.run_creative(fake), 1)
        self.assertEqual(fake.writes(), [])

    def test_creative_problems_stop_the_run_before_any_metadata_write(self) -> None:
        # The listing could change (READY_FOR_REVIEW takes text), but the new
        # image cannot: nothing at all is written.
        fake = FakeAsc(state="READY_FOR_REVIEW", localization=dict(LIVE_TEXT, description="Old"))
        self.assertEqual(self.run_creative(fake, {"UPLOAD_LISTING": "true"}), 1)
        self.assertEqual(fake.writes(), [])

    def test_a_retry_finishes_the_creative_draft_it_left_behind(self) -> None:
        library = [self.image("H", "header", "PREPARE_FOR_SUBMISSION"), self.image("S", "search-results", "PREPARE_FOR_SUBMISSION")]
        held = [{"id": "I-H", "relationships": {"appAssetLibraryImage": {"data": {"id": "H"}}}}]
        fake = FakeAsc(library=library, drafts=["OLD"], draft_items={"OLD": held})
        self.assertEqual(self.run_creative(fake), 0)
        self.assertNotIn(("review", "submissions-create"), [c[:2] for c in fake.writes()])
        self.assertEqual(submits(fake), ["OLD"])
        # A draft holding anything else is left alone and a new one is used.
        other = [version_item()]
        fake = FakeAsc(library=library, drafts=["VERSION"], draft_items={"VERSION": other})
        self.assertEqual(self.run_creative(fake), 0)
        self.assertEqual(len(submits(fake)), 1)
        self.assertNotEqual(submits(fake)[0], "VERSION")

    def test_a_creative_submission_with_other_items_is_not_submitted(self) -> None:
        fake = FakeAsc()
        fake_run = fake.run

        def run(*args, **kwargs):
            result = fake_run(*args, **kwargs)
            if args[:2] == ("review", "submissions-create"):
                fake.items[result["data"]["id"]] = [version_item()]
            return result

        fake.run = run  # type: ignore[method-assign]
        self.assertEqual(self.run_creative(fake), 1)
        self.assertEqual(submits(fake), [])

    def test_images_reviewed_first_then_the_version_is_submitted_in_its_own_draft(self) -> None:
        fake = FakeAsc()
        self.assertEqual(self.run_creative(fake, SUBMIT), 0)
        first, second = submits(fake)
        self.assertNotEqual(first, second)
        self.assertEqual(fake.items[second], [version_item("V1")])


class PrintGatesTests(unittest.TestCase):
    def run_print(self, env: dict[str, str]) -> str:
        out = io.StringIO()
        with redirect_stdout(out):
            print_gates.main([], env=env)
        return out.getvalue()

    def test_invalid_values_are_shown_as_invalid_not_false(self) -> None:
        output = self.run_print({"IOS_UPLOAD_BUILD": "maybe", "IOS_BUILD_POLL_SECONDS": "5",
                                 "IOS_BUILD_WAIT_MINUTES": "thirty", "IOS_RELEASE_AUTOMATION": "true"})
        self.assertIn("IOS_UPLOAD_BUILD=INVALID ('maybe'", output)
        self.assertIn("IOS_BUILD_POLL_SECONDS=INVALID ('5'", output)
        self.assertIn("IOS_BUILD_WAIT_MINUTES=INVALID ('thirty'", output)
        self.assertIn("WARNING: invalid values: IOS_UPLOAD_BUILD, IOS_BUILD_POLL_SECONDS, IOS_BUILD_WAIT_MINUTES", output)
        self.assertNotIn("IOS_UPLOAD_BUILD=false", output)

    def test_gates_and_summary_agree_on_valid_values(self) -> None:
        output = self.run_print({})
        self.assertIn("IOS_RELEASE_AUTOMATION=false", output)
        self.assertIn("IOS_BUILD_POLL_SECONDS=default (30)", output)
        self.assertIn("all switches off", output)
        output = self.run_print({"IOS_RELEASE_AUTOMATION": "on", "IOS_UPLOAD_BUILD": "1", "IOS_BUILD_WAIT_MINUTES": "90"})
        self.assertIn("IOS_UPLOAD_BUILD=true", output)
        self.assertIn("IOS_BUILD_WAIT_MINUTES=90", output)
        self.assertIn("one or more store switches are on", output)


    def test_creative_assets_switch_is_listed(self) -> None:
        self.assertIn("IOS_UPLOAD_CREATIVE_ASSETS=false", self.run_print({}))
        self.assertIn("IOS_UPLOAD_CREATIVE_ASSETS=INVALID ('maybe'", self.run_print({"IOS_UPLOAD_CREATIVE_ASSETS": "maybe"}))
        output = self.run_print({"IOS_RELEASE_AUTOMATION": "true", "IOS_UPLOAD_CREATIVE_ASSETS": "true"})
        self.assertIn("IOS_UPLOAD_CREATIVE_ASSETS=true", output)
        self.assertIn("one or more store switches are on", output)

# Obviously fake identifiers in the shape of an App Store Connect key ID and issuer ID.
KEY_ID = "TESTKEY0ID"
ISSUER_ID = "00000000-1111-2222-3333-444444444444"


class RedactLogsTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.logs = Path(tmp.name) / "logs"
        self.outside = Path(tmp.name) / "outside.txt"
        self.outside.write_text(f"kept {KEY_ID}")
        dist = self.logs / "QuitAll.xcdistributionlogs"
        dist.mkdir(parents=True)
        (self.logs / "archive.log").write_text(
            f"-authenticationKeyID {KEY_ID} -authenticationKeyIssuerID {ISSUER_ID}\n"
            f"AuthKey_{KEY_ID.lower()}.p8 issuer {ISSUER_ID.upper()}\n")
        (dist / "IDEDistribution.standard.log").write_text("no ids here\n")
        (dist / "binary.plist").write_bytes(b"bplist00\x00\x01" + KEY_ID.encode() + b"\x00" + ISSUER_ID.encode())
        (dist / "utf16.log").write_bytes(f"key {KEY_ID}".encode("utf-16-le"))
        (dist / f"AuthKey_{KEY_ID}.json").write_text("{}")
        (dist / "link-outside").symlink_to(self.outside)

    def files(self) -> dict[str, bytes]:
        return {str(p.relative_to(self.logs)): p.read_bytes()
                for p in self.logs.rglob("*") if p.is_file() and not p.is_symlink()}

    def test_ids_are_replaced_and_everything_else_that_could_hide_them_is_removed(self) -> None:
        report = redact_logs.redact_tree(self.logs, {"<ASC_KEY_ID>": KEY_ID, "<ASC_ISSUER_ID>": ISSUER_ID})
        files = self.files()
        self.assertEqual(
            files["archive.log"].decode(),
            "-authenticationKeyID <ASC_KEY_ID> -authenticationKeyIssuerID <ASC_ISSUER_ID>\n"
            "AuthKey_<ASC_KEY_ID>.p8 issuer <ASC_ISSUER_ID>\n")
        self.assertIn("QuitAll.xcdistributionlogs/IDEDistribution.standard.log", files)
        self.assertIn("QuitAll.xcdistributionlogs/AuthKey_ASC_KEY_ID.json", files, "names are redacted too")
        self.assertEqual(len(files), 3, sorted(files))
        for name, data in files.items():
            for secret in (KEY_ID, ISSUER_ID):
                for encoding in ("utf-8", "utf-16-le", "utf-16-be"):
                    self.assertNotIn(secret.lower().encode(encoding), data.lower(), name)
        self.assertFalse((self.logs / "QuitAll.xcdistributionlogs" / "link-outside").exists())
        self.assertEqual(self.outside.read_text(), f"kept {KEY_ID}", "files outside the logs are untouched")
        self.assertEqual(len(report["removed"]), 3)

    def test_without_ids_only_non_text_files_are_removed(self) -> None:
        redact_logs.redact_tree(self.logs, {})
        self.assertEqual(sorted(self.files()), [
            f"QuitAll.xcdistributionlogs/AuthKey_{KEY_ID}.json",
            "QuitAll.xcdistributionlogs/IDEDistribution.standard.log",
            "archive.log",
        ])

    def test_command_reads_the_ids_from_the_environment(self) -> None:
        env = {**os.environ, "ASC_KEY_ID": KEY_ID, "ASC_ISSUER_ID": ISSUER_ID}
        result = subprocess.run([sys.executable, str(ROOT / "scripts" / "store" / "redact_logs.py"), str(self.logs)],
                                capture_output=True, text=True, env=env)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn(KEY_ID, result.stdout)
        self.assertNotIn(KEY_ID.encode(), b"".join(self.files().values()))
        missing = subprocess.run([sys.executable, str(ROOT / "scripts" / "store" / "redact_logs.py"),
                                  str(self.logs / "none")], capture_output=True, text=True, env=env)
        self.assertEqual(missing.returncode, 0, missing.stderr)


if __name__ == "__main__":
    unittest.main()
