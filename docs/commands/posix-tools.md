# posix-tools

## Name
`posix-tools` - inspect the project command suite.

## Synopsis
`posix-tools help [command]`

`posix-tools version`

`posix-tools list`

`posix-tools paths`

`posix-tools verify`

## Description
Provides project management and inspection operations. It does not dispatch
POSIX utilities and is outside POSIX conformance claims.

## Operands
Subcommand-specific operands only.

## Options
`--help`, `--version`, and `--posix-tools-identify` are recognized by the common
wrapper.

## Standard Input
Not used for normal operations.

## Standard Output
Human-readable inventory, help, version, path, or verification output.

## Standard Error
Diagnostics for invalid subcommands or operational failures.

## Exit Status
`0` success, `2` invalid usage, `125` internal failure.

## Behavioral Details
`verify` invokes candidate executables without a shell and checks the internal
identity output. If a valid command next to the running `posix-tools` executable
is hidden by a different PATH candidate, the command is reported as `shadowed`.

## Locale Behavior
Human-oriented management headings, verification status labels, and diagnostics
are localized through project message adapters. Command names, paths, and
machine-oriented identity output are not localized.

## Implementation-Defined Choices
Verification timeout is bounded and conservative.

## Extensions
All behavior is a project extension outside POSIX utility claims.

## Examples
`posix-tools verify`

## Conformance Status
Conforming with project extensions; not a POSIX utility.

## Known Limitations
Verification remains intentionally observational: it classifies the installed
suite but does not repair PATH, install commands, or replace system utilities.
