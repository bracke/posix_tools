# whoami

## Name
`whoami` - write effective user name.

## Synopsis
`whoami`

## Description
Writes the effective user name for the current process.

## Operands
No operands are accepted.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
The user name followed by a newline.

## Standard Error
Diagnostics for invalid usage or unsupported identity queries.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The current user identifier and name are obtained through hostkit-backed adapters.

## Locale Behavior
Help and diagnostics are localized; the user name is not localized.

## Implementation-Defined Choices
Platforms that cannot report the current user produce an operational failure.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`whoami`

## Conformance Status
Conforming with extensions tracked by `WHOAMI-POSIX-001`.

## Known Limitations
None for the V1 supported surface.
