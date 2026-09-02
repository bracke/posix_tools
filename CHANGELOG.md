# Changelog

## 0.1.0

- Initial coordinated V1 repository with the root `posix_tools` crate, shared `posix_tools_common` library
  crate, tests/tooling crate, and one binary subcrate per compiled command.
- Compiled command inventory includes 30 POSIX-style utilities plus the non-POSIX `posix-tools` management
  executable; `awk` and `sed` are integrated from sibling projects, while `grep` remains intentionally out of
  scope because it is maintained as a sibling project.
- Added structured command metadata, generated manual pages, command reference documents, conformance registry,
  regression registry, package manifest, release checksums, and source archive generation.
- Added messages-backed locale support for help and diagnostics, with command data output kept locale-invariant.
- Added host adapter boundaries for environment, filesystem, process, stream, signal, and terminal integration.
- Added release gates for inventory consistency, executable smoke tests, staged identity verification, archive integrity,
  checksum coverage, documentation consistency, formatting, conformance metadata, and selected proof targets.
