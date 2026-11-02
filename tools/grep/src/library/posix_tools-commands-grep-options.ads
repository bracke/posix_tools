with Greplib;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Grep.Patterns;

--  grep's command line: its options, its pattern list, and its file
--  operands.
package Posix_Tools.Commands.Grep.Options is
   type Regex_Mode is (Basic_Regular_Expression, Extended_Regular_Expression);

   type Invocation is record
      --  Every pattern of every -e, -f, or pattern operand, in order.
      Pattern_Texts          : Posix_Tools.Commands.Grep.Patterns.Text_Vectors.Vector;
      Files                  : Posix_Tools.Commands.Grep.Patterns.Text_Vectors.Vector;
      Fixed_Strings          : Boolean := False;
      Regex                  : Regex_Mode := Basic_Regular_Expression;
      Count_Only             : Boolean := False;
      List_With_Matches      : Boolean := False;
      List_Without_Matches   : Boolean := False;
      Quiet                  : Boolean := False;
      Recursive              : Boolean := False;
      Invert_Match           : Boolean := False;
      Ignore_Case            : Boolean := False;
      Whole_Word             : Boolean := False;
      Whole_Record           : Boolean := False;
      Only_Matching          : Boolean := False;
      Byte_Offset            : Boolean := False;
      Maximum_Selected       : Greplib.Wide_Count := 0;
      Before_Context         : Greplib.Wide_Count := 0;
      After_Context          : Greplib.Wide_Count := 0;
      Line_Number            : Boolean := False;
      Force_With_Filename    : Boolean := False;
      Force_Without_Filename : Boolean := False;
      Suppress_Diagnostics   : Boolean := False;
   end record;

   type Parse_Outcome is
     (Search,
      --  --help or --version: write it and succeed.
      Show_Help,
      Show_Version,
      --  The command line is wrong: its diagnostic has been written, and
      --  the usage line is due.
      Usage_Failure,
      --  A -f pattern file could not be read: its diagnostic has been
      --  written.
      Pattern_File_Failure);

   --  Parse Context's arguments into Config. A diagnostic for a failure is
   --  written to Context's standard error. With Outcome Search, Config
   --  holds at least one pattern unless every -e and -f gave none, which
   --  is an empty pattern list that matches nothing.
   procedure Parse
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Config  : out Invocation;
      Outcome : out Parse_Outcome);

   --  Whether the lines and counts of a search with Config name their file.
   function Needs_File_Prefix (Config : Invocation) return Boolean;
end Posix_Tools.Commands.Grep.Options;
