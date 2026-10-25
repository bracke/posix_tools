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
comparisons `a -eq b`, `a -ne b`, `a -gt b`, `a -ge b`, `a -lt b`, and `a -le b`. The number of arguments decides first, as XCU test specifies: none is false; one is true when it is not
empty; two are `! string` or a unary primary; with three a binary primary in the middle comes first, then `!` and two
arguments, then `( string )`; with four, `!` and three arguments or `(` two arguments `)`. Only longer expressions, or
four that fit neither form, use the XSI grammar, where `!` binds tighter than `-a` and `-a` tighter than `-o`. So
`test x = -a` and `test ( = (` compare strings, and `test !` is true.

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
operators, or unknown unary or binary operators are invalid usage. An operand of `-eq`, `-ne`, `-gt`, `-ge`, `-lt` or
`-le` that is not an integer is diagnosed as `integer expression expected` and the exit status is `2`.

## Extensions
Sole-argument `--help`, `--version`, `--posix-tools-identify`; with any other argument they are operands, so `test --help = x` compares strings.

## Examples
`test value`

## Conformance Status
Conforming with extensions; see `POSIX-TEST-001`.

## Known Limitations
No known V1 limitation for the documented expression surface.
