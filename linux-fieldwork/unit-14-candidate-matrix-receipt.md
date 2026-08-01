# Unit 14 exact-candidate matrix receipt

Result: PASS
Candidate branch: `linux-fieldwork/unit-14-make-mirror-update-cache-source`
Candidate head: `c94132e344f97cee95901623552df6bcde5039bb`
Candidate source blob: `7d92a29a05ade7f5da397a1a9d03e601092f9465`
Runner: `ubuntu-latest`
Cases: 10 candidate-facing lifecycle tests

The adapter executed worker ownership, INT/QUIT/TERM status and rerun, cleanup failure, cleanup-time signal retention, later-signal suppression, precedence, state removal, and immediate rerun cases against the exact candidate source file.

## Output

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
Ran 10 tests in 3.464s

OK
```
