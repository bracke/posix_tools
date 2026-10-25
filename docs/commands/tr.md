# tr

## Name
`tr` - translate or delete characters.

## Synopsis
`tr [-cCds] set1 [set2]`

## Description
Reads standard input and translates, deletes, or squeezes bytes matching `set1`. Simple ascending byte ranges such as
`a-z` and `\141-\143`, selected ASCII bracket classes, i18n-backed locale equivalence classes, collating-symbol forms,
numeric repeated-output forms, and common backslash byte escapes are expanded.

## Operands
`set1`: source byte set. `set2`: replacement byte set. Sets may contain simple ascending ranges, selected classes,
i18n-backed locale equivalence classes, collating-symbol forms, numeric repeated-output forms, and backslash escapes.

## Options
`-c` and `-C` complement `set1`. `-d` deletes matching characters. `-s` squeezes repeated output characters that are
in the last operand: `set2` when it is given, otherwise `set1`, complemented under `-c`. With translation mode,
complemented characters use the locale collation order when the selected locale has one, with deterministic byte-order
fallback. Project extensions are recognized.

## Standard Input
Input to transform. It is read and written chunk by chunk, so `tr` works on endless input such as `yes | tr y n`.

## Standard Output
Transformed bytes.

## Standard Error
Diagnostics for invalid usage and standard input read failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
In the `C` and `POSIX` locales without a UTF-8 codeset, sets and input are bytes. In every other locale they are UTF-8
characters: a multibyte character in a set is one element, ranges run over code points, `[c*n]` repeats a character, and
an input byte that does not start a valid UTF-8 sequence is a character of its own. Complemented translation in those
locales places ASCII characters in the locale collation order and other characters after them in code point order.
Otherwise sets are interpreted as byte strings with simple ascending range expansion. Backslash escapes `\a`, `\b`, `\f`, `\n`,
`\r`, `\t`, `\v`, `\\`, and one- to three-digit octal byte escapes are expanded. The byte-oriented classes
`[:alnum:]`, `[:alpha:]`, `[:blank:]`, `[:cntrl:]`, `[:digit:]`, `[:graph:]`, `[:lower:]`, `[:print:]`, `[:punct:]`,
`[:space:]`, `[:upper:]`, and `[:xdigit:]` are expanded. Complement mode and squeeze mode are byte-oriented; complement
translation orders replacement positions over the locale collation order after removing bytes in `set1`, then over
remaining bytes 0 through 255. With `-d -s`, `set1` is deleted and `set2` selects bytes to squeeze.
Repeated-output forms use `[byte*count]`, where
`byte` may be escaped and `count` is decimal or octal when it has a leading zero, and `[byte*]`, which repeats the byte
across the 256-byte domain.
Equivalence classes `[=bytes=]` expand through `i18n` primary collation data plus release-locale equivalence fallbacks
when available and otherwise fall back to the named byte sequence. Collating symbols `[.bytes.]` accept supported multibyte symbols such as Spanish
`ch` and Danish `aa`, with byte-sequence fallback for unknown symbols. Bytes may be escaped.

## Locale Behavior
Command data is transformed according to `i18n` collation data and release-locale metadata where a set expression requires it.
Help and diagnostics are localized.

## Implementation-Defined Choices
Character classes are expanded with deterministic ASCII byte ranges. Locale equivalence and collation support uses
`i18n` collation plus project UTF-8 byte-sequence metadata for supported release locales and falls back to byte identity
for unknown locale elements.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`tr abc xyz`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `POSIX-TR-001`.

## Known Limitations
None for the implemented V1 supported surface.
