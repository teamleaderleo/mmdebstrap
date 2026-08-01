# Unit 14 canonical upstream sync receipt

Result: PASS
Canonical upstream: `https://gitlab.mister-muffin.de/josch/mmdebstrap.git`
Canonical branch: `main`
Exact upstream head: `77ec9be5417ee44c96343d2347145585da1b1f94`
Exact base source blob: `6c4be092edcf23b56b63a3befe238c099c45f590`
Controlled snapshot branch: `linux-fieldwork/upstream-main-snapshot`
Candidate branch: `linux-fieldwork/unit-14-make-mirror-update-cache-upstream-main`
Candidate head: `b2a9a09b36fd13f22a024ebf8522ac58543eac28`
Candidate source blob: `7d92a29a05ade7f5da397a1a9d03e601092f9465`
Patch SHA-256: `980720d262d0f5d4a568be54851e144652ae6d882a8ad0e8aa228c8ffed2ae42`
Runner: `ubuntu-latest`
Dynamic cases: 10 candidate-facing lifecycle tests

The job cloned current canonical Forgejo `main`, preserved its real history on the controlled snapshot branch, required the expected `make_mirror.sh` blob, applied the composed patch with zero fuzz, passed shell syntax and diff checks, enforced worker/proxy ownership assertions, ran the exact-candidate lifecycle matrix, and published a one-commit candidate atop canonical upstream history.

## Matrix output

```text
test_candidate_term_propagates_and_rerun_succeeds (tests.test_make_mirror_update_cache_signal_ownership.MakeMirrorUpdateCacheSignalOwnershipTest.test_candidate_term_propagates_and_rerun_succeeds) ... ok
test_candidate_preserves_ordinary_failure_and_signal_over_cleanup (tests.test_make_mirror_update_cache_signal_ownership.MakeMirrorUpdateCacheSignalOwnershipTest.test_candidate_preserves_ordinary_failure_and_signal_over_cleanup) ... ok
test_int_quit_term_status_cleanup_proxy_and_rerun (tests.test_make_mirror_update_cache_signal_matrix.MakeMirrorUpdateCacheSignalMatrixTest.test_int_quit_term_status_cleanup_proxy_and_rerun) ... ok
test_successful_work_reports_cleanup_failure_once_and_reruns (tests.test_make_mirror_update_cache_cleanup_failure.MakeMirrorUpdateCacheCleanupFailureTest.test_successful_work_reports_cleanup_failure_once_and_reruns) ... ok
test_repair_retains_explicit_term_and_completes_cleanup (tests.test_make_mirror_update_cache_cleanup_signals.MakeMirrorUpdateCacheCleanupSignalsTest.test_repair_retains_explicit_term_and_completes_cleanup) ... ok
test_repair_records_first_signal_during_ordinary_cleanup (tests.test_make_mirror_update_cache_cleanup_signals.MakeMirrorUpdateCacheCleanupSignalsTest.test_repair_records_first_signal_during_ordinary_cleanup) ... ok
test_repair_precedence_and_source_contract (tests.test_make_mirror_update_cache_cleanup_signals.MakeMirrorUpdateCacheCleanupSignalsTest.test_repair_precedence_and_source_contract) ... ok
test_cleanup_time_signal_allows_immediate_clean_rerun (tests.test_make_mirror_update_cache_cleanup_signals_rerun.MakeMirrorUpdateCacheCleanupSignalsRerunTest.test_cleanup_time_signal_allows_immediate_clean_rerun) ... ok
test_explicit_signal_remains_ahead_of_cleanup_failure (tests.test_make_mirror_update_cache_cleanup_signals_rerun.MakeMirrorUpdateCacheCleanupSignalsRerunTest.test_explicit_signal_remains_ahead_of_cleanup_failure) ... ok
test_unsignaled_cleanup_failure_remains_authoritative (tests.test_make_mirror_update_cache_cleanup_signals_rerun.MakeMirrorUpdateCacheCleanupSignalsRerunTest.test_unsignaled_cleanup_failure_remains_authoritative) ... ok

----------------------------------------------------------------------
Ran 10 tests in 3.459s

OK
```
