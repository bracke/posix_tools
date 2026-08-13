# rmdir

## Name
`rmdir` - remove empty directories.

## Synopsis
`rmdir [-p] [--] directory...`

## Description
Removes each named empty directory.

## Operands
`directory`: directory path to remove.

## Options
`-p` also removes empty parent directories named in the operand path. Options are recognized before the first directory
operand; later option-like words are directory operands. The end-of-options marker `--` is accepted. Project extensions `--help`, `--version`,
and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
No data output on success.

## Standard Error
Diagnostics for invalid usage and removal failures. With `-p`, a parent-cleanup failure names the parent component that
could not be removed.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Each operand is attempted in order. With `-p`, empty child components already
removed remain removed when cleanup later stops at a non-empty or otherwise
unremovable parent; the diagnostic names the parent component that failed.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Parent cleanup stops when a parent is not empty, cannot be removed, or no further named parent is present. Native host
errors are rendered through the project portable diagnostic categories.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`rmdir empty-dir`

## Conformance Status
Conforming with extensions tracked by `RMDIR-POSIX-001`.

## Known Limitations
None for the V1 supported surface.
