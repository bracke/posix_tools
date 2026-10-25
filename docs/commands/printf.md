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
Diagnostics for invalid usage and for arguments that are not completely numbers.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
The current formatter supports `%s`, `%b`, `%d`, `%i`, `%u`, `%o`, `%x`, `%X`, `%f`, `%e`, `%E`, `%g`, `%G`, `%c`,
minimum field width, left-justified `-` width, zero padding for numeric fields, signed decimal `+` and space flags,
alternate-form `#` prefixes
for `%o`, `%x`, and `%X`, dynamic `*` width and precision, string precision for `%s` and `%b`, integer precision for `%d`,
`%i`, `%u`, `%o`, `%x`, and `%X`, fixed decimal precision for `%f`, scientific decimal precision for `%e` and `%E`,
general decimal precision for `%g` and `%G`, field width and left justification for `%c`, `%%`,
`\a`, `\b`, `\f`, `\n`, `\t`, `\r`, `\v`, `\\`, and `\ddd` escapes of one to three octal digits written as that
byte, so `\0101` is the byte 010 followed by `1`. The format is reused while arguments
remain when a conversion consumes operands.

## Locale Behavior
Numeric conversions use the effective numeric locale selected from `LC_ALL`, `LC_NUMERIC`, then `LANG`.
For decimal integer and floating conversions, digit glyphs and signs come from `i18n`; floating conversions use the
locale decimal separator. Octal and hexadecimal conversions keep ASCII base digits and prefixes. Help and diagnostics are
localized.

## Implementation-Defined Choices
Missing `%s`, `%b`, and `%c` arguments are treated as empty strings; missing numeric and dynamic width or precision
arguments are treated as zero. `%b` expands backslash escapes in the
argument; `\c` stops further output. In `%b` arguments `\0ddd` takes zero to three octal digits
after the `0`. Numeric arguments are read as C constants (XCU printf): optional blanks and sign, then decimal, octal
after a leading `0`, or hexadecimal after `0x` or `0X`; floating conversions also take a fraction, a decimal exponent,
and hexadecimal constants with a binary `p` exponent. An argument that starts with a single or double quote has the
codeset value of the character after it, decoded as UTF-8 in a UTF-8 character locale. An argument that is not
completely a number is diagnosed (`expected a numeric value`, `value not completely converted`, or `numeric result out
of range`), the value converted so far is written, processing continues, and the exit status is `1`. `%d` and `%i`
take the range of a 64-bit signed integer; `%u`, `%o`, `%x`, and `%X` that of a 64-bit unsigned one, a negative value
wrapping as `strtoumax` gives it. Floating formats round using decimal half-up
rounding before numeric-locale rendering. `%f`, `%e`, and `%E` emit six fractional digits unless precision is supplied;
`%g` and `%G` use six significant digits unless precision is supplied and trim trailing zeros unless alternate form is
selected. `%c` emits the first character of the supplied operand: the whole UTF-8 character when the character locale
(`LC_ALL`, `LC_CTYPE`, then `LANG`) names a UTF-8 codeset, otherwise its first byte. Field widths count bytes.

## Extensions
Sole-argument `--help`, `--version`, `--posix-tools-identify`; with any other argument they are operands, so `printf --help x` uses `--help` as the format.

## Examples
`printf "%s\n" value`

## Conformance Status
Conforming with extensions tracked by `PRINTF-POSIX-001`.

## Known Limitations
Field width is supported for `%c`; precision on `%c` has no observable effect.
