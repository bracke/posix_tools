# sed

A POSIX-oriented command-line stream editor written in Ada 2022.

The executable owns invocation parsing, script provenance, the logical input
stream, standard and named output, localized diagnostics and process status.
It contains no sed language of its own: [`sedlib`](../../../sedlib) is the sole
sed parser and execution engine, and `regexp` is the sole regular-expression
engine. If a required behaviour is missing there, it is fixed there.

## Status

Prerelease, `0.1.0-dev`. The POSIX command set, address forms, substitution
and basic regular expressions are implemented and tested, and no conformance
gaps are open -- see [docs/posix-conformance.md](docs/posix-conformance.md) for
the feature-by-feature classification. The version stays a prerelease because
this is the first snapshot of a new program, not because anything is known to
be missing.

## Invocation

```
sed [-n] script [file...]
sed [-n] -e script [-e script]... [-f script_file]... [file...]
sed [-n] -f script_file [-e script]... [-f script_file]... [file...]
```

Options: `-n`, `-e`, `-f`, and the administrative `--help`, `--version`,
`--color=auto|always|never` and `--`. GNU extensions such as `-i`, `-E`, `-r`,
`-s`, `-u` and `-z` are not implemented and are rejected as unknown options
rather than silently accepted. See [docs/command-line.md](docs/command-line.md).

## Examples

```sh
sed 's/alpha/one/' input.txt        # substitute on every line
sed -n '/beta/p' input.txt          # print only matching lines
sed -e 's/a/A/' -e 's/b/B/' f       # several expressions, in order
sed -f rules.sed input.txt          # a script from a file
sed -n '$p' first.txt second.txt    # $ is the last line of both files
sed -- '-script'                    # a script that starts with a hyphen
```

All input operands form one logical stream: line numbers continue across
files, `$` matches only the final line of the whole stream, and execution
state never resets at a file boundary.

## Build requirements

* Alire 2.1 or later
* GNAT 15.2.1 (`gnat_native`)
* The `sedlib`, `regexp`, `terminal_styles`, `messages` and `i18n` crates,
  resolved through the local pins in `alire.toml`

Every build runs through Alire; there is no direct `gprbuild` workflow.

## Building, testing and verifying

```sh
cd tools/sed && alr build                   # build the executable
cd tests && alr build                       # build the posix_tools test driver
tests/bin/posix_tools_tests check           # run the integrated command checks
tests/bin/posix_tools_tests docs            # regenerate/check command docs
tests/bin/posix_tools_tests package         # regenerate/check package metadata
tests/bin/posix_tools_tests prove           # run the common SPARK proof gate
```

All release tooling is Ada and lives in the parent `posix_tools` repository.

## Localization and styling

Every user-facing string comes from the message catalogue at
`share/sed/messages/catalog.txt`, which ships as
`<prefix>/share/sed/messages/catalog.txt` and is resolved relative to the
executable. English and Danish are both maintained; the integrated metadata
checks fail if either locale is missing a key that a diagnostic or an option
needs.

`--color` styles diagnostics only. Program data is never localized and never
styled, on any stream, under any colour mode.

## Known limitations

No conformance gaps are open. Bounds that exist -- pattern-space size, and the
recursion depth of a backreferenced match -- are set far beyond realistic use
and report a structured diagnostic rather than failing abruptly; see
[docs/posix-conformance.md](docs/posix-conformance.md).

## Documentation

| Document | Contents |
| --- | --- |
| [docs/command-line.md](docs/command-line.md) | Options, operands, streams, exit status |
| [docs/posix-conformance.md](docs/posix-conformance.md) | Feature-by-feature classification and gaps |
| [docs/input-output-model.md](docs/input-output-model.md) | Bytes, newlines, the logical stream |
| [docs/diagnostics-and-localization.md](docs/diagnostics-and-localization.md) | Diagnostic model, catalogue, escaping |
| [docs/testing.md](docs/testing.md) | Suite organization and test identifiers |

## License

MIT. See [LICENSE](LICENSE).
