# dirname

## Name
`dirname` - return the directory portion of a lexical pathname.

## Synopsis
`dirname string`

## Description
Processes `string` lexically using `/` as the only separator.

## Operands
`string`: pathname text to process.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are
recognized.

## Standard Input
Not used.

## Standard Output
The derived dirname followed by LF.

## Standard Error
Diagnostics for missing or extra operands.

## Exit Status
`0` success, `2` invalid usage, `125` internal failure.

## Behavioral Details
Backslash is an ordinary character. Empty string returns `.`. Two or more
leading slashes are treated as one root slash.

## Locale Behavior
Command data output is not localized.

## Implementation-Defined Choices
`dirname ""` produces `.`.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`dirname /tmp/file`

## Conformance Status
Conforming with extensions for V1 behavior tracked in `generated/requirements.csv`.

## Known Limitations
No filesystem resolution is performed.
