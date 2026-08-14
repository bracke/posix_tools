# unexpand

## Name
`unexpand` - convert spaces to tabs.

## Synopsis
`unexpand [-a] [-t tabstop[,tabstop...]] [file...]`

## Description
Writes each input file to standard output, replacing selected space-byte runs with tab bytes where doing so reaches the
same tab stops. With no file operands, or with an operand exactly equal to `-`, `unexpand` reads standard input.

## Operands
`file`: input file to unexpand, or `-` for standard input.

## Options
`-a`: convert space-byte runs beyond the leading blank portion of a line.

`-t tabstop[,tabstop...]`: use one positive decimal tab width or a strictly increasing list of decimal tab stops.

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
considered. When a tab-stop list is given, stops must be strictly increasing. Columns after the final listed stop repeat
using the distance between the last two stops, or the single listed stop when only one stop was supplied. Other bytes are
copied unchanged.

## Locale Behavior
Help and diagnostics are localized. Input data, inserted tabs, widths, and pathnames are command data and are not
localized.

## Implementation-Defined Choices
V1 uses a deterministic UTF-8 display-column policy for tab placement: common combining marks have width zero, common
East Asian and emoji ranges have width two, backspace moves one column left when possible, and invalid byte sequences
advance by one column per byte.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`unexpand source.adb`

`unexpand -a -t 4 text.txt`

## Conformance Status
Conforming with implementation-defined behavior tracked by `UNEXPAND-POSIX-001`.

## Known Limitations
No known limitation for the documented V1 display-column policy.
