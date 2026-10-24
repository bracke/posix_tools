--  Filesystem operations shared by the commands and by explore.
--
--  Each operation is Context-free: it takes what it works on as parameters and
--  reports what happened as data, leaving diagnostics, prompts, and output to
--  its caller, so a command-line tool and an interactive one can both build on
--  it.
package Posix_Tools.File_Operations is
   pragma Pure;
end Posix_Tools.File_Operations;
