#!/usr/bin/env python3
from __future__ import annotations

import os
import pathlib
import subprocess
import sys
import unittest

SOURCE = pathlib.Path(os.environ["UNIT14_SOURCE"]).resolve()
LF_REPO = pathlib.Path(os.environ["LINUX_FIELDWORK_REPO"]).resolve()

sys.path.insert(0, str(LF_REPO))

from tests import test_make_mirror_update_cache_cleanup_failure as cleanup_failure  # noqa: E402
from tests import test_make_mirror_update_cache_cleanup_signals as cleanup_signals  # noqa: E402
from tests import test_make_mirror_update_cache_cleanup_signals_rerun as cleanup_rerun  # noqa: E402
from tests import test_make_mirror_update_cache_signal_matrix as signal_matrix  # noqa: E402
from tests import test_make_mirror_update_cache_signal_ownership as ownership  # noqa: E402


def candidate_text() -> str:
    checked = subprocess.run(
        ["/bin/sh", "-n", str(SOURCE)],
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=30,
    )
    if checked.returncode != 0:
        raise AssertionError(checked.stdout + checked.stderr)
    return SOURCE.read_text(encoding="utf-8")


def direct_prepare(self: unittest.TestCase, _root: pathlib.Path) -> str:
    return candidate_text()


def cleanup_direct_prepare(
    self: unittest.TestCase,
    _root: pathlib.Path,
    *,
    include_repair: bool,
) -> str:
    if not include_repair:
        raise AssertionError("predecessor case excluded from exact-candidate matrix")
    return candidate_text()


def final_functions(helper: object, source: str) -> str:
    initialization = "  update_cache_cleanup_signal_status=0\n"
    if source.count(initialization) != 1:
        raise AssertionError("candidate cleanup-signal initialization changed")
    blocks = [
        initialization.rstrip("\n"),
        helper.extract_nested_function(source, "record_update_cache_cleanup_signal"),
        helper.extract_nested_function(source, "update_cache_finish"),
        helper.extract_nested_function(source, "update_cache_exit_cleanup"),
        helper.extract_nested_function(source, "update_cache_signal_exit"),
    ]
    return "\n".join(blocks)


def final_candidate_blocks(self: object, source: str) -> tuple[str, str]:
    traps = (
        "  trap 'update_cache_exit_cleanup' EXIT\n"
        "  trap 'update_cache_signal_exit 130' INT\n"
        "  trap 'update_cache_signal_exit 131' QUIT\n"
        "  trap 'update_cache_signal_exit 143' TERM\n"
    )
    for line in traps.splitlines(keepends=True):
        if source.count(line) != 1:
            raise AssertionError(f"candidate trap changed: {line.rstrip()}")
    return final_functions(self, source), traps


ownership.MakeMirrorUpdateCacheSignalOwnershipTest.prepare_candidate = direct_prepare
ownership.MakeMirrorUpdateCacheSignalOwnershipTest.candidate_blocks = final_candidate_blocks
cleanup_failure.MakeMirrorUpdateCacheCleanupFailureTest.prepare_candidate = direct_prepare
cleanup_failure.MakeMirrorUpdateCacheCleanupFailureTest.candidate_functions = final_functions
cleanup_signals.MakeMirrorUpdateCacheCleanupSignalsTest.prepare_candidate = cleanup_direct_prepare


def load_case(
    suite: unittest.TestSuite,
    case: type[unittest.TestCase],
    names: tuple[str, ...],
) -> None:
    for name in names:
        suite.addTest(case(name))


suite = unittest.TestSuite()
load_case(
    suite,
    ownership.MakeMirrorUpdateCacheSignalOwnershipTest,
    (
        "test_candidate_term_propagates_and_rerun_succeeds",
        "test_candidate_preserves_ordinary_failure_and_signal_over_cleanup",
    ),
)
load_case(
    suite,
    signal_matrix.MakeMirrorUpdateCacheSignalMatrixTest,
    ("test_int_quit_term_status_cleanup_proxy_and_rerun",),
)
load_case(
    suite,
    cleanup_failure.MakeMirrorUpdateCacheCleanupFailureTest,
    ("test_successful_work_reports_cleanup_failure_once_and_reruns",),
)
load_case(
    suite,
    cleanup_signals.MakeMirrorUpdateCacheCleanupSignalsTest,
    (
        "test_repair_retains_explicit_term_and_completes_cleanup",
        "test_repair_records_first_signal_during_ordinary_cleanup",
        "test_repair_precedence_and_source_contract",
    ),
)
load_case(
    suite,
    cleanup_rerun.MakeMirrorUpdateCacheCleanupSignalsRerunTest,
    (
        "test_cleanup_time_signal_allows_immediate_clean_rerun",
        "test_explicit_signal_remains_ahead_of_cleanup_failure",
        "test_unsignaled_cleanup_failure_remains_authoritative",
    ),
)

result = unittest.TextTestRunner(verbosity=2).run(suite)
if not result.wasSuccessful():
    raise SystemExit(1)
