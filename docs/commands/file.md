# file

## Name
`file` - determine file type.

## Synopsis
`file [-i] [-m magicfile] [--] file...`

## Description
Classifies file operands using filesystem type information, built-in content signatures, and bounded content inspection.

## Operands
`file`: path to classify, or `-` for standard input.

## Options
`-i`, `--mime`, `--mime-type`: write deterministic MIME-style classification names.

`-m magicfile`: read additional project magic rules before the built-in signatures. Each non-comment rule has the form
`offset:literal:description[:mime-type]`. The literal supports `\0`, `\n`, `\r`, `\t`, `\\`, `\:`, and `\xHH` byte
escapes. Rules are tried in file order.

`--` ends option processing.
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized before operands.

## Standard Input
Read when an operand is exactly `-`.

## Standard Output
One classification line per readable operand in the form `path: type`.

## Standard Error
Diagnostics are written for invalid usage and operands that cannot be opened or read.

## Exit Status
`0` all operands were classified, `1` at least one operand failed or output failed, `2` invalid usage, `125` internal
failure.

## Behavioral Details
V1 recognizes external project magic rules, then built-in signatures for PDF, ELF, PNG, GIF, ZIP, gzip, tar, and shebang
scripts before falling back to `directory`, `special file`, `empty`, `text`, or `data`. Text means all inspected bytes
are printable ASCII or common ASCII whitespace. A NUL byte or another non-text byte makes the regular file `data`.

## Locale Behavior
Help and diagnostics are localized. Classification words and pathnames are command data and are not localized.

## Implementation-Defined Choices
The `-m` format is a deterministic project rule format, not a clone of any host-specific magic database syntax.
Locale-sensitive text classification is not used in V1.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`file README.md`

## Conformance Status
Conforming with implementation-defined behavior tracked by `FILE-POSIX-001`.

## Known Limitations
No known V1 limitation for the documented rule format.
