# xargs

## Name
`xargs` - construct argument lists.

## Synopsis
`xargs [-0rtx] [-E eofstr] [-I replstr] [-n number] [-s size] [utility [argument...]]`

## Description
Reads standard input, constructs utility argument lists, and invokes the selected utility.

## Operands
`utility`: command name. `argument`: fixed argument.

## Options
`-0` reads null-delimited input operands. `-E eofstr` stops reading input-derived operands at the selected marker.
`-I replstr` invokes the utility once for each input line and replaces occurrences of `replstr` in fixed arguments.
`-n number` emits at most `number` input-derived operands per composed line. `-s size` limits the composed utility
invocation size and splits batches before that limit is exceeded. `-t` writes each composed utility invocation to
standard error before execution. `-x` makes an oversized composed invocation fail instead of reducing the batch size.
`-r` and `--no-run-if-empty` skip the utility invocation when no input-derived operands are produced. `--` ends
`xargs` option recognition before the utility operand. Project extensions `--help`, `--version`, and
`--posix-tools-identify` are recognized.

## Standard Input
Input text to append.

## Standard Output
Utility standard output.

## Standard Error
Diagnostics for execution-boundary failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `123` invoked utility exited with status `1` through `125`,
`124` invoked utility exited with status `255`, `125` internal failure, `126` utility found but could not be invoked,
`127` utility not found.

## Behavioral Details
Without `-0`, input is split on spaces, tabs, and LF before batching. Single quotes, double quotes, and
backslash-escaped bytes remove their syntactic delimiters and keep embedded blanks inside the same input-derived
operand. With `-I`, input is split into LF-delimited replacement lines and each nonempty line drives one invocation.
With `-0`, input is split on null bytes; without `-n`, all null-delimited operands are passed in one utility invocation.
The first non-option operand selects the utility; later words are fixed utility arguments even when they look like
`xargs` options. If no utility is supplied, `echo` is used. By default an empty input still invokes the utility once
with only fixed operands; `-r` suppresses that invocation. The default composed invocation size limit is 131072 bytes,
counted as the
sum of utility and argument byte lengths plus one separator byte per argument vector element. `-s` replaces that limit.
A single utility invocation that cannot fit within the selected limit fails without invoking the utility. Non-zero
utility results are classified into the documented `xargs` exit-status bands. With `-x`, a batch selected by `-n` or by
all remaining input operands fails when its composed size exceeds `-s`; without `-x`, xargs reduces the batch when a
smaller nonempty batch can fit.

## Locale Behavior
Composed data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
Input splitting is byte-oriented and recognizes spaces, horizontal tabs, and LF. Quote and backslash handling is
deterministic and does not invoke a shell. Null-delimited splitting is also byte-oriented. The default composed command
size limit is 131072 bytes.

## Extensions
`-0`, `-r`, `--no-run-if-empty`, `--help`, `--version`, `--posix-tools-identify`.

## Examples
`xargs echo`

## Conformance Status
Conforming with extensions. Requirement tracked by `XARGS-POSIX-001`.

## Known Limitations
No known V1 limitation.
