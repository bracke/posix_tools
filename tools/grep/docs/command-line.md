# grep Command-Line Reference

## Synopsis

```text
grep [-FcilLqvinHhxs] [-e pattern] [-f pattern_file] pattern [file...]
```

With no file operands, `grep` searches standard input. A file operand of `-`
also names standard input.

## Options

- `-e pattern`: add a search pattern.
- `-f pattern_file`: read newline-separated patterns from a file.
- `-F`: treat patterns as fixed strings.
- `-i`: ignore ASCII case differences.
- `-v`: select non-matching records.
- `-c`: print selected-record counts.
- `-l`: print names of files with selected records.
- `-L`: print names of files without selected records.
- `-q`: suppress output and report only status.
- `-n`: prefix selected records with one-based record numbers.
- `-H`: force file-name prefixes.
- `-h`: suppress file-name prefixes.
- `-x`: require the accepted match to cover the whole record.
- `-s`: suppress diagnostics for input/search failures.
- `--help`, `--version`, `--posix-tools-identify`: administrative extensions.

## Exit Status

- `0`: at least one selected record was found.
- `1`: no selected record was found.
- `2`: invocation, pattern, input, or internal failure.
