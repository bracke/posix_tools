# grep

A POSIX-oriented command-line grep wrapper for `posix_tools`.

The executable owns invocation parsing, process status, and output formatting.
Pattern compilation and all record matching are delegated to
[`greplib`](../../../greplib).

## Status

This integration supports file and standard-input searches, `-e`, `-f`, `-F`,
`-E`, `-G`, `-i`, `-v`, `-w`, `-A`, `-B`, `-C`, `-c`, `-l`, `-L`, `-m`,
`-o`, `-q`, `-b`, `-n`, `-H`, `-h`, `-r`, `-R`, `-x`, `-s`, `--help`,
`--version`, and `--posix-tools-identify`.

Regular expression syntax follows the `regexp` engine exposed by `greplib`;
use `-F` for byte-exact fixed-string matching. Diagnostic wording is currently
locale-invariant.

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
grep -A 1 needle input.txt
grep -r needle src
grep -ow word input.txt
```

## License

MIT. See [LICENSE](../../LICENSE).
