# Security

Arguments, pathnames, environment values, locale data, streams, executable
search results, subprocess output, temporary-storage paths, and files are
treated as untrusted input.

Do not install these executables with elevated privileges. The project does not
request privilege elevation, install set-user-ID or set-group-ID binaries,
modify system utilities, or edit shell startup files.

Release builds validate:

- bounded stream copying and partial-write handling;
- safe diagnostic quoting for untrusted subjects;
- binary-safe command data paths;
- locale-dependent help and diagnostics through `messages`;
- terminal styling only through the presentation boundary;
- host-specific filesystem, stream, terminal, process, and temporary-storage
  behavior through host adapters;
- bounded executable identity verification for `posix-tools verify`;
- release archive checksums and archive integrity.

Report security defects with the affected command, platform, input bytes or
arguments, expected behavior, actual behavior, and whether the issue requires a
terminal, filesystem, environment, temporary-storage, or subprocess boundary.
