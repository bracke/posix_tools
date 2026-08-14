# logname

## Name
`logname` - write the user's login name.

## Synopsis
`logname`

## Description
Writes the login name from the command environment.

## Operands
No operands are accepted.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
The login name followed by a newline.

## Standard Error
Diagnostics for invalid usage or unavailable login name.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
V1 reads `LOGNAME` from the command context environment.

## Locale Behavior
Help and diagnostics are localized; the login name is not localized.

## Implementation-Defined Choices
An empty or absent `LOGNAME` is an operational failure.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`logname`

## Conformance Status
Conforming with extensions tracked by `LOGNAME-POSIX-001`.

## Known Limitations
No system login database fallback is implemented in this pass.
