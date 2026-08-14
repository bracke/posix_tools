# posix_tools

`posix_tools` is an Ada 2022 repository containing basic POSIX-style command-line utilities.

V1 inventory:

- `basename`
- `cat`
- `chgrp`
- `chmod`
- `chown`
- `cksum`
- `cmp`
- `comm`
- `cp`
- `cut`
- `date`
- `dd`
- `dirname`
- `du`
- `echo`
- `env`
- `expr`
- `false`
- `file`
- `find`
- `fold`
- `head`
- `id`
- `kill`
- `link`
- `ln`
- `logname`
- `ls`
- `mkdir`
- `mv`
- `od`
- `paste`
- `pathchk`
- `printf`
- `pwd`
- `readlink`
- `realpath`
- `rm`
- `rmdir`
- `sleep`
- `split`
- `sort`
- `tail`
- `tee`
- `test`
- `timeout`
- `touch`
- `tr`
- `true`
- `tty`
- `uname`
- `uniq`
- `wc`
- `whoami`
- `xargs`
- `posix-tools`

`awk`, `grep`, and `sed` are not implemented in this repository; they are
maintained as separate sibling projects and are intentionally excluded from
the `posix_tools` command inventory.

The normative baseline is The Open Group Base Specifications, Issue 8, IEEE Std 1003.1-2024.
The root `posix-tools` executable is a project management command and is not part of POSIX conformance claims.

Command references live in `docs/commands/`. Development and release checks are
driven by the Ada executable `posix_tools_tests`, including metadata validation
through `project_tools`.
