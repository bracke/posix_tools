# dd

## Name
`dd` - copy a byte stream.

## Synopsis
`dd [if=file] [of=file] [count=n] [files=n] [bs=n] [cbs=n] [ibs=n] [obs=n] [skip=n] [iseek=n] [seek=n] [oseek=n] [conv=ascii|ebcdic|ibm|block|unblock|noerror|notrunc|ucase|lcase|swab|sync]`

## Description
Copies bytes from standard input or an input file to standard output or an output file.

## Operands
Assignment operands select input, output, count, input file count, block sizes, conversion block size, input/output
offsets, and limited conversion modes. Numeric operands accept plain decimal values, `c` for 1-byte units, `b` for 512-byte units, `k` and
`K` for 1024-byte units, `M` for 1024*1024-byte
units, `G` for 1024*1024*1024-byte units, `w` for 2-byte units, and `x` multiplication.

## Options
Project extensions `--help`, `--version`, and `--posix-tools-identify` are recognized only as sole arguments.

## Standard Input
Used when `if=` is absent.

## Standard Output
Copied data when `of=` is absent.

## Standard Error
Diagnostics for invalid operands and I/O failures. On successful copies, deterministic `records in` and `records out`
accounting is written to standard error.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
`count=` limits copied input blocks. `files=` is parsed as a positive numeric operand for the single input-source
model. `ibs=` sets the input block size used by `count=` and `skip=`. `obs=` sets the
output block size used by `seek=` and `oseek=`. `bs=` sets both input and output block sizes; when absent, each block
size is 512 bytes. `skip=` and `iseek=` skip input blocks before copying. For standard output, `seek=` and `oseek=` prefix output with zero bytes for the
selected number of output blocks; for `of=`, `seek=` positions the output file before writing so large offsets do not
require retaining the skipped prefix in memory. `cbs=` sets the conversion block size required by `conv=block` and
`conv=unblock`, `conv=ascii`, `conv=ebcdic`, and `conv=ibm`. Numeric values with `b`, `k`, `K`, `M`, `G`, and `w`
suffixes and `x` multiplication are multiplied before use. `conv=sync` pads the final selected input block to the current input block size before other conversions:
with NUL bytes normally, and with spaces when `conv=block` or `conv=unblock` is active. `conv=block` converts
LF-terminated input lines into fixed-size `cbs=` records padded with spaces or
truncated to the conversion block size. `conv=unblock` converts fixed-size `cbs=` records to LF-terminated lines after
removing trailing spaces. `conv=ascii` maps EBCDIC bytes to ASCII bytes and handles input as `unblock`; `conv=ebcdic`
and `conv=ibm` handle input as `block` and then map ASCII bytes to EBCDIC bytes using the project deterministic
single-byte table. `conv=swab` swaps adjacent bytes in the selected
output data and leaves an odd final byte unchanged. `conv=ucase` and `conv=lcase` convert ASCII letters after byte
swapping; with comma-separated case conversion names, the later case conversion wins. `conv=noerror` diagnoses a read
failure and retains the readable prefix collected before that failure in the deterministic command context. When
combined with `conv=sync`, that partial failed block is padded to the input block size before conversion.
`conv=notrunc` preserves existing output-file bytes outside the written region and honors `seek=` as the write offset.
Record accounting reports full and partial selected input blocks and full and partial converted output blocks using the
selected input and output block sizes. `conv=block`, `conv=ebcdic`, and `conv=ibm` also report truncated conversion
records when an input line is longer than `cbs=`.

## Locale Behavior
Copied data is not localized. Help and diagnostics are localized.

## Implementation-Defined Choices
The current implementation keeps the expanded command simple and deterministic. Default input and output block sizes
are 512 bytes.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`dd if=input of=output count=12`

## Conformance Status
Conforming with extensions. Requirement coverage is tracked by `POSIX-DD-001`.

## Known Limitations
The implementation reports deterministic record accounting and uses the project command context for input failures.
