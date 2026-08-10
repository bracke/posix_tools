# wc

## Name
`wc` - count lines, words, bytes, and characters.

## Synopsis
`wc [-c] [-l] [-m] [-w] [file...]`

## Description
Counts selected domains for each input. With no count options, V1 prints line,
word, and byte counts.

## Operands
`file`: input file path or `-` for standard input.

## Options
- `-c`: bytes.
- `-l`: LF bytes.
- `-m`: UTF-8 characters.
- `-w`: words under the project Unicode whitespace policy.

## Standard Input
Used when no files are present or when an operand is `-`.

## Standard Output
One result line per successful input and a total line for multiple operands.

## Standard Error
Diagnostics for unreadable files and invalid UTF-8 in text-counting modes.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Byte and line counting never decode text. `-m` and `-w` use incremental UTF-8
decoding from `Posix_Tools.Text.UTF_8` and reject malformed or incomplete
sequences for the affected input.

## Locale Behavior
Count output is not localized. Text classification is deterministic UTF-8 and
is not full arbitrary POSIX locale behavior.

## Implementation-Defined Choices
Unicode whitespace is isolated in `Posix_Tools.Text.Classification` and backed
by generated `Posix_Tools.Text.Whitespace_Data` property ranges recording
Unicode version 15.1.0, the UCD source, and the Unicode license reference.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`wc -l -w -c file`

## Conformance Status
Conforming with extensions for V1 behavior tracked in `generated/requirements.csv`.

## Known Limitations
GNU `-L` maximum-line-length mode is not a POSIX.1-2024 `wc` option and is not
implemented in V1.
