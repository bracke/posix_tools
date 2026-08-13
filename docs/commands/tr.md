# tr

## Name
`tr` - translate or delete characters.

## Synopsis
`tr [-cCds] set1 [set2]`

## Description
Reads standard input and translates, deletes, or squeezes bytes matching `set1`. Simple ascending byte ranges such as
`a-z` and `\141-\143`, selected ASCII bracket classes, equivalence and collating-symbol identity forms,
numeric repeated-output forms, and common backslash byte escapes are expanded.

## Operands
`set1`: source byte set. `set2`: replacement byte set. Sets may contain simple ascending ranges, selected classes,
equivalence and collating-symbol identity forms, numeric repeated-output forms, and backslash escapes.

## Options
`-c` and `-C` complement `set1`. `-d` deletes matching bytes. `-s` squeezes repeated output bytes from the selected
squeeze set. With translation mode, complemented bytes use the deterministic byte-order complement of `set1`. Project
extensions are recognized.

## Standard Input
Input bytes to transform.

## Standard Output
Transformed bytes.

## Standard Error
Diagnostics for invalid usage.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Sets are interpreted as byte strings with simple ascending range expansion. Backslash escapes `\a`, `\b`, `\f`, `\n`,
`\r`, `\t`, `\v`, `\\`, and one- to three-digit octal byte escapes are expanded. The byte-oriented classes
`[:alnum:]`, `[:alpha:]`, `[:blank:]`, `[:cntrl:]`, `[:digit:]`, `[:graph:]`, `[:lower:]`, `[:print:]`, `[:punct:]`,
`[:space:]`, `[:upper:]`, and `[:xdigit:]` are expanded. Complement mode and squeeze mode are byte-oriented; complement
translation orders replacement positions over bytes 0 through 255 after removing bytes in `set1`. With `-d -s`, `set1`
is deleted and `set2` selects bytes to squeeze. Repeated-output forms use `[byte*count]`, where
`byte` may be escaped and `count` is decimal or octal when it has a leading zero, and `[byte*]`, which repeats the byte
across the 256-byte domain.
Equivalence classes `[=bytes=]` and collating symbols `[.bytes.]` are accepted as deterministic byte-sequence identity
forms; bytes may be escaped.

## Locale Behavior
Transformed data is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
Character classes are expanded with deterministic ASCII byte ranges. Complement translation uses deterministic byte
ordering rather than the full POSIX locale collating element model.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`tr abc xyz`

## Conformance Status
Known deviation tracked by `TR-V1-DEVIATION-001`.

## Known Limitations
Locale-expanded equivalence classes, locale-dependent complement translation ordering, and multibyte locale collation
semantics are not implemented.
