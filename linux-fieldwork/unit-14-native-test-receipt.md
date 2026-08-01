# Unit 14 upstream-native regression receipt

Result: FAIL
Exit status: `1`
Candidate branch: `linux-fieldwork/unit-14-make-mirror-update-cache-upstream-main`
Candidate head after run: `76728bbb8e084b54261713ba80762cd6f6ada79a`
Registered test: `tests/make-mirror-update-cache-worker-lifecycle`
Test metadata: `coverage.txt`
Runner: `ubuntu-latest`

The classified gate attempted test registration, `sh -n`, shellcheck, upstream shfmt options, direct lifecycle execution, diff hygiene, and candidate publication. A PASS means every step completed and the test commit was pushed. A FAIL transcript identifies the first command owner.

## Output

```text
Cloning into '/tmp/mmdebstrap-candidate'...
Get:1 file:/etc/apt/apt-mirrors.txt Mirrorlist [144 B]
Hit:2 http://azure.archive.ubuntu.com/ubuntu noble InRelease
Hit:6 https://packages.microsoft.com/repos/azure-cli noble InRelease
Get:7 https://packages.microsoft.com/ubuntu/24.04/prod noble InRelease [3600 B]
Get:3 http://azure.archive.ubuntu.com/ubuntu noble-updates InRelease [126 kB]
Get:4 http://azure.archive.ubuntu.com/ubuntu noble-backports InRelease [126 kB]
Get:8 https://dl.google.com/linux/chrome-stable/deb stable InRelease [2548 B]
Get:5 http://azure.archive.ubuntu.com/ubuntu noble-security InRelease [126 kB]
Get:9 http://azure.archive.ubuntu.com/ubuntu noble-updates/main amd64 Packages [1154 kB]
Get:10 http://azure.archive.ubuntu.com/ubuntu noble-updates/main Translation-en [278 kB]
Get:11 http://azure.archive.ubuntu.com/ubuntu noble-updates/main amd64 Components [181 kB]
Get:12 http://azure.archive.ubuntu.com/ubuntu noble-updates/universe amd64 Packages [1680 kB]
Get:13 http://azure.archive.ubuntu.com/ubuntu noble-updates/universe Translation-en [334 kB]
Get:14 http://azure.archive.ubuntu.com/ubuntu noble-updates/universe amd64 Components [388 kB]
Get:15 http://azure.archive.ubuntu.com/ubuntu noble-updates/restricted amd64 Packages [1367 kB]
Get:16 http://azure.archive.ubuntu.com/ubuntu noble-updates/restricted Translation-en [308 kB]
Get:17 http://azure.archive.ubuntu.com/ubuntu noble-updates/multiverse amd64 Packages [45.4 kB]
Get:18 http://azure.archive.ubuntu.com/ubuntu noble-updates/multiverse Translation-en [12.3 kB]
Get:20 https://packages.microsoft.com/ubuntu/24.04/prod noble/main armhf Packages [11.7 kB]
Get:21 https://packages.microsoft.com/ubuntu/24.04/prod noble/main arm64 Packages [227 kB]
Get:22 https://packages.microsoft.com/ubuntu/24.04/prod noble/main amd64 Packages [261 kB]
Get:19 http://azure.archive.ubuntu.com/ubuntu noble-updates/multiverse amd64 Components [940 B]
Get:23 http://azure.archive.ubuntu.com/ubuntu noble-backports/main amd64 Components [5744 B]
Get:24 http://azure.archive.ubuntu.com/ubuntu noble-backports/universe amd64 Packages [32.5 kB]
Get:25 http://azure.archive.ubuntu.com/ubuntu noble-backports/universe amd64 Components [12.6 kB]
Get:26 http://azure.archive.ubuntu.com/ubuntu noble-security/main amd64 Packages [897 kB]
Get:36 https://dl.google.com/linux/chrome-stable/deb stable/main amd64 Packages [1411 B]
Get:27 http://azure.archive.ubuntu.com/ubuntu noble-security/main Translation-en [198 kB]
Get:28 http://azure.archive.ubuntu.com/ubuntu noble-security/main amd64 Components [46.4 kB]
Get:29 http://azure.archive.ubuntu.com/ubuntu noble-security/universe amd64 Packages [1199 kB]
Get:30 http://azure.archive.ubuntu.com/ubuntu noble-security/universe Translation-en [239 kB]
Get:31 http://azure.archive.ubuntu.com/ubuntu noble-security/universe amd64 Components [76.3 kB]
Get:32 http://azure.archive.ubuntu.com/ubuntu noble-security/restricted amd64 Packages [1273 kB]
Get:33 http://azure.archive.ubuntu.com/ubuntu noble-security/restricted Translation-en [290 kB]
Get:34 http://azure.archive.ubuntu.com/ubuntu noble-security/multiverse amd64 Packages [40.3 kB]
Get:35 http://azure.archive.ubuntu.com/ubuntu noble-security/multiverse Translation-en [10.6 kB]
Fetched 11.0 MB in 1s (10.4 MB/s)
Reading package lists...
Reading package lists...
Building dependency tree...
Reading state information...
shellcheck is already the newest version (0.9.0-1).
The following NEW packages will be installed:
  shfmt
0 upgraded, 1 newly installed, 0 to remove and 79 not upgraded.
Need to get 1131 kB of archives.
After this operation, 3038 kB of additional disk space will be used.
Get:1 file:/etc/apt/apt-mirrors.txt Mirrorlist [144 B]
Get:2 http://azure.archive.ubuntu.com/ubuntu noble/universe amd64 shfmt amd64 3.8.0-1 [1131 kB]
Fetched 1131 kB in 0s (8328 kB/s)
Selecting previously unselected package shfmt.
(Reading database ... (Reading database ... 5%(Reading database ... 10%(Reading database ... 15%(Reading database ... 20%(Reading database ... 25%(Reading database ... 30%(Reading database ... 35%(Reading database ... 40%(Reading database ... 45%(Reading database ... 50%(Reading database ... 55%(Reading database ... 60%(Reading database ... 65%(Reading database ... 70%(Reading database ... 75%(Reading database ... 80%(Reading database ... 85%(Reading database ... 90%(Reading database ... 95%(Reading database ... 100%(Reading database ... 202954 files and directories currently installed.)
Preparing to unpack .../shfmt_3.8.0-1_amd64.deb ...
Unpacking shfmt (3.8.0-1) ...
Setting up shfmt (3.8.0-1) ...
Processing triggers for man-db (2.12.0-4build2) ...
Not building database; man-db/auto-update is not 'true'.

Running kernel seems to be up-to-date.

No services need to be restarted.

No containers need to be restarted.

No user sessions are running outdated binaries.

No VM guests are running outdated hypervisor (qemu) binaries on this host.
make_mirror update_cache worker lifecycle: PASS
On branch linux-fieldwork/unit-14-make-mirror-update-cache-upstream-main
Your branch is up to date with 'origin/linux-fieldwork/unit-14-make-mirror-update-cache-upstream-main'.

nothing to commit, working tree clean
```
