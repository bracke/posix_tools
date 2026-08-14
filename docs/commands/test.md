# test

## Name
`test` - evaluate an expression.

## Synopsis
`test expression`

## Description
Evaluates a limited expression and returns success or failure.

## Operands
Expression operands.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized only as sole arguments.

## Standard Input
Not used.

## Standard Output
No ordinary output.

## Standard Error
Diagnostics for internal failures.

## Exit Status
`0` expression true, `1` expression false or operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Supported forms include nonempty string, `! expression`, parenthesized expressions, `expression -a expression`,
`expression -o expression`, `-n string`, `-z string`, `-e path`, `-b path`, `-c path`, `-d path`, `-f path`,
`-h path`, `-L path`, `-g path`, `-k path`, `-p path`, `-r path`, `-s path`, `-S path`, `-t fd`, `-u path`,
`-w path`, `-x path`, `a -ef b`, `a = b`, `a != b`, string ordering `a < b` and `a > b`, and signed integer
comparisons `a -eq b`, `a -ne b`, `a -gt b`, `a -ge b`, `a -lt b`, and `a -le b`. `-a` binds tighter than `-o`.

## Locale Behavior
Expression results are not localized. String ordering uses the collation locale selected by `LC_ALL`,
`LC_COLLATE`, `LANG`, then the command context locale.

## Implementation-Defined Choices
String ordering uses the project i18n collation data and falls back to bytewise ordering for the `C` and `POSIX`
locales or when no collation data is available. `-ef` uses hostkit file identity metadata. `-t` answers for
standard input, output, and error descriptors 0, 1, and 2 through the command context
terminal service; other descriptor operands are false in this increment. `-g`, `-k`, `-u`, `-w`, and `-x` use
hostkit permission-bit metadata where available. `-b`, `-c`, `-p`, and `-S` use hostkit special-file subtype metadata
for block devices, character devices, FIFOs, and sockets where available. Malformed expressions with unbalanced parentheses, dangling boolean
operators, or unknown unary or binary operators are invalid usage.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`test value`

## Conformance Status
Conforming with extensions; see `POSIX-TEST-001`.

## Known Limitations
No known V1 limitation for the documented expression surface.
