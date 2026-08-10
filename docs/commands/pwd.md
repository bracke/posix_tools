# pwd

## Name
`pwd` - write the working directory pathname.

## Synopsis
`pwd [-L|-P]`

## Description
Writes the logical or physical current working directory followed by LF.

## Operands
Operands are invalid.

## Options
- `-L`: logical mode.
- `-P`: physical mode.

## Standard Input
Not used.

## Standard Output
One pathname followed by LF.

## Standard Error
Diagnostics for invalid options, operands, or lookup failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The last applicable `-L` or `-P` option wins.
Logical mode uses `PWD` only when it is nonempty, absolute, and contains no `.`
or `..` pathname components. Otherwise it falls back to the physical current
directory.

## Locale Behavior
Path output is not localized.

## Implementation-Defined Choices
Logical mode falls back to physical lookup when `PWD` is unusable under the
project lexical policy above.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`pwd -P`

## Conformance Status
Conforming with extensions for V1 behavior tracked in `generated/requirements.csv`.

## Known Limitations
Logical `PWD` is accepted only when it passes the project lexical policy and
the filesystem adapter verifies that it names the physical current directory.
