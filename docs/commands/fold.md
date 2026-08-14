# fold

## Name
`fold` - fold long input lines.

## Synopsis
`fold [-bs] [-w width] [file...]`

## Description
Writes each input file to standard output with long lines folded to the selected width. With no file operands, or with
an operand exactly equal to `-`, `fold` reads standard input.

## Operands
`file`: input file to fold, or `-` for standard input.

## Options
`-b`: count bytes. This is the V1 counting policy and is accepted explicitly for POSIX compatibility.

`-s`: prefer folding at the last blank byte before the selected width.

`-w width`: set the maximum output line width. The width must be a positive decimal integer.

Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Read when no file operands are supplied, or when a file operand is exactly `-`.

## Standard Output
Folded input bytes are written to standard output. Existing newline bytes are preserved, and inserted folds use LF.

## Standard Error
Diagnostics are written for invalid options, invalid widths, and operands that cannot be read.

## Exit Status
`0` success, `1` one or more operands could not be read or output failed, `2` invalid usage, `125` internal failure.

## Behavioral Details
The default width is 80. A final input line without a newline remains without a final newline unless folding inserts one.
When `-s` is active, the blank byte chosen as the fold point is preserved before the inserted newline.

## Locale Behavior
Help and diagnostics are localized. Input data, inserted LF bytes, widths, and pathnames are command data and are not
localized.

## Implementation-Defined Choices
V1 uses deterministic byte-column counting for all modes. It does not calculate display columns for tabs, backspaces,
wide characters, or combining characters.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`fold -w 72 README.md`

`fold -s -w 40 notes.txt`

## Conformance Status
Conforming with implementation-defined behavior tracked by `FOLD-POSIX-001`.

## Known Limitations
Display-column measurement is intentionally byte-oriented in V1.
