# Codex Restart State

Date: 2026-08-14
Repository: `/home/bent/Projekte/Ada/posix_tools`
Branch: `main`
Remote: `origin https://github.com/bracke/posix_tools.git`

## Latest Validated State

- `../hostkit/check_hostkit/bin/check_hostkit` passed after adding host login-name support.
- `alr build` passed in `tests/`.
- `./bin/posix_tools_tests test --suite commands` passed: 81/81.
- `./bin/posix_tools_tests check` passed: 155/155.
- `./bin/posix_tools_tests release-check` passed with network access.

## Current Implementation Scope

- Expanded compiled command inventory includes:
  `basename cat chgrp chmod chown cksum cmp comm cp cut date dd dirname echo env false find head id kill link ln logname ls mkdir mv od paste printf pwd readlink realpath rm rmdir sleep split sort tail tee test touch tr true uname uniq wc whoami xargs`
- `awk`, `grep`, and `sed` remain intentionally excluded from this repository because they are sibling projects.
- Added or completed shared implementations, command subcrates, documentation, generated manpages, conformance metadata, package manifests, checksums, and command tests for the expanded inventory.
- `date` now uses sibling `../i18n` timezone support where available.
- `posix_tools_common` uses sibling `../messages` for locale support.

## Latest Hostkit Work

- Added `Hostkit.Host.Login_Name`.
- Linux and macOS implementations use `getlogin_r`.
- Windows implementation uses `GetUserNameA`.
- Unsupported implementation returns an empty string.
- Hostkit syntax and binding checks now cover the login-name bindings.
- Hostkit tests validate sanitized login-name behavior.

## Latest Posix Tools Work

- Added host adapter forwarding for `Login_Name`.
- `logname` now resolves login name by fallback order:
  1. nonempty `LOGNAME`;
  2. host login-name API;
  3. current user ID mapped through filesystem user lookup;
  4. operational failure.
- `uname` platform support was improved through hostkit release/version APIs.
- Documentation and generated metadata were refreshed for `logname`, `uname`, and the expanded command inventory.

## Remaining Gap Surface

- The generated requirements registry currently has no active `Known deviation`, `Partially conforming`, or
  `Not yet assessed` rows.
- All compiled command inventory rows are marked `conforming_with_extensions`.
- The remaining conformance gap is depth: the expanded commands need more exhaustive black-box interoperability,
  property, stress, and platform fixture coverage before their `conforming_with_extensions` labels should be
  treated as final POSIX-grade claims.
- `TAIL-FOLLOW-001` is implemented and tracked as `Conforming with extensions`: `-f` follows appended data after
  the initial suffix, while `-F` and `--follow` are project extensions.

## GitHub/Auth Notes

- Earlier `gh auth status` reported one active `bracke` token as invalid.
- Normal Git credentials worked for GitHub push when network access was available.
