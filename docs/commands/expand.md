# expand

## Name
`expand` - convert tabs to spaces.

## Synopsis
`expand [-t tabstop[,tabstop...]] [file...]`

## Description
Writes each input file to standard output, replacing tab bytes with the number of space bytes needed to reach the next
tab stop. With no file operands, or with an operand exactly equal to `-`, `expand` reads standard input.

## Operands
`file`: input file to expand, or `-` for standard input.

## Options
`-t tabstop[,tabstop...]`: use one positive decimal tab width or a strictly increasing list of decimal tab stops.

Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized.

## Standard Input
Read when no file operands are supplied, or when a file operand is exactly `-`.

## Standard Output
Input bytes are written with tab bytes replaced by space bytes. Newline bytes reset the current column.

## Standard Error
Diagnostics are written for invalid options, invalid tab widths, and operands that cannot be read.

## Exit Status
`0` success, `1` one or more operands could not be read or output failed, `2` invalid usage, `125` internal failure.

## Behavioral Details
The default tab width is 8. A tab at column `n` emits enough spaces to reach the next configured tab stop. When a list is
given, stops must be strictly increasing. Columns after the final listed stop repeat using the distance between the last
two stops, or the single listed stop when only one stop was supplied. Other bytes are copied unchanged.

## Locale Behavior
Help and diagnostics are localized. Input data, inserted spaces, widths, and pathnames are command data and are not
localized.

## Implementation-Defined Choices
V1 counts bytes for column movement. It does not perform display-column adjustment for backspaces, wide characters, or
combining characters.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`expand Makefile`

`expand -t 4 source.adb`

## Conformance Status
Conforming with implementation-defined behavior tracked by `EXPAND-POSIX-001`.

## Known Limitations
Display-column adjustment for backspaces, wide characters, and combining characters is not yet implemented.
