# unexpand

## Name
`unexpand` - convert spaces to tabs.

## Synopsis
`unexpand [-a] [-t tabstop] [file...]`

## Description
Writes each input file to standard output, replacing selected space-byte runs with tab bytes where doing so reaches the
same tab stops. With no file operands, or with an operand exactly equal to `-`, `unexpand` reads standard input.

## Operands
`file`: input file to unexpand, or `-` for standard input.

## Options
`-a`: convert space-byte runs beyond the leading blank portion of a line.

`-t tabstop`: use the given positive decimal tab width instead of the default width of 8.

Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Read when no file operands are supplied, or when a file operand is exactly `-`.

## Standard Output
Input bytes are written with selected spaces replaced by tab bytes. Newline bytes reset the current column.

## Standard Error
Diagnostics are written for invalid options, invalid tab widths, and operands that cannot be read.

## Exit Status
`0` success, `1` one or more operands could not be read or output failed, `2` invalid usage, `125` internal failure.

## Behavioral Details
Without `-a`, only leading spaces on each line are considered for tab replacement. With `-a`, every run of spaces is
considered. Other bytes are copied unchanged.

## Locale Behavior
Help and diagnostics are localized. Input data, inserted tabs, widths, and pathnames are command data and are not
localized.

## Implementation-Defined Choices
V1 supports a single positive decimal tab width. It does not yet implement comma-separated tab stop lists or
display-column adjustment for backspaces, wide characters, or combining characters.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`unexpand source.adb`

`unexpand -a -t 4 text.txt`

## Conformance Status
Conforming with implementation-defined behavior tracked by `UNEXPAND-POSIX-001`.

## Known Limitations
Tab stop lists are not yet implemented.
