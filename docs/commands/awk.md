# awk

## Name
`awk` - scan text files and execute AWK programs.

## Synopsis
`awk [options] 'program' [operand...]`

`awk [options] -f program-file [-f program-file...] [operand...]`

## Description
Runs AWK programs using the resolved `awklib` interpreter. Direct program text
or one or more `-f` program files provide the program source.

## Operands
`program`: direct AWK program text when no `-f` option is present. `operand`:
input file, `-` for standard input, or a runtime `name=value` assignment.

## Options
`-F sep`, `-Fsep`, `-v name=value`, `-vname=value`, `-f file`, `-ffile`, `--`,
`--help`, `--version`, and `--color=auto|always|never`.

## Standard Input
Used as AWK input when no input operand is supplied or when an operand is `-`.
`-f -` is not supported because standard input is reserved for input data.

## Standard Output
Program output and print redirections requested by the AWK program.

## Standard Error
Diagnostics for invalid options, missing program text, missing files, parser
failures, runtime failures, and host I/O failures.

## Exit Status
`0` success, `1` interpreter parse or runtime failure, `2` invalid invocation,
`3` host input/output failure, and `70` internal failure.

## Behavioral Details
The last `-F` value wins. Initial `-v` assignments are applied in command-line
order before `BEGIN`. Program files are loaded in command-line order and joined
with a safe line separator when needed. Runtime assignment operands are applied
at their operand positions. `command | getline` is executed through the CLI
platform adapter with the current process privileges.

## Locale Behavior
Help and diagnostics are localized through the AWK message catalogs. AWK
language behavior follows the resolved `awklib` runtime.

## Implementation-Defined Choices
Repeated `-` operands are accepted; after the first standard-input stream is
consumed, later occurrences observe end of file. Runtime assignments are
recognized when the name before `=` matches `[A-Za-z_][A-Za-z0-9_]*`.

## Extensions
`--help`, `--version`, `--color=auto|always|never`, and
`--posix-tools-identify`.

## Examples
`awk '{ print $1 }' input.txt`

`awk -F, '{ print $2 }' data.csv`

## Conformance Status
Conforming with extensions through the bundled CLI and resolved `awklib`
runtime.

## Known Limitations
Complete POSIX AWK language conformance is delegated to the resolved `awklib`
version. The CLI does not sandbox host commands executed through AWK programs.
