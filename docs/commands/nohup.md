# nohup

## Name
nohup - invoke a utility immune to hangups where supported

## Synopsis
nohup utility [argument...]

## Description
`nohup` invokes a utility after requesting that hangup signals be ignored where the host supports that operation.

## Operands
`utility` names the program to execute. Remaining operands are passed as arguments.

## Options
`--help` and `--version` are project extensions.

## Standard Input
Inherited by the invoked utility.

## Standard Output
Inherited by the invoked utility in V1.

## Standard Error
Localized diagnostics are written when the utility cannot be invoked.

## Exit Status
The invoked utility status is returned when available. 126 means the utility could not be invoked, 127 means it was
not found, 2 means invalid usage, and 125 means internal failure.

## Behavioral Details
Signal disposition handling is delegated to the host signal adapter.

## Locale Behavior
Help and diagnostics are locale-dependent. Utility output is not localized by `nohup`.

## Implementation-Defined Choices
V1 does not create `nohup.out`; output redirection remains the caller's responsibility.

## Extensions
`--help`, `--version`, and `--posix-tools-identify`.

## Examples
`nohup true`

## Conformance Status
Conforming with extensions.

## Known Limitations
Full POSIX `nohup.out` redirection is not implemented in V1.
