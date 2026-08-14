# sha256sum

## Name

sha256sum - compute SHA-256 message digests

## Synopsis

`sha256sum [file...]`

## Description

`sha256sum` reads each file operand and writes a lowercase hexadecimal SHA-256 digest. With no operands, or with an
operand exactly equal to `-`, it reads standard input.

## Operands

Each operand names an input file. `-` names standard input.

## Options

`--` marks the end of options. `--help` and `--version` are provided by the common executable wrapper.

## Standard Input

Used when no operands are supplied or when an operand is `-`.

## Standard Output

For standard input, the command writes the digest followed by a newline. For file operands, it writes the digest, two
spaces, the operand text, and a newline.

## Standard Error

Diagnostics are written for input failures and output failures.

## Exit Status

Zero indicates all requested digests were written. One indicates an operational failure.

## Behavioral Details

Input is processed as bytes in bounded chunks. File data is not decoded or localized. SHA-256 digest calculation is
provided by the repository sibling `cryptolib` through `CryptoLib.Hashes`.

## Locale Behavior

Digest output is locale-invariant. Help and diagnostics are locale-dependent through `messages`.

## Implementation-Defined Choices

This is a project extension and follows the widely used `sha256sum` output shape for ordinary file and standard-input
operation.

## Extensions

The entire command is a project extension, not a POSIX.1-2024 utility.

## Examples

`sha256sum README.md`

## Conformance Status

Conforming with extensions.

## Known Limitations

Checksum verification modes such as `-c` are not implemented in this V1 extension.
