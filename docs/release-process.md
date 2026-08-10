# Release Process

A release must build every crate, run the tests/tooling executable, verify
metadata consistency, generate documentation, and produce checksums.

The GitHub Actions workflow in `.github/workflows/ci.yml` runs the release
check on Linux, macOS, and Windows. A release candidate should not be treated as
platform-validated until all three CI jobs have passed for the candidate commit.

Current Ada tooling entry points:

- `posix_tools_tests check` validates metadata and runs the AUnit suite.
- `posix_tools_tests build` builds the root crate, every command subcrate, and
  the tests crate through Alire using `project_tools`.
- `posix_tools_tests docs` regenerates `generated/manual-index.md`.
- `posix_tools_tests package` regenerates `generated/package-manifest.txt`
  with byte counts and FNV-1a checksums for packaged files.
- `posix_tools_tests release-check` and `release` regenerate
  `generated/release-checksums.txt` with FNV-1a checksums for the package
  manifest and built executables.
- `posix_tools_tests release-check` regenerates the current generated docs and
  package manifest, builds the root crate, every command subcrate, and the
  tests crate, verifies the exact built command executables by internal
  identity, validates metadata, runs format checks, validates conformance
  metadata, and runs the AUnit suite.
- `posix_tools_tests release` first requires `git status --porcelain` to report
  a clean source tree, then runs the same implemented gates as `release-check`
  and reports completion; archive/checksum production remains acceptance work.
