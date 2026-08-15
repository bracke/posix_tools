# cmp

## Name
`cmp` - compare two files.

## Synopsis
`cmp [-l|-s] [--] file1 file2`

## Description
Compares two byte streams and reports whether they differ.

## Operands
`file1`, `file2`: input paths. `-` reads standard input.

## Options
`-l` lists each differing byte number and byte values in octal. `-s` suppresses ordinary difference output. Project
extensions `--help`, `--version`, and `--posix-tools-identify` are recognized. The end-of-options marker `--` is
accepted.

## Standard Input
Used for an operand exactly equal to `-`.

## Standard Output
In default mode, the first byte and line difference is reported. With `-l`, all differing byte positions before EOF are
listed. Equal files produce no output.

## Standard Error
Diagnostics for invalid usage and input failures.

## Exit Status
`0` files are equal, `1` files differ or an operational failure occurred, `2` invalid usage, `125` internal failure.

## Behavioral Details
Comparison is byte-oriented. LF bytes update the reported line number.
The command treats `--` as the end of options. Option-like filenames are accepted after `--`.

## Locale Behavior
Comparison and data output are not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
EOF differences use a concise project diagnostic shape.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`cmp old.bin new.bin`
`cmp -l old.bin new.bin`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `CMP-POSIX-001` and `CMP-POSIX-002`.

## Known Limitations
None for the implemented V1 supported surface.
