# od

## Name
`od` - dump files in various formats.

## Synopsis
`od [-A address_base] [-j skip] [-N count] [-t type_string] [-v] [--] [file...]`

## Description
Writes a byte dump for each input.

## Operands
`file`: input file path. `-` reads standard input.

## Options
`-A address_base` selects address output: `d` decimal, `o` octal, `x` hexadecimal, or `n` for no addresses. Attached
forms such as `-An` are accepted. `-j skip` skips input bytes before dumping. `skip` accepts decimal, leading-zero
octal, `0x`/`0X` hexadecimal, and non-hexadecimal `b`, `k`, and `m` suffixes for 512, 1024, and 1048576 byte
multipliers. `-N count` limits the number of dumped bytes. `count` accepts decimal, leading-zero octal, and `0x`/`0X`
hexadecimal forms. Attached forms such as `-j16` and `-N0x20` are accepted.

`-t type_string` selects output types. V1 supports named characters `a`, characters `c`, signed decimal `d`, floating
point `f`, octal `o`, unsigned decimal `u`, and hexadecimal `x`. Integer types support byte sizes `1`, `2`, `4`, and
`8`, plus `C`, `S`, `I`, and `L` aliases. Floating types support `4`, `8`, `F`, `D`, and `L`; `L` is rendered using the
V1 double-precision path. Multiple types may be concatenated in one type string or supplied by repeated `-t` options.
Attached forms such as `-tx1` are accepted. `-a`, `-b`, `-c`, `-d`, `-o`, `-s`, and `-x` are accepted as historical
shorthand output type options. By default, repeated identical output blocks are replaced by a single `*`; `-v` emits
all repeated blocks. Project extensions `--help`,
`--version`, and `--posix-tools-identify` are recognized. The end-of-options marker `--` is accepted.

## Standard Input
Used when no files are supplied or when an operand is `-`.

## Standard Output
Offsets, unless suppressed with `-An`, followed by byte values in the selected display format.

## Standard Error
Diagnostics for invalid usage and input failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Data is processed as bytes and emitted in sixteen-byte rows. Address output reflects the byte offset after any selected
skip. Final address output is suppressed when `-An` is selected. The default output type is octal two-byte units. Numeric
values are interpreted in the implementation byte order used by this project. Partial final numeric items are padded with
NUL bytes for display. The `-t c` form renders printable ASCII characters and stable escapes for common controls; other
non-printable bytes are rendered as three-digit octal values. The `-t a` form renders IRV named characters using `nl` for
line feed. Duplicate suppression compares complete rendered data rows without their address prefixes.

## Locale Behavior
Data output is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
The V1 default dump format is octal two-byte units with octal addresses. Floating `L` is treated as the V1
double-precision representation.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`od file.bin`

`od -An file.bin`

`od -j 16 -N 32 file.bin`

`od -tx1 file.bin`

`od -t o2x2 -N 18 file.bin`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `OD-POSIX-001`.

## Known Limitations
No known V1 limitation.
