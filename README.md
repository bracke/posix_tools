# posix_tools

`posix_tools` is an Ada 2022 repository containing basic POSIX-style command-line utilities.

V1 inventory:

- `arch`
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
- `df`
- `dirname`
- `du`
- `echo`
- `env`
- `expand`
- `expr`
- `false`
- `file`
- `find`
- `fold`
- `getconf`
- `groups`
- `head`
- `hostname`
- `id`
- `kill`
- `link`
- `ln`
- `locale`
- `logname`
- `ls`
- `mkdir`
- `mkfifo`
- `mv`
- `nice`
- `nl`
- `nohup`
- `od`
- `paste`
- `pathchk`
- `printenv`
- `printf`
- `pwd`
- `readlink`
- `realpath`
- `rm`
- `rmdir`
- `seq`
- `sha256sum`
- `sleep`
- `split`
- `stat`
- `sort`
- `tail`
- `tee`
- `test`
- `timeout`
- `touch`
- `tr`
- `true`
- `tty`
- `unexpand`
- `uname`
- `unlink`
- `uniq`
- `wc`
- `which`
- `whoami`
- `xargs`
- `yes`
- `posix-tools`

`awk`, `grep`, and `sed` are not implemented in this repository; they are
maintained as separate sibling projects and are intentionally excluded from
the `posix_tools` command inventory.

The normative baseline is The Open Group Base Specifications, Issue 8, IEEE Std 1003.1-2024.
The root `posix-tools` executable is a project management command and is not part of POSIX conformance claims.

Command references live in `docs/commands/`. Development and release checks are
driven by the Ada executable `posix_tools_tests`, including metadata validation
through `project_tools`.
