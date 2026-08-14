# pathchk

## Name
`pathchk` - check pathnames.

## Synopsis
`pathchk [-p] pathname...`

## Description
Checks pathname operands using lexical path and component limits. With `-p`, checks portable pathname limits and the
portable filename character set.

## Operands
`pathname`: pathname to check.

## Options
`-p`: check portable pathname limits and portable filename characters.
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized before operands.

## Standard Input
Not used.

## Standard Output
No output is written for valid pathnames.

## Standard Error
Diagnostics are written for invalid pathnames and invalid usage.

## Exit Status
`0` all pathnames are valid, `1` at least one pathname is invalid, `2` invalid usage, `125` internal failure.

## Behavioral Details
Pathnames are checked lexically. A slash separates path components. Repeated slashes do not create empty components for
component-length checks. The default V1 path limit is 4096 bytes and the default component limit is 255 bytes. Portable
mode uses a 256-byte pathname limit, a 14-byte component limit, and permits only ASCII letters, digits, period,
underscore, and hyphen in components.

## Locale Behavior
Help and diagnostics are localized. Pathname bytes are not localized.

## Implementation-Defined Choices
V1 uses project-defined lexical limits instead of querying per-directory `pathconf` values.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`pathchk -p portable/name`

## Conformance Status
Conforming with implementation-defined behavior tracked by `PATHCHK-POSIX-001`.

## Known Limitations
Per-filesystem path and name limits are not queried in V1.
