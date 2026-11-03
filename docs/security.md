# Security

The project does not elevate privileges, modify system utilities, or install
set-user-ID or set-group-ID executables.

`POSIX_TOOLS_DEBUG` is intended only for controlled development environments.
When it is nonempty, internal-failure diagnostics can disclose exception
messages, source locations, pathnames, operands, or other process data. Do not
enable it when standard error is exposed to untrusted users or retained in
logs with broader access than the command's input data.
