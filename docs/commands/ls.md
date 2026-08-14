# ls

## Name
`ls` - list directory contents.

## Synopsis
`ls [-1aAd] [--] [file...]`

## Description
Lists file operands and directory entries.

## Operands
`file`: file or directory path.

## Options
`-1` writes one entry per line. `-a` includes dot-prefixed entries. `-A` includes dot-prefixed entries other than `.` and
`..` when the host reports them. `-d` lists directory operands as operands instead of listing their contents. Project
extensions `--help`, `--version`, and `--posix-tools-identify` are recognized. The end-of-options marker `--` is
accepted.

## Standard Input
Not used.

## Standard Output
Listed names, one per line.

## Standard Error
Diagnostics for invalid usage and filesystem failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Directory entries are sorted deterministically before output.

## Locale Behavior
Data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
The V1 output format is the deterministic one-entry-per-line form.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`ls -a src`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `LS-POSIX-001`.

## Known Limitations
None for the implemented V1 supported surface.
