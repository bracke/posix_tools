# awk

`awk` is an Ada command-line AWK implementation built on `awklib`. Its command-line workflow follows traditional POSIX `awk`; supported language and runtime behavior is limited to the resolved `awklib` version.

The program does not claim complete POSIX conformance.

## Usage

```sh
awk '{ print }' file.txt
awk -F, '{ print $2 }' data.csv
awk -v limit=10 '$1 > limit { print $0 }' input.txt
awk -f program.awk input.txt
awk -f begin.awk -f rules.awk input1.txt input2.txt
```

If no input file is supplied, standard input is used:

```sh
printf 'one two\n' | awk '{ print $2 }'
```

Use `-` as an explicit standard-input operand, and use `--` before filenames
beginning with `-`:

```sh
awk '{ print FILENAME ":" $0 }' -- -data.txt
```

Operands after the program are named input files, `-`, or runtime assignments
whose name matches `[A-Za-z_][A-Za-z0-9_]*`. Runtime-assignment positioning is
limited by the current `awklib` API; see the compatibility guide.

`--help` and `--version` do not initialize the interpreter. CLI-owned help and
diagnostics use localized message catalogs and may be styled according to
`--color=auto|always|never`. In auto mode, styling follows `terminal_styles`,
including `NO_COLOR` and stdout terminal detection. AWK program output is never
localized or styled.

On Windows command prompts, quoting differs by shell. For example:

```cmd
awk "{ print $1 }" input.txt
awk -F, "{ print $2 }" data.csv
```

Build with Alire:

```sh
alr build --development
cd tests && alr build --development && ./bin/awk_tests_main
cd tests && ./bin/awk_workflows verify
```

The project uses Alire for dependency resolution and builds. Install Alire before
building locally. Workspace dependency pins and publish readiness policy are
documented in [docs/dependency-policy.md](docs/dependency-policy.md).

Limitations are documented in [docs/compatibility.md](docs/compatibility.md).
The project is MIT licensed.
