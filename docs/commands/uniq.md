# uniq

## Name
`uniq` - report or filter adjacent repeated lines.

## Synopsis
`uniq [-cdiu] [-f fields] [-s chars] [--] [input [output]]`

## Description
Writes consecutive duplicate lines only once, or filters them according to the
selected reporting mode.

## Operands
`input`: input file or `-` for standard input. `output`: output file.

## Options
`-c` prefixes each emitted line with a seven-column count field followed by one space. `-d` emits only repeated groups.
`-i` compares ASCII plus selected UTF-8 Latin-1, Latin Extended-A, Latin Extended-B, Greek, Cyrillic, Armenian, Cherokee, Georgian,
Deseret, and Fullwidth Latin uppercase pairs without case significance before applying the project release-locale
collation key. `-u` emits only unrepeated groups. `-f fields` skips leading
blank-separated fields before comparison. `-s chars` skips characters after field skipping. Project extensions `--help`,
`--version`, and `--posix-tools-identify` are recognized. Options are recognized before the first input operand; later
option-like words are operands. The end-of-options marker `--` is accepted.

## Standard Input
Used when no file operand is supplied.

## Standard Output
Filtered lines.

## Standard Error
Diagnostics for invalid usage and input failures.

## Exit Status
`0` success, `1` operational failure, `2` invalid usage, `125` internal failure.

## Behavioral Details
Line comparison is adjacent only unless `-i` is selected. Count output uses a deterministic seven-column decimal field.
Line comparison uses the project release-locale collation key after field and character skipping. Field skipping treats
Unicode whitespace under the project UTF-8 text policy as field separators. Character skipping
uses decoded UTF-8 characters. Invalid UTF-8 bytes are advanced byte-by-byte for skip purposes. Case-insensitive
comparison folds ASCII plus selected UTF-8 Latin-1, Latin Extended-A, Latin Extended-B, Greek, Cyrillic, Armenian, Cherokee, Georgian,
Deseret, and Fullwidth Latin uppercase pairs for the comparison key only;
emitted lines preserve their original bytes.

## Locale Behavior
Duplicate detection uses the effective locale through the project release-locale collation data. Filtered output keeps
the original input bytes. Help and diagnostics are localized.

## Implementation-Defined Choices
Field boundaries and character skipping use the project deterministic UTF-8 and Unicode whitespace policy rather than
host byte classification. Case folding is deterministic and then passed through the project locale collation key.

## Extensions
`--help`, `--version`, `--posix-tools-identify`.

## Examples
`uniq sorted.txt`

## Conformance Status
Conforming with extensions tracked by `UNIQ-POSIX-001`.

## Known Limitations
None for the implemented V1 supported surface.
