# basename

## Name
`basename` - return the final lexical pathname component.

## Synopsis
`basename string [suffix]`

## Description
Processes `string` lexically using `/` as the only separator. Repeated and
trailing slashes are handled without consulting the filesystem.

## Operands
- `string`: pathname text to process.
- `suffix`: optional suffix removed only when it is present and not the whole
  resulting basename.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are
recognized by the common wrapper.

## Standard Input
Not used.

## Standard Output
The derived basename followed by LF.

## Standard Error
Diagnostics for missing or extra operands.

## Exit Status
`0` success, `2` invalid usage, `125` internal failure.

## Behavioral Details
Backslash is an ordinary character on every platform. Empty string returns an
empty line. Two or more leading slashes are treated as one root slash.

## Locale Behavior
Command data output is not localized. Help and diagnostics are localization
boundaries.

## Implementation-Defined Choices
`basename ""` produces an empty basename.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`basename /tmp/file .txt`

## Conformance Status
Conforming with extensions for V1 behavior tracked in `generated/requirements.csv`.

## Known Limitations
No GNU multi-name or suffix-option extensions are implemented.
