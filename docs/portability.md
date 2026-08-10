# Portability

V1 targets Linux, Windows, and macOS. POSIX lexical path operations use `/` as
the only separator even on Windows.

Platform validation is performed by CI in `.github/workflows/ci.yml`. Each
runner builds the tests/tooling crate and runs `posix_tools_tests release-check`,
which builds the common crate, root executable, every command subcrate, and the
tests crate, then runs metadata, conformance, staged executable identity, and
AUnit checks.
