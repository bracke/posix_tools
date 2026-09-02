# grep Command-Line Reference

## Synopsis

```text
grep [-EFGbciloLqRrvinHhwxs] [-A num] [-B num] [-C num] [-m num] [-e pattern] [-f pattern_file] pattern [file...]
```

With no file operands, `grep` searches standard input. A file operand of `-`
also names standard input.

## Options

- `-e pattern`: add a search pattern.
- `-f pattern_file`: read newline-separated patterns from a file.
- `-F`: treat patterns as fixed strings.
- `-G`: use POSIX basic regular-expression syntax. This is the default.
- `-E`: use the extended regular-expression syntax exposed by `greplib`.
- `-i`: ignore ASCII case differences.
- `-v`: select non-matching records.
- `-w`: require whole-word matches.
- `-A num`: print trailing context records.
- `-B num`: print leading context records.
- `-C num`: print leading and trailing context records.
- `-c`: print selected-record counts.
- `-l`: print names of files with selected records.
- `-L`: print names of files without selected records.
- `-m num`: stop after `num` selected records per input source.
- `-o`: print only matching text.
- `-q`: suppress output and report only status.
- `-b`: prefix output records with zero-based byte offsets.
- `-n`: prefix selected records with one-based record numbers.
- `-H`: force file-name prefixes.
- `-h`: suppress file-name prefixes.
- `-r`, `-R`: recursively search directory operands.
- `-x`: require the accepted match to cover the whole record.
- `-s`: suppress diagnostics for input/search failures.
- `--help`, `--version`, `--posix-tools-identify`: administrative extensions.

## Exit Status

- `0`: at least one selected record was found.
- `1`: no selected record was found.
- `2`: invocation, pattern, input, or internal failure.
