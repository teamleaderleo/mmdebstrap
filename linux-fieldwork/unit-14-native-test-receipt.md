# Unit 14 upstream-native regression receipt

Result: PASS
Candidate branch: `linux-fieldwork/unit-14-make-mirror-update-cache-upstream-main`
Candidate head: `76728bbb8e084b54261713ba80762cd6f6ada79a`
Registered test: `tests/make-mirror-update-cache-worker-lifecycle`
Test metadata: `coverage.txt`
Runner: `ubuntu-latest`

The native shell regression passed `sh -n`, shellcheck, upstream shfmt options, direct execution, and `git diff --check`. It extracted the actual candidate finalizer and handlers from `make_mirror.sh`, then exercised cleanup-time INT/QUIT/TERM, later-signal suppression, explicit-signal precedence, host-failure precedence, cleanup-failure precedence, state removal, and a clean rerun.

## Output

```text
make_mirror update_cache worker lifecycle: PASS
```
