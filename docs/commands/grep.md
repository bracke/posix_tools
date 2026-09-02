# grep

## Name

grep - search input records for matching patterns

## Synopsis

`grep [-EFGbciloLqRrvinHhwxs] [-A num] [-B num] [-C num] [-m num] [-e pattern] [-f pattern_file] pattern [file...]`

## Description

`grep` searches each input record for patterns using the integrated
`greplib` search engine. With no file operands, standard input is searched.
The operand `-` names standard input at its position in the file list.

## Operands

When no `-e` or `-f` option is present, the first non-option operand is the
pattern and all remaining operands are input files. When `-e` or `-f` is
present, every non-option operand is an input file.

## Options

`-e pattern` adds an inline pattern.

`-f pattern_file` reads newline-separated patterns from `pattern_file`.

`-F` treats patterns as fixed strings.

`-E` and `-G` select the regular-expression matcher exposed by `greplib`.

`-i` ignores ASCII case differences.

`-v` selects records that do not match.

`-w` requires a match to be bounded by ASCII word boundaries.

`-c` prints selected-record counts.

`-l` prints names of files with selected records.

`-L` prints names of files without selected records.

`-m num` stops after `num` selected records per input source.

`-o` prints only matching text, one accepted span per output record.

`-q` suppresses output and reports only status.

`-b` prefixes output records with zero-based byte offsets. With `-o`, offsets
refer to the selected match span.

`-n` prefixes selected records with one-based record numbers.

`-H` forces file-name prefixes and `-h` suppresses them.

`-r` and `-R` recursively search directory operands. With no file operands,
recursive search starts in the current directory.

`-x` requires a match to cover the whole record.

`-s` suppresses input and search diagnostics.

`--help`, `--version`, and `--posix-tools-identify` are project extensions.

## Standard Input

Standard input is searched when no file operand is supplied or when an operand
is exactly `-`.

## Standard Output

Standard output carries selected records, counts, source names, help text, or
version text depending on the selected mode. Data output is not localized.

## Standard Error

Standard error carries localized invocation, pattern, and input diagnostics
unless `-s` suppresses input/search diagnostics.

## Exit Status

`0` indicates that at least one selected record was found.

`1` indicates that no selected record was found.

`2` indicates invocation, pattern, input, or internal failure.

## Behavioral Details

Each file operand is searched independently. Matching, invert-match selection,
whole-word and whole-record checks, selected-record limits, context windows,
count modes, quiet mode, source-name modes, match spans, byte offsets, and
recursive traversal are delegated to `greplib`.

## Locale Behavior

Data output formatting is locale-invariant. Diagnostics use the project
message catalog selected by `LC_ALL`, `LANG`, or the native host locale.
Case-insensitive matching follows the ASCII folding behavior exposed by
`greplib`.

## Implementation-Defined Choices

Regular expression syntax follows the `regexp` engine used by `greplib`; this
wrapper does not translate POSIX basic regular expressions into a distinct
engine dialect. Use `-F` for byte-exact fixed-string matching.

## Extensions

`--help`, `--version`, and `--posix-tools-identify` are project extensions.
`-H`, `-h`, `-o`, `-b`, `-m`, `-w`, `-r`, and `-R` provide explicit prefix,
match-only, limit, word-boundary, and recursive traversal controls.

## Examples

Search one file:

```
grep needle input.txt
```

Search standard input with line numbers:

```
grep -n error
```

Use fixed-string matching:

```
grep -F 'a.b' input.txt
```

Print counts for multiple files:

```
grep -c needle first.txt second.txt
```

Print one line of trailing context:

```
grep -A 1 needle input.txt
```

Search a directory recursively:

```
grep -r needle src
```

## Conformance Status

Conforming with implementation-defined behavior and extensions.

## Known Limitations

The regular-expression dialect is the dialect provided by `greplib` and
`regexp`; this wrapper does not provide a separate POSIX BRE parser.
