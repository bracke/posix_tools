with Ada.Containers.Vectors;
with Ada.Strings.Unbounded;
with Explore.String_Vectors;
with Posix_Tools.Arguments;

--  Handing files to other programs: the opener a file is opened with, the
--  shell command lines that run openers and the user's own commands, and the
--  clipboard sequence that puts text on the system clipboard.
--
--  Every command runs through /bin/sh in the directory explore shows, with
--  the files it is for as its positional parameters, so that a command line
--  names them as "$@" or "$1" and no file name is ever spliced into the text
--  of a command.
package Explore.Launch is
   type Opener is record
      --  Globs on the file's name, case ignored; an opener with none
      --  matches every file.
      Patterns : Explore.String_Vectors.Vector;
      --  The command line, for /bin/sh.
      Run      : Ada.Strings.Unbounded.Unbounded_String;
      --  Run apart from the terminal, without waiting for it to end, for a
      --  program with a window of its own.
      Detach   : Boolean := False;
   end record;

   package Opener_Vectors is new Ada.Containers.Vectors (Positive, Opener);

   --  Text goes to the editor the environment names, and anything else to
   --  the desktop's opener.
   Text_Opener  : constant String := "${VISUAL:-${EDITOR:-vi}} ""$@""";
   Other_Opener : constant String := "xdg-open ""$1""";

   --  The first of Openers whose patterns match Name, or else the default
   --  for a text file or for another.
   function Opener_For (Openers : Opener_Vectors.Vector; Name : String; Is_Text : Boolean) return Opener;

   Shell : constant String := "/bin/sh";

   --  The arguments for Shell that run Script in Directory with Files as its
   --  positional parameters. Detached, it runs in the background with its
   --  input and output away from the terminal, and Shell returns at once.
   function Shell_Arguments
     (Directory : String;
      Script    : String;
      Files     : Explore.String_Vectors.Vector;
      Detach    : Boolean := False) return Posix_Tools.Arguments.Vector;

   --  The script that starts the user's own shell, from SHELL.
   Interactive_Shell : constant String := "exec ""${SHELL:-/bin/sh}""";

   --  OSC 52: put Text on the system clipboard.
   function Clipboard (Text : String; In_Tmux : Boolean) return String;
end Explore.Launch;
