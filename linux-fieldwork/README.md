# Linux Fieldwork unit 14 carrier

Branch: `linux-fieldwork/unit-14-make-mirror-update-cache`

This branch preserves the repository's downstream `master` history and carries the upstream-facing unit 14 patch separately.

The relevant base file is already byte-identical to canonical mmdebstrap `main`:

- `make_mirror.sh` Git blob: `6c4be092edcf23b56b63a3befe238c099c45f590`
- canonical upstream commit checked by Linux Fieldwork: `77ec9be5417ee44c96343d2347145585da1b1f94`

Run from the repository root:

```sh
sh linux-fieldwork/apply-unit-14.sh --check
sh linux-fieldwork/apply-unit-14.sh --apply
```

The script refuses an unexpected base or patch digest, requires zero-fuzz application, runs `/bin/sh -n`, checks the diff, and verifies that `update_cache()` no longer references the parent-owned proxy PID.

External upstream contact remains unauthorized. This controlled-fork branch is an internal candidate carrier only.
