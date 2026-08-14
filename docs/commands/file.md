# file

## Name
`file` - determine file type.

## Synopsis
`file [--] file...`

## Description
Classifies file operands using filesystem type information and bounded content inspection.

## Operands
`file`: path to classify.

## Options
No POSIX options are implemented in V1. `--` ends option processing.
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized before operands.

## Standard Input
Not used in V1.

## Standard Output
One classification line per readable operand in the form `path: type`.

## Standard Error
Diagnostics are written for invalid usage and operands that cannot be opened or read.

## Exit Status
`0` all operands were classified, `1` at least one operand failed or output failed, `2` invalid usage, `125` internal
failure.

## Behavioral Details
V1 reports `directory`, `special file`, `empty`, `text`, or `data`. Text means all inspected bytes are printable ASCII or
common ASCII whitespace. A NUL byte or another non-text byte makes the regular file `data`.

## Locale Behavior
Help and diagnostics are localized. Classification words and pathnames are command data and are not localized.

## Implementation-Defined Choices
Magic databases and locale-sensitive text classification are not used in V1. Classification is intentionally
deterministic and bounded.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`file README.md`

## Conformance Status
Conforming with implementation-defined behavior tracked by `FILE-POSIX-001`.

## Known Limitations
V1 does not implement magic-file rules, MIME output, archive inspection, or standard-input classification.
