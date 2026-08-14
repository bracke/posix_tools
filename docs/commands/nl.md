# nl

## Name

nl - write files with selected lines numbered.

## Synopsis

`nl [-ba|-bt|-bn] [-i increment] [-s separator] [-v start] [-w width] [file...]`

## Description

`nl` writes each input file to standard output, prefixing selected logical body
lines with a line number. With no file operands, or with a file operand exactly
equal to `-`, standard input is read.

## Operands

`file`: input file to number, or `-` for standard input.

## Options

`-ba`: number all body lines.

`-bt`: number non-empty body lines. This is the default.

`-bn`: do not number body lines.

`-i increment`: set the line-number increment. The value must be a positive decimal integer.

`-s separator`: write `separator` after each emitted number. The default is a tab byte.

`-v start`: set the initial line number. The value must be a decimal integer.

`-w width`: set the minimum line-number field width. The value must be a positive decimal integer.

Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input

Read when no file operands are supplied, or when a file operand is exactly `-`.

## Standard Output

Numbered input bytes are written to standard output. Newline bytes from input are preserved.

## Standard Error

Diagnostics are written for invalid options, invalid numeric operands, and input or output failures.

## Exit Status

0 success, 1 one or more operands could not be read or output failed, 2 invalid usage, 125 internal failure.

## Behavioral Details

V1 treats all input as body text. Logical page delimiter processing is not implemented. A non-numbered line is prefixed
with blanks matching the configured number width followed by the configured separator.

## Locale Behavior

Help and diagnostics are localized. Input data, line numbers, separators, and pathnames are command data and are not
localized.

## Implementation-Defined Choices

Line-number fields are right-aligned ASCII decimal. V1 uses byte-preserving LF line scanning and does not interpret
logical page delimiters.

## Extensions

`--help`, `--version`, `--posix-tools-identify`.

## Examples

`nl file.txt`

`nl -ba -w 3 -s ": " file.txt`

## Conformance Status

Known deviation tracked by NL-POSIX-001.

## Known Limitations

Logical page delimiter processing and header/footer/body section selection are not implemented in V1.
