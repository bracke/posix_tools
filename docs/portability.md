# Portability

V1 targets Linux, Windows, and macOS. POSIX lexical path operations use `/` as
the only separator even on Windows.

Windows builds retain POSIX command semantics for the V1 utilities:

- option prefix is `-`;
- end-of-options marker is `--`;
- lexical pathname separator is `/`;
- POSIX line delimiter is LF;
- executable suffix is `.exe` where applicable;
- byte-processing mode is binary;
- for `basename` and `dirname`, backslash is an ordinary character.

Platform validation is performed by CI in `.github/workflows/ci.yml`. Each
runner uses the Node 24-compatible checkout action, builds the tests/tooling
crate after setup through the Node 24-compatible setup-alire v6 branch, and
runs `posix_tools_tests release-check`, which builds the common crate, root
executable, every command subcrate, and the tests crate, then runs metadata,
conformance, staged executable identity, and AUnit checks.
