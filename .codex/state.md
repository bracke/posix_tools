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
  `basename cat chmod cksum cmp comm cp cut date dd dirname echo env false find head id ln logname ls mkdir mv od paste printf pwd rm rmdir sort split tail tee test touch tr true uname uniq wc xargs`
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

## Known Deviation Surface

The release gate passes with documented known-deviation records for deliberately incomplete POSIX areas in expanded utilities:

- `TAIL-FOLLOW-001`
- `CP-V1-DEVIATION-001`
- `DATE-V1-DEVIATION-001`
- `DD-V1-DEVIATION-001`
- `FIND-V1-DEVIATION-001`
- `SORT-V1-DEVIATION-001`
- `TEST-V1-DEVIATION-001`
- `TOUCH-V1-DEVIATION-001`
- `TR-V1-DEVIATION-001`

## GitHub/Auth Notes

- Earlier `gh auth status` reported one active `bracke` token as invalid.
- Normal Git credentials worked for GitHub push when network access was available.
