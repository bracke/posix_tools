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
- Metadata validation asserts that the `release-check` branch names the selector
  smoke, staged verification, executable smoke, source archive, release checksum,
  metadata, format, conformance, and AUnit steps.
- Metadata validation also asserts that the `release` branch runs clean-tree
  enforcement before release generation/build work and reports completion
  through the Ada project_tools driver.
- The metadata gate validates package-manifest coverage from the compiled Ada
  command inventory for each command manifest, project file, wrapper source,
  reference document, and generated manual page.
- Each command manifest is validated against the compiled command inventory for
  crate name, executable name, synchronized version, MIT license, author and
  maintainer metadata, project-file declaration, local common dependency and
  pin, and coordinated build profile.
- The metadata gate also checks that the Ada build driver names the common
  crate, root crate, tests crate, and every command build label derived from the
  compiled command inventory.
- The metadata gate checks that staged verification invokes the bounded identity
  adapter for the built root executable and every command executable derived
  from the compiled command inventory.
- Generated manual pages are created by the Ada tooling from the compiled
  command inventory. The metadata gate compares the manual index, root manual
  page, and every command manual page byte-for-byte against the expected current
  content and requires every generated manual page to appear in the package
  manifest.
- The metadata gate requires the AI-oriented project guide and checks its
  repository map, package map, dependency rules, import boundaries, workflow,
  testing, localization, styling, resource, completion, and rejected architecture
  sections.
- The metadata gate checks that the Ada format scanner and testing guide cover
  maintained Ada, Alire/GPR, Markdown, CSV, and text files for tabs, trailing
  whitespace, and multiple consecutive blank lines.
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
- Version synchronization is checked as exact current lines across the root,
  common, tests, and command Alire manifests, the compiled
  `Posix_Tools.Version.Version_String` metadata, the changelog, and generated
  documentation, package-manifest, and release-checksum headers.
- The release message catalog is validated as a required source file, selected
  release locale identifiers are checked by metadata validation, and the catalog
  must appear in the generated package manifest.
- The release gate writes `dist/posix-tools-<version>-source.7z` from
  `generated/package-files.txt`; `dist/` is ignored because release archives are
  reproducible outputs, while their checksums are recorded in generated metadata.
- `posix_tools_tests release` first requires `git status --porcelain` to report
  a clean source tree, then runs the same implemented gates as `release-check`
  and reports completion.
