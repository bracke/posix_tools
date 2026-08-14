# nl

## Name

nl - write files with selected lines numbered.

## Synopsis

`nl [-ba|-bt|-bn] [-fa|-ft|-fn] [-ha|-ht|-hn] [-d delim] [-i increment] [-p] [-s separator] [-v start] [-w width] [file...]`

## Description

`nl` writes each input file to standard output, prefixing selected logical lines
with a line number. With no file operands, or with a file operand exactly equal
to `-`, standard input is read.

## Operands

`file`: input file to number, or `-` for standard input.

## Options

`-ba`: number all body lines.

`-bt`: number non-empty body lines. This is the default.

`-bn`: do not number body lines.

`-fa`, `-ft`, `-fn`: select numbering for footer lines.

`-ha`, `-ht`, `-hn`: select numbering for header lines.

`-d delim`: use the two-character logical page delimiter `delim`. The default is `\:`.

`-i increment`: set the line-number increment. The value must be a positive decimal integer.

`-p`: do not restart numbering at logical page delimiters.

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

Logical page delimiters select header, body, and footer sections. With the default delimiter `\:`, `\:\:\:` starts a
header section, `\:\:` starts a body section, and `\:` starts a footer section. Delimiter lines are not copied to output.
Unless `-p` is supplied, numbering restarts at the configured initial value when a new logical page starts. A non-numbered
line is prefixed with blanks matching the configured number width followed by the configured separator.

## Locale Behavior

Help and diagnostics are localized. Input data, line numbers, separators, and pathnames are command data and are not
localized.

## Implementation-Defined Choices

Line-number fields are right-aligned ASCII decimal. V1 uses byte-preserving LF line scanning. Logical page delimiters are
recognized lexically using the configured two-character delimiter and LF line endings.

## Extensions

`--help`, `--version`, `--posix-tools-identify`.

## Examples

`nl file.txt`

`nl -ba -w 3 -s ": " file.txt`

## Conformance Status

Conforming with extensions.

## Known Limitations

No known V1 limitations for the documented option set.
