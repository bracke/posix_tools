# du

## Name
`du` - estimate file space usage.

## Synopsis
`du [-a] [-s] [-k] [file...]`

## Description
Writes rounded usage counts for files and directories. With no file operands, `du` reports the current directory.

## Operands
`file`: file or directory path to measure.

## Options
`-a`: include non-directory entries encountered during traversal.

`-s`: write only a summary line for each operand.

`-k`: use 1024-byte units instead of the default 512-byte units.

Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
Each result line contains the rounded unit count, a tab, the pathname, and a newline.

## Standard Error
Diagnostics for invalid options and paths that cannot be inspected.

## Exit Status
`0` success, `1` one or more operands could not be inspected or output failed, `2` invalid usage,
`125` internal failure.

## Behavioral Details
Directories are traversed recursively. The V1 implementation uses host-reported file byte sizes rounded to the selected
unit size; it does not yet use a separate allocated-block count when a platform exposes one.

## Locale Behavior
Help and diagnostics are localized. Numeric counts and pathnames are command data and are not localized.

## Implementation-Defined Choices
Default units are 512 bytes. `-k` selects 1024-byte units. Directory entry traversal order follows the host adapter.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`du -s .`

`du -ak src`

## Conformance Status
Conforming with implementation-defined behavior tracked by `DU-POSIX-001`.

## Known Limitations
Allocated block accounting and filesystem-cycle detection are not yet implemented.
