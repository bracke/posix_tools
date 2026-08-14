# chown

## Name
`chown` - change file owner and group.

## Synopsis
`chown [-R] [--] owner[:group] file...`

## Description
Changes the owner and optionally the group of each named file.

## Operands
`owner[:group]`: owner name or numeric identifier with optional group. `file`: file or directory path.

## Options
`-R` applies the change recursively to directory operands. `--` ends option recognition. Project extensions `--help`,
`--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
No data output on success.

## Standard Error
Diagnostics for invalid usage and ownership failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Names and numeric identifiers are resolved through hostkit metadata services.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
The V1 owner/group separator is colon.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`chown root:staff file`

## Conformance Status
Conforming with extensions tracked by `CHOWN-POSIX-001`.

## Known Limitations
Symbolic-link traversal details follow the hostkit file-system adapter.
