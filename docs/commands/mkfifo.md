# mkfifo

## Name
mkfifo - make FIFO special files

## Synopsis
mkfifo [-m mode] file...

## Description
`mkfifo` creates one FIFO special file for each operand.

## Operands
`file` names the FIFO to create.

## Options
`-m mode` sets octal permission bits for the created FIFO. `--help` and `--version` are project extensions.

## Standard Input
Not used.

## Standard Output
No output is written for successful creation.

## Standard Error
Localized diagnostics are written for invalid usage and creation failures.

## Exit Status
0 on success, 1 for operational failure, 2 for invalid usage, and 125 for internal failure.

## Behavioral Details
Creation is delegated to the host filesystem adapter.

## Locale Behavior
Help and diagnostics are locale-dependent. Pathnames are not localized.

## Implementation-Defined Choices
Only octal modes are accepted in V1.

## Extensions
`--help`, `--version`, and `--posix-tools-identify`.

## Examples
`mkfifo queue`

## Conformance Status
Conforming with extensions.

## Known Limitations
FIFO creation depends on host platform support.
