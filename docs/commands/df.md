# df

## Name
df - report filesystem space

## Synopsis
df [file...]

## Description
`df` writes one line of filesystem capacity information for each operand, or for the current directory when no
operand is supplied. Counts are reported in 512-byte units.

## Operands
`file` names a path located on the filesystem to inspect.

## Options
`--help` and `--version` are project extensions.

## Standard Input
Not used.

## Standard Output
A header followed by filesystem, total, used, and available block counts.

## Standard Error
Localized diagnostics are written for paths whose filesystem capacity cannot be determined.

## Exit Status
0 on success, 1 for operational failure, 2 for invalid usage, and 125 for internal failure.

## Behavioral Details
The implementation asks the host adapter for capacity of the filesystem containing each operand.

## Locale Behavior
Help and diagnostics are locale-dependent. Capacity data is not localized.

## Implementation-Defined Choices
The V1 output uses a compact project format with 512-byte blocks.

## Extensions
`--help`, `--version`, and `--posix-tools-identify`.

## Examples
`df .`

## Conformance Status
Conforming with extensions.

## Known Limitations
Capacity precision depends on the host adapter and underlying platform APIs.
