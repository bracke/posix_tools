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
Inherited by the invoked utility when standard output is not a terminal. When standard output is a terminal, the
utility's standard output is appended to `nohup.out`.

## Standard Error
Localized diagnostics are written when the utility cannot be invoked. When standard error is a terminal, the invoked
utility's standard error is redirected away from the terminal: to `nohup.out` when standard output is also redirected,
otherwise to the inherited standard output.

## Exit Status
The invoked utility status is returned when available. 126 means the utility could not be invoked, 127 means it was
not found, 2 means invalid usage, and 125 means internal failure.

## Behavioral Details
Signal disposition handling is delegated to the host signal adapter. Terminal output redirection is performed through
the host process adapter without invoking a shell.

## Locale Behavior
Help and diagnostics are locale-dependent. Utility output is not localized by `nohup`.

## Implementation-Defined Choices
`nohup.out` is opened in append mode in the current working directory when terminal standard output needs redirection.

## Extensions
`--help`, `--version`, and `--posix-tools-identify`.

## Examples
`nohup true`

## Conformance Status
Conforming with extensions.

## Known Limitations
No known V1 limitation for the documented `nohup.out` redirection surface beyond host process and filesystem
capability limits.
