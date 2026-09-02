# grep

A POSIX-oriented command-line grep wrapper for `posix_tools`.

The executable owns invocation parsing, process status, and output formatting.
Pattern compilation and all record matching are delegated to
[`greplib`](../../../greplib).

## Status

This integration supports file and standard-input searches, `-e`, `-f`, `-F`,
`-i`, `-v`, `-c`, `-l`, `-L`, `-q`, `-n`, `-H`, `-h`, `-x`, `-s`, `--help`,
`--version`, and `--posix-tools-identify`.

Recursive search and GNU-only output modes are not implemented here. Regular
expression syntax follows the `regexp` engine exposed by `greplib`; use `-F`
for byte-exact fixed-string matching.

## Building

```sh
cd tools/grep && alr build
```

## Examples

```sh
grep needle input.txt
grep -n -e error -e warning log.txt
grep -F 'a.b' input.txt
grep -c needle first.txt second.txt
```

## License

MIT. See [LICENSE](../../LICENSE).
