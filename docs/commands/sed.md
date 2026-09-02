# sed

## Name

sed - stream editor

## Synopsis

`sed [-n] script [file...]`

`sed [-n] -e script [-e script]... [-f script_file]... [file...]`

`sed [-n] -f script_file [-e script]... [-f script_file]... [file...]`

## Description

`sed` reads text from the named files, or standard input when no file is named,
and applies a sed script using the integrated `sedlib` execution engine.
Input operands form one logical stream. The operand `-` names standard input
at its position in the stream.

## Operands

When no `-e` or `-f` option is present, the first operand is the script and all
remaining operands are input files. When `-e` or `-f` is present, every operand
is an input file. Use `--` before a positional script that begins with `-`.

## Options

`-n` suppresses the automatic print at the end of each cycle.

`-e script` appends script text to the program.

`-f script_file` appends script text loaded from `script_file`.

`--help` writes command help to standard output and exits successfully.

`--version` writes version information to standard output and exits
successfully.

`--color=auto`, `--color=always`, and `--color=never` control diagnostic
styling only.

`--` ends option processing.

GNU options such as `-i`, `-E`, `-r`, `-z`, `-s`, `-u`, `--posix`,
`--regexp-extended`, `--sandbox`, and `--follow-symlinks` are not implemented
and are reported as unknown options.

## Standard Input

Standard input is read when no input file is named or when `-` appears as an
input operand. Repeating `-` does not rewind standard input.

## Standard Output

Standard output carries sed program data only: the automatic print, `p`, `P`,
`=`, `l`, `a`, `i`, `c`, and `r` output. Help and version output also use
standard output, but only before script execution begins.

## Standard Error

Standard error carries localized diagnostics and never carries transformed
input data.

## Exit Status

`0` indicates success, including `--help` and `--version`.

`1` indicates script loading, compilation, input, output, or execution failure.

`2` indicates an invalid invocation.

`3` indicates an unexpected internal failure.

## Behavioral Details

Input operands are processed as a single logical stream. Scripts supplied by
`-e` and `-f` are compiled in command-line order before any input is opened.
Statuses accumulate monotonically, so a later successful operation does not
erase an earlier failure.

## Locale Behavior

Help, version labels, and diagnostics are resolved through the sed message
catalog. Program data remains byte-oriented and locale-invariant except where
the sed language engine explicitly defines text behavior.

## Implementation-Defined Choices

The nonzero exit statuses distinguish processing, invocation, and internal
failures even though POSIX only requires a value greater than zero on error.
Diagnostic color handling is implementation-defined and never changes data
output.

## Extensions

The command supports `--help`, `--version`, and `--color=auto|always|never` as
project extensions. The `--posix-tools-identify` option is reserved for the
repository verifier.

## Examples

Replace the first `foo` on each input line:

```
sed 's/foo/bar/' file
```

Suppress automatic printing and print only matching lines:

```
sed -n '/error/p' log.txt
```

Load a script from a file:

```
sed -f script.sed input.txt
```

## Conformance Status

Conforming with extensions.

## Known Limitations

The integrated implementation follows the current `sedlib` feature set. GNU
extensions such as in-place editing, extended regular expressions through
`-E`/`-r`, NUL-separated mode, and sandbox mode are intentionally not
implemented in this command.
