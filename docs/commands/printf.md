# printf

## Name
`printf` - format and write arguments.

## Synopsis
`printf format [argument...]`

## Description
Writes a format string with limited substitution.

## Operands
`format`: format string. `argument`: values for substitutions.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized only as sole arguments.

## Standard Input
Not used.

## Standard Output
Formatted data.

## Standard Error
Diagnostics for invalid usage.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The current formatter supports `%s`, `%b`, `%d`, `%i`, `%u`, `%o`, `%x`, `%X`, `%f`, `%e`, `%E`, `%g`, `%G`, `%c`,
minimum field width, left-justified `-` width, zero padding for numeric fields, signed decimal `+` and space flags,
alternate-form `#` prefixes
for `%o`, `%x`, and `%X`, dynamic `*` width and precision, string precision for `%s` and `%b`, integer precision for `%d`,
`%i`, `%u`, `%o`, `%x`, and `%X`, fixed decimal precision for `%f`, scientific decimal precision for `%e` and `%E`,
general decimal precision for `%g` and `%G`, field width and left justification for `%c`, `%%`,
`\a`, `\b`, `\f`, `\n`, `\t`, `\r`, `\v`, `\\`, and `\0ooo` octal byte escapes. The format is reused while arguments
remain when a conversion consumes operands.

## Locale Behavior
Numeric conversions use the effective numeric locale selected from `LC_ALL`, `LC_NUMERIC`, then `LANG`.
For decimal integer and floating conversions, digit glyphs and signs come from `i18n`; floating conversions use the
locale decimal separator. Octal and hexadecimal conversions keep ASCII base digits and prefixes. Help and diagnostics are
localized.

## Implementation-Defined Choices
Missing `%s`, `%b`, and `%c` arguments are treated as empty strings; missing numeric and dynamic width or precision
arguments are treated as zero. `%b` expands backslash escapes in the
argument; `\c` stops further output. `%d` and `%i` validate signed decimal operands and emit canonical decimal digits. `%u`,
`%o`, `%x`, and `%X` validate nonnegative decimal operands and emit the selected base. `%f`, `%e`, and `%E` accept decimal
operands; `%e`, `%E`, `%g`, and `%G` also accept exponent notation. Floating formats round using decimal half-up
rounding before numeric-locale rendering. `%f`, `%e`, and `%E` emit six fractional digits unless precision is supplied;
`%g` and `%G` use six significant digits unless precision is supplied and trim trailing zeros unless alternate form is
selected. `%c` emits the first character of the supplied operand.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`printf "%s\n" value`

## Conformance Status
Conforming with extensions tracked by `PRINTF-POSIX-001`.

## Known Limitations
Field width is supported for `%c`; precision on `%c` has no observable effect.
