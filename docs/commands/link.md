# link

## Name
`link` - call the link function.

## Synopsis
`link [--] source target`

## Description
Creates a hard link named by `target` for `source`.

## Operands
`source`: existing path. `target`: link path to create.

## Options
`--` ends option recognition. Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Not used.

## Standard Output
No data output on success.

## Standard Error
Diagnostics for invalid usage and link failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The command delegates hard-link creation to hostkit.

## Locale Behavior
Help and diagnostics are localized.

## Implementation-Defined Choices
Host file-system restrictions are reported as operational failures.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`link source target`

## Conformance Status
Conforming with extensions tracked by `LINK-POSIX-001`.

## Known Limitations
Hard links may be unavailable on some file systems.
