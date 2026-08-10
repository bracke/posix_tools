# Release Process

A release must build every crate, run the tests/tooling executable, verify
metadata consistency, generate documentation, and produce checksums.

The GitHub Actions workflow in `.github/workflows/ci.yml` runs the release
check on Linux, macOS, and Windows. A release candidate should not be treated as
platform-validated until all three CI jobs have passed for the candidate commit.
The local metadata gate checks the workflow triggers, read-only repository
permission, non-fail-fast matrix, timeout, Alire setup, tests-crate build step,
and release-check invocation so CI cannot silently stop exercising the Ada
release gate.

Current Ada tooling entry points:

- `posix_tools_tests check` validates metadata and runs the AUnit suite.
- `posix_tools_tests build` builds the root crate, every command subcrate, and
  the tests crate through Alire using `project_tools`.
- `posix_tools_tests docs` regenerates `generated/manual-index.md`.
- `posix_tools_tests package` regenerates `generated/package-manifest.txt`
  with byte counts and FNV-1a checksums for packaged files.
- `posix_tools_tests release-check` and `release` regenerate
  `generated/release-checksums.txt` with FNV-1a checksums for the package
  manifest, source release archive, and built executables.
- `posix_tools_tests release-check` regenerates the current generated docs and
  package manifest, builds the root crate, every command subcrate, and the
  tests crate, verifies the exact built root and command executables by internal
  identity, executes built binaries for version-output and representative
  command-data smoke coverage, validates metadata, runs format checks, validates
  conformance metadata, and runs the AUnit suite.
- The metadata gate validates package-manifest coverage from the compiled Ada
  command inventory for each command manifest, project file, wrapper source,
  reference document, and generated manual page.
- The metadata gate also verifies that every entry in
  `generated/package-files.txt` has exactly one current checksum row in
  `generated/package-manifest.txt`, that the manifest carries the synchronized
  version header, and that the manifest has no extra data rows beyond its
  header.
- The metadata gate verifies that `generated/release-checksums.txt` contains
  exactly the synchronized version header, package-manifest row, source-archive
  row, root executable row, and one row for every command executable from the
  compiled Ada inventory. When the referenced artifact exists, the gate
  recomputes and validates the recorded FNV-1a value.
- The release gate writes `dist/posix-tools-<version>-source.7z` from
  `generated/package-files.txt`; `dist/` is ignored because release archives are
  reproducible outputs, while their checksums are recorded in generated metadata.
- `posix_tools_tests release` first requires `git status --porcelain` to report
  a clean source tree, then runs the same implemented gates as `release-check`
  and reports completion.
