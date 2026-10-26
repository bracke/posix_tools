with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Streams.Stream_IO;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Hostkit.Fs;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Expr;
with Posix_Tools.Commands.Find;
with Posix_Tools.Commands.Printf;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Test_Command;
with Posix_Tools.Exit_Status;
with Test_Contexts;

package body Command_Tests.Scripting is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
   package Line_Sorting is new Line_Vectors.Generic_Sorting;

   type Word_List is array (Positive range <>) of Unbounded_String;

   EOL : constant Character := Character'Val (10);

   function "+" (Item : String) return Unbounded_String renames To_Unbounded_String;
   function Args (Words : Word_List) return Posix_Tools.Arguments.Vector;
   function Lines_Of (Text : String) return Line_Vectors.Vector;
   --  False where the host will not make symbolic links.
   function Make_Tree (Root : String) return Boolean;
   --  Remove Root without following the links in it, which loop.
   procedure Remove_Tree (Root : String);
   function Run_Find
     (Words  : Word_List;
      Status : out Posix_Tools.Exit_Status.Code;
      Errors : out Unbounded_String) return String;
   function Sorted (Text : String) return String;
   function Test_Status (Words : Word_List) return Posix_Tools.Exit_Status.Code;
   function Tree_Root return String;
   procedure Write_File (Path, Data : String);

   function Args (Words : Word_List) return Posix_Tools.Arguments.Vector is
   begin
      return Result : Posix_Tools.Arguments.Vector do
         for Word of Words loop
            Result.Append (To_String (Word));
         end loop;
      end return;
   end Args;

   function Lines_Of (Text : String) return Line_Vectors.Vector is
      Result : Line_Vectors.Vector;
      First  : Positive := Text'First;
   begin
      for I in Text'Range loop
         if Text (I) = EOL then
            Result.Append (Text (First .. I - 1));
            First := I + 1;
         end if;
      end loop;
      return Result;
   end Lines_Of;

   --  Root/d holds f, sub/g, loop -> ., lsub -> sub and dangle -> nowhere.
   function Make_Tree (Root : String) return Boolean is
      D : constant String := Root & "/d";
   begin
      Remove_Tree (Root);
      Ada.Directories.Create_Path (D & "/sub");
      Write_File (D & "/f", "f");
      Write_File (D & "/sub/g", "g");
      return Hostkit.Fs.Create_Link (".", D & "/loop")
        and then Hostkit.Fs.Create_Link ("sub", D & "/lsub")
        and then Hostkit.Fs.Create_Link ("nowhere", D & "/dangle");
   end Make_Tree;

   procedure Remove_Tree (Root : String) is
      use type Hostkit.Fs.Delete_Tree_Outcome;
   begin
      if Ada.Directories.Exists (Root) or else Hostkit.Fs.Is_Link (Root) then
         AUnit.Assertions.Assert
           (Hostkit.Fs.Delete_Tree_No_Follow (Root) = Hostkit.Fs.Tree_Deleted, "cleanup failed for " & Root);
      end if;
   end Remove_Tree;

   function Run_Find
     (Words  : Word_List;
      Status : out Posix_Tools.Exit_Status.Code;
      Errors : out Unbounded_String) return String
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("find", Args (Words));
      Posix_Tools.Commands.Find.Run (Context, Result);
      Status := Result.Status;
      Errors := +Test_Contexts.Error_Output (Context);
      return Test_Contexts.Output (Context);
   end Run_Find;

   --  The lines of Text in order, for a walk whose order the directory sets.
   function Sorted (Text : String) return String is
      Lines  : Line_Vectors.Vector := Lines_Of (Text);
      Result : Unbounded_String;
   begin
      Line_Sorting.Sort (Lines);
      for Line of Lines loop
         Append (Result, Line & EOL);
      end loop;
      return To_String (Result);
   end Sorted;

   procedure Test_Expr_Extension_Operands (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("expr", Args ([+"--help", +"=", +"--help"]));
      Posix_Tools.Commands.Expr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "1" & EOL,
         "expr compares --help as a string when it is not the sole argument");

      Context.Initialize ("expr", Args ([+"--version"]));
      Posix_Tools.Commands.Expr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Strings.Fixed.Index (Test_Contexts.Output (Context), "expr") /= 0,
         "expr --version alone is the project extension");
   end Test_Expr_Extension_Operands;

   procedure Test_Find_Exec_Batches (T : in out Fixture) is
      pragma Unreferenced (T);
      Root     : constant String := Tree_Root & "-exec";
      Name_Pad : constant String (1 .. 100) := [others => 'n'];
      Limit    : constant := 4_096;
      Status   : Posix_Tools.Exit_Status.Code;
      Errors   : Unbounded_String;
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
   begin
      Remove_Tree (Root);
      Ada.Directories.Create_Path (Root);
      for I in 1 .. 60 loop
         Write_File (Root & "/" & Name_Pad & Ada.Strings.Fixed.Trim (I'Image, Ada.Strings.Both), "x");
      end loop;

      --  A '+' that does not follow "{}" is an argument; ';' ends the -exec.
      declare
         Output : constant String :=
           Run_Find ([+(Root & "/" & Name_Pad & "1"), +"-exec", +"echo", +"+", +";"], Status, Errors);
      begin
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Exit_Status.Success and then Output = "+" & EOL,
            "find -exec takes a lone + as an argument");
      end;

      declare
         Output : constant String :=
           Run_Find ([+Root, +"-exec", +"echo", +"{}", +"x", +"+"], Status, Errors);
      begin
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Exit_Status.Invalid_Usage
            and then Output = ""
            and then To_String (Errors) = "find: missing option argument '-exec'" & EOL,
            "find -exec needs ; when + does not follow {}");
      end;

      --  An environment this large leaves the smallest {ARG_MAX} for the
      --  pathnames, so the 60 files take more than one invocation.
      Context.Initialize ("find", Args ([+Root, +"-type", +"f", +"-exec", +"echo", +"{}", +"+"]));
      Test_Contexts.Set_Environment_Value (Context, "BIG", [1 .. 130_000 => 'x']);
      Posix_Tools.Commands.Find.Run (Context, Result);
      declare
         Lines : constant Line_Vectors.Vector := Lines_Of (Test_Contexts.Output (Context));
         Seen  : Natural := 0;
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success and then Natural (Lines.Length) > 1,
            "find -exec {} + splits a long batch over invocations");
         for Line of Lines loop
            declare
               Size  : Natural := 4 + 9;
               First : Positive := Line'First;
            begin
               for I in Line'Range loop
                  if Line (I) = ' ' or else I = Line'Last then
                     Size := Size + (if Line (I) = ' ' then I - First else I - First + 1) + 9;
                     Seen := Seen + 1;
                     First := I + 1;
                  end if;
               end loop;
               AUnit.Assertions.Assert (Size <= Limit, "find -exec {} + keeps each invocation within the limit");
            end;
         end loop;
         AUnit.Assertions.Assert (Seen = 60, "find -exec {} + passes every pathname once");
      end;
      Remove_Tree (Root);
   end Test_Find_Exec_Batches;

   procedure Test_Find_Missing_Operands (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Tree_Root & "-missing";
      Missing : constant String := Root & "/absent";
      Status  : Posix_Tools.Exit_Status.Code;
      Errors  : Unbounded_String;
   begin
      if not Make_Tree (Root) then
         Remove_Tree (Root);
         return;
      end if;
      declare
         Output : constant String := Run_Find ([+Missing, +(Root & "/d/f")], Status, Errors);
      begin
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Exit_Status.Operational_Failure
            and then Output = Root & "/d/f" & EOL
            and then To_String (Errors) = "find: '" & Missing & "': no such file or directory" & EOL,
            "find diagnoses a missing path operand and goes on with the rest");
      end;

      --  A link to nothing exists as a link: it is a starting point.
      declare
         Output : constant String := Run_Find ([+(Root & "/d/dangle")], Status, Errors);
      begin
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Exit_Status.Success
            and then Output = Root & "/d/dangle" & EOL
            and then To_String (Errors) = "",
            "find takes a dangling link operand as a link");
      end;
      Remove_Tree (Root);
   end Test_Find_Missing_Operands;

   procedure Test_Find_Symbolic_Links (T : in out Fixture) is
      pragma Unreferenced (T);
      Root   : constant String := Tree_Root & "-links";
      D      : constant String := Root & "/d";
      Status : Posix_Tools.Exit_Status.Code;
      Errors : Unbounded_String;
   begin
      if not Make_Tree (Root) then
         Remove_Tree (Root);
         return;
      end if;

      AUnit.Assertions.Assert
        (Sorted (Run_Find ([+D], Status, Errors)) =
           D & EOL & D & "/dangle" & EOL & D & "/f" & EOL & D & "/loop" & EOL & D & "/lsub" & EOL
           & D & "/sub" & EOL & D & "/sub/g" & EOL
         and then Status = Posix_Tools.Exit_Status.Success,
         "find follows no link by default and lists links to nothing");

      AUnit.Assertions.Assert
        (Sorted (Run_Find ([+"-P", +D, +"-type", +"l"], Status, Errors)) =
           D & "/dangle" & EOL & D & "/loop" & EOL & D & "/lsub" & EOL,
         "find -P -type l is every link");

      AUnit.Assertions.Assert
        (Sorted (Run_Find ([+D, +"-type", +"d"], Status, Errors)) = D & EOL & D & "/sub" & EOL,
         "find -type d does not count a link to a directory");

      declare
         Output : constant String := Sorted (Run_Find ([+"-L", +D], Status, Errors));
      begin
         AUnit.Assertions.Assert
           (Output =
              D & EOL & D & "/dangle" & EOL & D & "/f" & EOL & D & "/lsub" & EOL & D & "/lsub/g" & EOL
              & D & "/sub" & EOL & D & "/sub/g" & EOL
            and then Status = Posix_Tools.Exit_Status.Operational_Failure
            and then To_String (Errors) = "find: '" & D & "/loop': file system loop detected" & EOL,
            "find -L follows links and diagnoses a loop");
      end;

      declare
         Output : constant String := Run_Find ([+"-L", +D, +"-type", +"l"], Status, Errors);
      begin
         AUnit.Assertions.Assert
           (Output = D & "/dangle" & EOL,
            "find -L -type l is only a link to nothing, not: " & Output & To_String (Errors));
      end;

      AUnit.Assertions.Assert
        (Sorted (Run_Find ([+"-H", +(D & "/lsub")], Status, Errors)) = D & "/lsub" & EOL & D & "/lsub/g" & EOL
         and then Run_Find ([+(D & "/lsub")], Status, Errors) = D & "/lsub" & EOL,
         "find -H follows a link named as an operand, -P does not");

      AUnit.Assertions.Assert
        (Run_Find ([+"-HL", +"-P", +(D & "/lsub")], Status, Errors) = D & "/lsub" & EOL,
         "find takes the last of -H, -L and -P");
      Remove_Tree (Root);
   end Test_Find_Symbolic_Links;

   procedure Test_Printf_Character_Conversion (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
   begin
      Context.Initialize ("printf", Args ([+"%c|%3c|", +(E_Acute & "x"), +E_Acute]));
      Test_Contexts.Set_Environment_Value (Context, "LC_CTYPE", "C.UTF-8");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = E_Acute & "| " & E_Acute & "|",
         "printf %c writes a whole UTF-8 character, its width counted in bytes");

      Context.Initialize ("printf", Args ([+"%c|", +E_Acute]));
      Test_Contexts.Set_Environment_Value (Context, "LC_ALL", "C");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#C3#) & "|",
         "printf %c writes the first byte in the C locale");
   end Test_Printf_Character_Conversion;

   procedure Test_Printf_Escapes (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("printf", Args ([+"\101\60\0\n"]));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A0" & Character'Val (0) & EOL,
         "printf format \ddd writes the byte of one to three octal digits");

      Context.Initialize ("printf", Args ([+"%b|%b|%b|%s", +"\0101", +"\101", +"x\cy", +"never"]));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A|A|x",
         "printf %b takes \0ddd and stops all output at \c");
   end Test_Printf_Escapes;

   procedure Test_Printf_Extension_Operands (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("printf", Args ([+"--help", +"x"]));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "--help",
         "printf uses --help as the format when other arguments follow");

      Context.Initialize ("printf", Args ([+"--help"]));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Strings.Fixed.Index (Test_Contexts.Output (Context), "printf") /= 0,
         "printf --help alone is the project extension");
   end Test_Printf_Extension_Operands;

   procedure Test_Printf_Numeric_Arguments (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      procedure Check (Words : Word_List; Output, Errors : String; Status : Posix_Tools.Exit_Status.Code;
                       Label : String);

      procedure Check (Words : Word_List; Output, Errors : String; Status : Posix_Tools.Exit_Status.Code;
                       Label : String) is
      begin
         Context.Initialize ("printf", Args (Words));
         Test_Contexts.Set_Environment_Value (Context, "LC_ALL", "C");
         Posix_Tools.Commands.Printf.Run (Context, Result);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Output
            and then Test_Contexts.Error_Output (Context) = Errors
            and then Result.Status = Status,
            Label);
      end Check;
   begin
      Check ([+"%d %x %o %i\n", +"0x10", +"010", +"-0X1f", +" +12"], "16 8 1777777777777777777741 12" & EOL, "",
             Posix_Tools.Exit_Status.Success, "printf reads hexadecimal and octal constants");
      Check ([+"%d %d %u", +"'A", +"""B", +"'"], "65 66 0", "printf: ''': expected a numeric value" & EOL,
             Posix_Tools.Exit_Status.Operational_Failure, "printf reads a quoted character as its value");
      Check ([+"%d|%x|%d", +"12abc", +"0x1g", +"7"], "12|1|7",
             "printf: '12abc': value not completely converted" & EOL
             & "printf: '0x1g': value not completely converted" & EOL,
             Posix_Tools.Exit_Status.Operational_Failure,
             "printf writes the value converted so far and goes on");
      Check ([+"%d", +"99999999999999999999"], "9223372036854775807",
             "printf: '99999999999999999999': numeric result out of range" & EOL,
             Posix_Tools.Exit_Status.Operational_Failure, "printf writes the nearest value out of range");
      Check ([+"%g %.1f %g %g", +"0x10", +"0x1.8p1", +"1e2", +"'A"], "16 3.0 100 65", "",
             Posix_Tools.Exit_Status.Success, "printf reads floating constants");
      Check ([+"%d", +""], "0", "", Posix_Tools.Exit_Status.Success, "printf takes an empty argument as zero");

      Context.Initialize
        ("printf", Args ([+"%d", +(Character'Val (39) & Character'Val (16#C3#) & Character'Val (16#A9#))]));
      Test_Contexts.Set_Environment_Value (Context, "LC_CTYPE", "C.UTF-8");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "233",
         "printf takes a quoted UTF-8 character's code point");
   end Test_Printf_Numeric_Arguments;

   function Test_Status (Words : Word_List) return Posix_Tools.Exit_Status.Code is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("test", Args (Words));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      return Result.Status;
   end Test_Status;

   procedure Test_Test_Argument_Counts (T : in out Fixture) is
      pragma Unreferenced (T);
      True_Status  : constant Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
      False_Status : constant Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Operational_Failure;
      Usage_Status : constant Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Invalid_Usage;
   begin
      AUnit.Assertions.Assert (Test_Status ([1 .. 0 => <>]) = False_Status, "test with no arguments is false");
      AUnit.Assertions.Assert (Test_Status ([1 => +"!"]) = True_Status, "test ! is a nonempty string");
      AUnit.Assertions.Assert (Test_Status ([1 => +"-a"]) = True_Status, "test -a is a nonempty string");
      AUnit.Assertions.Assert (Test_Status ([+"!", +""]) = True_Status, "test ! with two arguments negates");
      AUnit.Assertions.Assert (Test_Status ([+"x", +"=", +"-a"]) = False_Status, "test x = -a compares strings");
      AUnit.Assertions.Assert (Test_Status ([+"(", +"=", +"("]) = True_Status, "test ( = ( compares strings");
      AUnit.Assertions.Assert (Test_Status ([+"!", +"=", +"!"]) = True_Status, "test ! = ! compares strings");
      AUnit.Assertions.Assert (Test_Status ([+"x", +"-a", +""]) = False_Status, "test x -a '' is a binary -a");
      AUnit.Assertions.Assert (Test_Status ([+"!", +"-z", +"x"]) = True_Status, "test ! -z x negates");
      AUnit.Assertions.Assert (Test_Status ([+"(", +"", +")"]) = False_Status, "test ( '' ) groups");
      AUnit.Assertions.Assert
        (Test_Status ([+"!", +"x", +"=", +"y"]) = True_Status, "test ! x = y negates three arguments");
      AUnit.Assertions.Assert
        (Test_Status ([+"(", +"-n", +"x", +")"]) = True_Status, "test ( -n x ) groups two arguments");
      AUnit.Assertions.Assert
        (Test_Status ([+"a", +"=", +"a", +"-a", +"b", +"=", +"c"]) = False_Status, "test -a with five or more");
      AUnit.Assertions.Assert
        (Test_Status ([+"a", +"=", +"b", +"-o", +"x", +"-a", +""]) = False_Status, "test -a binds tighter than -o");
      AUnit.Assertions.Assert
        (Test_Status ([+"!", +"a", +"=", +"a", +"-o", +"b"]) = True_Status, "test ! binds tighter than -o");
      AUnit.Assertions.Assert
        (Test_Status ([+"(", +"a", +"-o", +"b", +")", +"-a", +""]) = False_Status, "test parentheses group");
      AUnit.Assertions.Assert (Test_Status ([+"a", +"b"]) = Usage_Status, "test a b is invalid");
      AUnit.Assertions.Assert
        (Test_Status ([+"a", +"=", +"a", +"-a"]) = Usage_Status, "test with a dangling -a is invalid");
   end Test_Test_Argument_Counts;

   procedure Test_Test_Extension_Operands (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("test", Args ([+"--help", +"=", +"x"]));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "test compares --help as a string when it is not the sole argument");

      Context.Initialize ("test", Args ([+"--help"]));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Strings.Fixed.Index (Test_Contexts.Output (Context), "test") /= 0,
         "test --help alone is the project extension");
   end Test_Test_Extension_Operands;

   procedure Test_Test_Integer_Operands (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("test", Args ([+"1", +"-lt", +"2", +"-a", +"abc", +"-gt", +"1"]));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Error_Output (Context) = "test: 'abc': integer expression expected" & EOL,
         "test diagnoses a non-integer operand of -gt and exits 2");

      Context.Initialize ("test", Args ([+"-3", +"-lt", +"+2"]));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Error_Output (Context) = "",
         "test compares signed integers");
   end Test_Test_Integer_Operands;

   function Tree_Root return String is
   begin
      return Ada.Directories.Full_Name ("generated/test-work") & "/scripting-find";
   end Tree_Root;

   procedure Write_File (Path, Data : String) is
      File : Ada.Streams.Stream_IO.File_Type;
   begin
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      String'Write (Ada.Streams.Stream_IO.Stream (File), Data);
      Ada.Streams.Stream_IO.Close (File);
   end Write_File;
end Command_Tests.Scripting;
