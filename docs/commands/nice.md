# nice

## Name
nice - invoke a utility with adjusted scheduling priority

## Synopsis
nice [-n increment] utility [argument...]

## Description
`nice` invokes a utility and returns its exit status.

## Operands
`utility` names the program to execute. Remaining operands are passed as arguments.

## Options
`-n increment` parses the requested priority adjustment. `--help` and `--version` are project extensions.

## Standard Input
Inherited by the invoked utility.

## Standard Output
Inherited output from the invoked utility.

## Standard Error
Localized diagnostics are written when the utility cannot be invoked.

## Exit Status
The invoked utility status is returned when available. 126 means the utility could not be invoked, 127 means it was
not found, 2 means invalid usage, and 125 means internal failure.

## Behavioral Details
V1 validates the requested adjustment and delegates execution to the process adapter.

## Locale Behavior
Help and diagnostics are locale-dependent. Utility output is not localized by `nice`.

## Implementation-Defined Choices
Priority adjustment application is host-adapter dependent.

## Extensions
`--help`, `--version`, and `--posix-tools-identify`.

## Examples
`nice -n 5 true`

## Conformance Status
Conforming with extensions.

## Known Limitations
Some platforms may execute the utility without changing scheduling priority.
