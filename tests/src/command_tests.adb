with Ada.Calendar;
with Ada.Directories;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with GNAT.OS_Lib;
with Hostkit.Fs;
with Hostkit.Metadata;
with Posix_Tools.Arguments;
with Posix_Tools.Command_Inventory;
with Posix_Tools.Commands.Arch;
with Posix_Tools.Commands.Basename;
with Posix_Tools.Commands.Cat;
with Posix_Tools.Commands.Chgrp;
with Posix_Tools.Commands.Chmod;
with Posix_Tools.Commands.Chown;
with Posix_Tools.Commands.Cksum;
with Posix_Tools.Commands.Cmp;
with Posix_Tools.Commands.Comm;
with Posix_Tools.Commands.Cp;
with Posix_Tools.Commands.Cut;
with Posix_Tools.Commands.Date;
with Posix_Tools.Commands.Dd;
with Posix_Tools.Commands.Df;
with Posix_Tools.Commands.Dirname;
with Posix_Tools.Commands.Du;
with Posix_Tools.Commands.Echo;
with Posix_Tools.Commands.Env;
with Posix_Tools.Commands.Expand;
with Posix_Tools.Commands.Expr;
with Posix_Tools.Commands.False_Command;
with Posix_Tools.Commands.File;
with Posix_Tools.Commands.Find;
with Posix_Tools.Commands.Fold;
with Posix_Tools.Commands.Getconf;
with Posix_Tools.Commands.Groups;
with Posix_Tools.Commands.Head;
with Posix_Tools.Commands.Hostname;
with Posix_Tools.Commands.Id;
with Posix_Tools.Commands.Kill;
with Posix_Tools.Commands.Link;
with Posix_Tools.Commands.Ln;
with Posix_Tools.Commands.Locale;
with Posix_Tools.Commands.Logname;
with Posix_Tools.Commands.Ls;
with Posix_Tools.Commands.Mkdir;
with Posix_Tools.Commands.Mkfifo;
with Posix_Tools.Commands.Mv;
with Posix_Tools.Commands.Nice;
with Posix_Tools.Commands.Nl;
with Posix_Tools.Commands.Nohup;
with Posix_Tools.Commands.Od;
with Posix_Tools.Commands.Paste;
with Posix_Tools.Commands.Pathchk;
with Posix_Tools.Commands.Printenv;
with Posix_Tools.Commands.Printf;
with Posix_Tools.Commands.Pwd;
with Posix_Tools.Commands.Readlink;
with Posix_Tools.Commands.Realpath;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rm;
with Posix_Tools.Commands.Rmdir;
with Posix_Tools.Commands.Root;
with Posix_Tools.Commands.Seq;
with Posix_Tools.Commands.Sha256sum;
with Posix_Tools.Commands.Sleep;
with Posix_Tools.Commands.Split;
with Posix_Tools.Commands.Sort;
with Posix_Tools.Commands.Stat;
with Posix_Tools.Commands.Tail;
with Posix_Tools.Commands.Tee;
with Posix_Tools.Commands.Test_Command;
with Posix_Tools.Commands.Timeout;
with Posix_Tools.Commands.Touch;
with Posix_Tools.Commands.Tr;
with Posix_Tools.Commands.True_Command;
with Posix_Tools.Commands.Tty;
with Posix_Tools.Commands.Unexpand;
with Posix_Tools.Commands.Unlink;
with Posix_Tools.Commands.Uname;
with Posix_Tools.Commands.Uniq;
with Posix_Tools.Commands.Wc;
with Posix_Tools.Commands.Which;
with Posix_Tools.Commands.Whoami;
with Posix_Tools.Commands.Xargs;
with Posix_Tools.Commands.Yes;
with Posix_Tools.Exit_Status;
with Posix_Tools.Help;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Localization;
with Posix_Tools.Paths;
with Posix_Tools.Presentation;
with Posix_Tools.Text.Matching;
with Posix_Tools.Version;
with Test_Contexts;
with Command_Tests.Surface_Smoke;

package body Command_Tests is
   use type Ada.Directories.File_Size;
   use type Ada.Directories.File_Kind;
   use type Hostkit.Fs.Special_File_Kind;
   use type Posix_Tools.Host_Adapters.Signals.Disposition;
   use type Posix_Tools.Exit_Status.Code;
   use Ada.Strings.Unbounded;

   function No_Args return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      return Result;
   end No_Args;

   function One_Arg (A : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      return Result;
   end One_Arg;

   function Two_Args (A, B : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      return Result;
   end Two_Args;

   function Three_Args (A, B, C : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      return Result;
   end Three_Args;

   function Four_Args (A, B, C, D : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      return Result;
   end Four_Args;

   function Five_Args (A, B, C, D, E : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      Result.Append (E);
      return Result;
   end Five_Args;

   function Six_Args (A, B, C, D, E, F : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      Result.Append (B);
      Result.Append (C);
      Result.Append (D);
      Result.Append (E);
      Result.Append (F);
      return Result;
   end Six_Args;

   function Fixture_Path (Name : String) return String is
   begin
      if Ada.Directories.Exists ("fixtures") then
         return "fixtures/" & Name;
      else
         return "../fixtures/" & Name;
      end if;
   end Fixture_Path;

   function Work_Path (Name : String) return String is
   begin
      return Hostkit.Fs.Join (Hostkit.Fs.Join ("generated", "test-work"), Name);
   end Work_Path;

   function Contains (Text, Pattern : String) return Boolean is
   begin
      return Posix_Tools.Text.Matching.Contains (Text, Pattern);
   end Contains;

   function Occurrences (Text, Pattern : String) return Natural is
      Count : Natural := 0;
      Index : Positive := Text'First;
   begin
      if Pattern = "" or else Text'Length < Pattern'Length then
         return 0;
      end if;

      while Index <= Text'Last - Pattern'Length + 1 loop
         if Text (Index .. Index + Pattern'Length - 1) = Pattern then
            Count := Count + 1;
            Index := Index + Pattern'Length;
         else
            Index := Index + 1;
         end if;
      end loop;

      return Count;
   end Occurrences;

   procedure Run_Command_By_Name
     (Name    : String;
      Context : in out Test_Contexts.Capturing_Context;
      Result  : out Posix_Tools.Commands.Results.Result) is
   begin
      if Name = "arch" then
         Posix_Tools.Commands.Arch.Run (Context, Result);
      elsif Name = "awk" then
         if Context.Argument_Count = 1 and then Context.Argument (1) = "--help" then
            Posix_Tools.Help.Render_Command_Help (Context, "awk");
            Result.Status := Posix_Tools.Exit_Status.Success;
         elsif Context.Argument_Count = 1 and then Context.Argument (1) = "--version" then
            Posix_Tools.Help.Render_Version (Context, "awk");
            Result.Status := Posix_Tools.Exit_Status.Success;
         elsif Context.Argument_Count = 1
           and then Context.Argument (1) = "--posix-tools-identify"
         then
            Posix_Tools.Help.Render_Identity (Context, "awk");
            Result.Status := Posix_Tools.Exit_Status.Success;
         else
            AUnit.Assertions.Assert (False, "awk is not context-dispatched");
         end if;
      elsif Name = "basename" then
         Posix_Tools.Commands.Basename.Run (Context, Result);
      elsif Name = "cat" then
         Posix_Tools.Commands.Cat.Run (Context, Result);
      elsif Name = "chgrp" then
         Posix_Tools.Commands.Chgrp.Run (Context, Result);
      elsif Name = "chmod" then
         Posix_Tools.Commands.Chmod.Run (Context, Result);
      elsif Name = "chown" then
         Posix_Tools.Commands.Chown.Run (Context, Result);
      elsif Name = "cksum" then
         Posix_Tools.Commands.Cksum.Run (Context, Result);
      elsif Name = "cmp" then
         Posix_Tools.Commands.Cmp.Run (Context, Result);
      elsif Name = "comm" then
         Posix_Tools.Commands.Comm.Run (Context, Result);
      elsif Name = "cp" then
         Posix_Tools.Commands.Cp.Run (Context, Result);
      elsif Name = "cut" then
         Posix_Tools.Commands.Cut.Run (Context, Result);
      elsif Name = "date" then
         Posix_Tools.Commands.Date.Run (Context, Result);
      elsif Name = "dd" then
         Posix_Tools.Commands.Dd.Run (Context, Result);
      elsif Name = "df" then
         Posix_Tools.Commands.Df.Run (Context, Result);
      elsif Name = "dirname" then
         Posix_Tools.Commands.Dirname.Run (Context, Result);
      elsif Name = "du" then
         Posix_Tools.Commands.Du.Run (Context, Result);
      elsif Name = "echo" then
         Posix_Tools.Commands.Echo.Run (Context, Result);
      elsif Name = "env" then
         Posix_Tools.Commands.Env.Run (Context, Result);
      elsif Name = "expand" then
         Posix_Tools.Commands.Expand.Run (Context, Result);
      elsif Name = "expr" then
         Posix_Tools.Commands.Expr.Run (Context, Result);
      elsif Name = "false" then
         Posix_Tools.Commands.False_Command.Run (Context, Result);
      elsif Name = "file" then
         Posix_Tools.Commands.File.Run (Context, Result);
      elsif Name = "find" then
         Posix_Tools.Commands.Find.Run (Context, Result);
      elsif Name = "fold" then
         Posix_Tools.Commands.Fold.Run (Context, Result);
      elsif Name = "getconf" then
         Posix_Tools.Commands.Getconf.Run (Context, Result);
      elsif Name = "groups" then
         Posix_Tools.Commands.Groups.Run (Context, Result);
      elsif Name = "head" then
         Posix_Tools.Commands.Head.Run (Context, Result);
      elsif Name = "hostname" then
         Posix_Tools.Commands.Hostname.Run (Context, Result);
      elsif Name = "id" then
         Posix_Tools.Commands.Id.Run (Context, Result);
      elsif Name = "kill" then
         Posix_Tools.Commands.Kill.Run (Context, Result);
      elsif Name = "link" then
         Posix_Tools.Commands.Link.Run (Context, Result);
      elsif Name = "ln" then
         Posix_Tools.Commands.Ln.Run (Context, Result);
      elsif Name = "locale" then
         Posix_Tools.Commands.Locale.Run (Context, Result);
      elsif Name = "logname" then
         Posix_Tools.Commands.Logname.Run (Context, Result);
      elsif Name = "ls" then
         Posix_Tools.Commands.Ls.Run (Context, Result);
      elsif Name = "mkdir" then
         Posix_Tools.Commands.Mkdir.Run (Context, Result);
      elsif Name = "mkfifo" then
         Posix_Tools.Commands.Mkfifo.Run (Context, Result);
      elsif Name = "mv" then
         Posix_Tools.Commands.Mv.Run (Context, Result);
      elsif Name = "nice" then
         Posix_Tools.Commands.Nice.Run (Context, Result);
      elsif Name = "nl" then
         Posix_Tools.Commands.Nl.Run (Context, Result);
      elsif Name = "nohup" then
         Posix_Tools.Commands.Nohup.Run (Context, Result);
      elsif Name = "od" then
         Posix_Tools.Commands.Od.Run (Context, Result);
      elsif Name = "paste" then
         Posix_Tools.Commands.Paste.Run (Context, Result);
      elsif Name = "pathchk" then
         Posix_Tools.Commands.Pathchk.Run (Context, Result);
      elsif Name = "printenv" then
         Posix_Tools.Commands.Printenv.Run (Context, Result);
      elsif Name = "printf" then
         Posix_Tools.Commands.Printf.Run (Context, Result);
      elsif Name = "pwd" then
         Posix_Tools.Commands.Pwd.Run (Context, Result);
      elsif Name = "readlink" then
         Posix_Tools.Commands.Readlink.Run (Context, Result);
      elsif Name = "realpath" then
         Posix_Tools.Commands.Realpath.Run (Context, Result);
      elsif Name = "rm" then
         Posix_Tools.Commands.Rm.Run (Context, Result);
      elsif Name = "rmdir" then
         Posix_Tools.Commands.Rmdir.Run (Context, Result);
      elsif Name = "seq" then
         Posix_Tools.Commands.Seq.Run (Context, Result);
      elsif Name = "sed" then
         if Context.Argument_Count = 1 and then Context.Argument (1) = "--help" then
            Posix_Tools.Help.Render_Command_Help (Context, "sed");
            Result.Status := Posix_Tools.Exit_Status.Success;
         elsif Context.Argument_Count = 1 and then Context.Argument (1) = "--version" then
            Posix_Tools.Help.Render_Version (Context, "sed");
            Result.Status := Posix_Tools.Exit_Status.Success;
         elsif Context.Argument_Count = 1
           and then Context.Argument (1) = "--posix-tools-identify"
         then
            Posix_Tools.Help.Render_Identity (Context, "sed");
            Result.Status := Posix_Tools.Exit_Status.Success;
         else
            AUnit.Assertions.Assert (False, "sed is not context-dispatched");
         end if;
      elsif Name = "sha256sum" then
         Posix_Tools.Commands.Sha256sum.Run (Context, Result);
      elsif Name = "sleep" then
         Posix_Tools.Commands.Sleep.Run (Context, Result);
      elsif Name = "split" then
         Posix_Tools.Commands.Split.Run (Context, Result);
      elsif Name = "sort" then
         Posix_Tools.Commands.Sort.Run (Context, Result);
      elsif Name = "stat" then
         Posix_Tools.Commands.Stat.Run (Context, Result);
      elsif Name = "tail" then
         Posix_Tools.Commands.Tail.Run (Context, Result);
      elsif Name = "tee" then
         Posix_Tools.Commands.Tee.Run (Context, Result);
      elsif Name = "test" then
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
      elsif Name = "timeout" then
         Posix_Tools.Commands.Timeout.Run (Context, Result);
      elsif Name = "touch" then
         Posix_Tools.Commands.Touch.Run (Context, Result);
      elsif Name = "tr" then
         Posix_Tools.Commands.Tr.Run (Context, Result);
      elsif Name = "true" then
         Posix_Tools.Commands.True_Command.Run (Context, Result);
      elsif Name = "tty" then
         Posix_Tools.Commands.Tty.Run (Context, Result);
      elsif Name = "unexpand" then
         Posix_Tools.Commands.Unexpand.Run (Context, Result);
      elsif Name = "unlink" then
         Posix_Tools.Commands.Unlink.Run (Context, Result);
      elsif Name = "uname" then
         Posix_Tools.Commands.Uname.Run (Context, Result);
      elsif Name = "uniq" then
         Posix_Tools.Commands.Uniq.Run (Context, Result);
      elsif Name = "wc" then
         Posix_Tools.Commands.Wc.Run (Context, Result);
      elsif Name = "which" then
         Posix_Tools.Commands.Which.Run (Context, Result);
      elsif Name = "whoami" then
         Posix_Tools.Commands.Whoami.Run (Context, Result);
      elsif Name = "xargs" then
         Posix_Tools.Commands.Xargs.Run (Context, Result);
      elsif Name = "yes" then
         Posix_Tools.Commands.Yes.Run (Context, Result);
      else
         AUnit.Assertions.Assert (False, "unknown command inventory entry " & Name);
      end if;
   end Run_Command_By_Name;

   procedure Assert_Inventory_Status_Lines (Output_Text, Label : String) is
      LF       : constant Character := Character'Val (10);
      Position : Natural := Output_Text'First;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Prefix : constant String :=
              Posix_Tools.Command_Inventory.Executable (Index) & ": ";
         begin
            AUnit.Assertions.Assert
              (Position <= Output_Text'Last,
               Label & " missing line for " & Posix_Tools.Command_Inventory.Executable (Index));
            AUnit.Assertions.Assert
              (Position + Prefix'Length - 1 <= Output_Text'Last
               and then Output_Text (Position .. Position + Prefix'Length - 1) = Prefix,
               Label & " prefix for " & Posix_Tools.Command_Inventory.Executable (Index));

            while Position <= Output_Text'Last and then Output_Text (Position) /= LF loop
               Position := Position + 1;
            end loop;

            AUnit.Assertions.Assert
              (Position <= Output_Text'Last and then Output_Text (Position) = LF,
               Label & " line terminator for " & Posix_Tools.Command_Inventory.Executable (Index));
            Position := Position + 1;
         end;
      end loop;

      AUnit.Assertions.Assert
        (Position = Output_Text'Last + 1,
         Label & " extra output after inventory lines");
   end Assert_Inventory_Status_Lines;

   function Inventory_List_Output return String is
      Expected : Ada.Strings.Unbounded.Unbounded_String;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Ada.Strings.Unbounded.Append
           (Expected,
            Posix_Tools.Command_Inventory.Executable (Index) & Character'Val (10));
      end loop;

      return Ada.Strings.Unbounded.To_String (Expected);
   end Inventory_List_Output;

   procedure Write_File (Path, Data : String) is
      use type Ada.Streams.Stream_Element_Offset;
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Data'Length));
      Target : Ada.Streams.Stream_Element_Offset := Buffer'First;
   begin
      if Data'Length = 0 then
         Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
         Ada.Streams.Stream_IO.Close (File);
         return;
      end if;

      for I in Data'Range loop
         Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Data (I)));
         Target := Target + Ada.Streams.Stream_Element_Offset (1);
      end loop;

      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
      Ada.Streams.Stream_IO.Write (File, Buffer);
      Ada.Streams.Stream_IO.Close (File);
   end Write_File;

   procedure Test_Command_Surface_Smoke (T : in out Fixture) is
   begin
      Command_Tests.Surface_Smoke.Test_Command_Surface_Smoke (T);
   end Test_Command_Surface_Smoke;

   procedure Test_Xargs_Status_Bands (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("xargs", One_Arg ("false"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Xargs_Utility_Failed,
         "xargs maps utility status 1 through 125 to 123");

      Context.Initialize ("xargs", One_Arg ("xargs-status-255"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Xargs_Utility_Requested_Stop,
         "xargs maps utility status 255 to 124");

      Context.Initialize ("xargs", One_Arg ("xargs-cannot-invoke"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Cannot_Invoke,
         "xargs maps utility status 126 to 126");

      Context.Initialize ("xargs", One_Arg ("xargs-status-127"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "xargs maps utility status 127 to 127");

      Context.Initialize ("xargs", One_Arg ("missing-utility"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "xargs maps missing utility to 127");
   end Test_Xargs_Status_Bands;

   procedure Test_Pathchk (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
      Long_Component : constant String (1 .. 260) := (others => 'a');
   begin
      Context.Initialize ("pathchk", One_Arg ("portable/name_1.2"));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pathchk accepts ordinary path");
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "pathchk success output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "pathchk success diagnostics");

      Context.Initialize ("pathchk", Two_Args ("-p", "portable_1.2"));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pathchk -p accepts portable name");

      Context.Initialize ("pathchk", Two_Args ("-p", "bad@name"));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "pathchk -p rejects non-portable characters");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "pathchk: 'bad@name': non-portable character" & LF,
         "pathchk non-portable diagnostic");

      Context.Initialize ("pathchk", One_Arg (""));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "pathchk rejects empty pathname");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "pathchk: '': empty pathname" & LF,
         "pathchk empty diagnostic");

      Context.Initialize ("pathchk", One_Arg (Long_Component));
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "pathchk rejects long component");

      declare
         Capacity : constant Hostkit.Metadata.Volume_Capacity := Hostkit.Metadata.Volume_Capacity_Of (".");
      begin
         if Capacity.Available and then Capacity.Name_Max_Known and then Capacity.Name_Max < 1024 then
            declare
               Too_Long : constant String (1 .. Capacity.Name_Max + 1) := (others => 'b');
            begin
               Context.Initialize ("pathchk", One_Arg (Too_Long));
               Posix_Tools.Commands.Pathchk.Run (Context, Result);
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
                  "pathchk rejects host-reported name_max overflow");
            end;
         end if;
      end;

      Context.Initialize ("pathchk", No_Args);
      Posix_Tools.Commands.Pathchk.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "pathchk rejects missing operands");
   end Test_Pathchk;

   procedure Test_Expr (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);

      procedure Run_Case
        (Arguments       : Posix_Tools.Arguments.Vector;
         Expected_Output : String;
         Expected_Status : Posix_Tools.Exit_Status.Code;
         Label           : String) is
      begin
         Context.Initialize ("expr", Arguments);
         Posix_Tools.Commands.Expr.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Expected_Status, Label & " status");
         AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected_Output, Label & " output");
      end Run_Case;
   begin
      Run_Case (One_Arg ("value"), "value" & LF, Posix_Tools.Exit_Status.Success, "expr literal");
      Run_Case (Five_Args ("1", "+", "2", "*", "3"), "7" & LF, Posix_Tools.Exit_Status.Success,
                "expr arithmetic precedence");
      Run_Case (Three_Args ("4", "<", "3"), "0" & LF, Posix_Tools.Exit_Status.Operational_Failure,
                "expr false comparison");
      Run_Case (Three_Args ("0", "|", "fallback"), "fallback" & LF, Posix_Tools.Exit_Status.Success,
                "expr boolean or");
      Run_Case (Three_Args ("yes", "&", "ok"), "yes" & LF, Posix_Tools.Exit_Status.Success,
                "expr boolean and");
      Run_Case (Three_Args ("abcdef", ":", "abc.*"), "6" & LF, Posix_Tools.Exit_Status.Success,
                "expr regex length");
      Run_Case (Three_Args ("abc", ":", "a(b.)"), "bc" & LF, Posix_Tools.Exit_Status.Success,
                "expr regex capture");
      Run_Case (Three_Args ("abc", ":", "a.c"), "3" & LF, Posix_Tools.Exit_Status.Success,
                "expr BRE dot");
      Run_Case (Three_Args ("aaab", ":", "a*b"), "4" & LF, Posix_Tools.Exit_Status.Success,
                "expr BRE star");
      Run_Case (Three_Args ("b", ":", "[a-c]"), "1" & LF, Posix_Tools.Exit_Status.Success,
                "expr BRE bracket range");
      Run_Case (Three_Args ("7", ":", "[[:digit:]]"), "1" & LF, Posix_Tools.Exit_Status.Success,
                "expr BRE named class");
      Run_Case (Three_Args ("g", ":", "[^[:digit:]]"), "1" & LF, Posix_Tools.Exit_Status.Success,
                "expr BRE negated named class");
      Run_Case (Three_Args ("a", ":", "[[=a=]]"), "1" & LF, Posix_Tools.Exit_Status.Success,
                "expr BRE equivalence class");
      Run_Case (Three_Args ("chord", ":", "[[.ch.]]"), "2" & LF, Posix_Tools.Exit_Status.Success,
                "expr BRE multi-character collating element");
      Run_Case (Three_Args ("abc", ":", "a\(b.\)"), "bc" & LF, Posix_Tools.Exit_Status.Success,
                "expr BRE escaped capture");
      Run_Case (Two_Args ("length", "abc"), "3" & LF, Posix_Tools.Exit_Status.Success,
                "expr length");
      Run_Case (Three_Args ("index", "abc", "cb"), "2" & LF, Posix_Tools.Exit_Status.Success,
                "expr index");
      Run_Case (Four_Args ("substr", "abcde", "2", "3"), "bcd" & LF, Posix_Tools.Exit_Status.Success,
                "expr substr");

      Context.Initialize ("expr", No_Args);
      Posix_Tools.Commands.Expr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "expr rejects missing expression");

      Context.Initialize ("expr", Three_Args ("1", "+", "x"));
      Posix_Tools.Commands.Expr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "expr rejects non-numeric arithmetic operand");
   end Test_Expr;

   procedure Test_File (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Text_Path : constant String := Fixture_Path ("file-text.txt");
      Data_Path : constant String := Fixture_Path ("file-data.bin");
      Empty_Path : constant String := Fixture_Path ("file-empty.bin");
      Dir_Path : constant String := Fixture_Path ("file-dir");
      Png_Path : constant String := Fixture_Path ("file-image.png");
      Zip_Path : constant String := Fixture_Path ("file-archive.zip");
      Script_Path : constant String := Fixture_Path ("file-script.sh");
      Tar_Path : constant String := Fixture_Path ("file-archive.tar");
      Magic_Path : constant String := Fixture_Path ("file.magic");
      Magic_Data_Path : constant String := Fixture_Path ("file-magic-data.bin");
      Missing_Path : constant String := Fixture_Path ("file-missing.txt");
      LF : constant Character := Character'Val (10);

      procedure Delete_If_Exists (Path : String) is
      begin
         if Ada.Directories.Exists (Path) then
            if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
               Ada.Directories.Delete_Tree (Path);
            else
               Ada.Directories.Delete_File (Path);
            end if;
         end if;
      end Delete_If_Exists;
   begin
      Delete_If_Exists (Text_Path);
      Delete_If_Exists (Data_Path);
      Delete_If_Exists (Empty_Path);
      Delete_If_Exists (Dir_Path);
      Delete_If_Exists (Png_Path);
      Delete_If_Exists (Zip_Path);
      Delete_If_Exists (Script_Path);
      Delete_If_Exists (Tar_Path);
      Delete_If_Exists (Magic_Path);
      Delete_If_Exists (Magic_Data_Path);

      Write_File (Text_Path, "hello" & LF);
      Write_File (Data_Path, "a" & Character'Val (0) & "b");
      Write_File (Empty_Path, "");
      Write_File (Png_Path, Character'Val (16#89#) & "PNG" & Character'Val (13) & LF
                  & Character'Val (16#1A#) & LF);
      Write_File (Zip_Path, "PK" & Character'Val (3) & Character'Val (4) & "rest");
      Write_File (Script_Path, "#!/bin/sh" & LF & "echo ok" & LF);
      Write_File (Tar_Path, String'(1 .. 257 => Character'Val (0)) & "ustar");
      Write_File (Magic_Path, "0:AB\x00:custom binary:application/x-custom" & LF);
      Write_File (Magic_Data_Path, "AB" & Character'Val (0) & "tail");
      if not Ada.Directories.Exists (Dir_Path) then
         Ada.Directories.Create_Directory (Dir_Path);
      end if;

      Context.Initialize ("file", Four_Args (Text_Path, Data_Path, Empty_Path, Dir_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "file classifies readable operands successfully");
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Text_Path & ": text" & LF
           & Data_Path & ": data" & LF
           & Empty_Path & ": empty" & LF
         & Dir_Path & ": directory" & LF,
         "file classification output");

      Context.Initialize ("file", Four_Args (Png_Path, Zip_Path, Script_Path, Tar_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           Png_Path & ": PNG image data" & LF
           & Zip_Path & ": Zip archive data" & LF
           & Script_Path & ": script text executable" & LF
           & Tar_Path & ": tar archive data" & LF,
         "file applies built-in content signatures");

      Context.Initialize ("file", Two_Args ("-i", Png_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Png_Path & ": image/png" & LF,
         "file -i emits MIME classification");

      Context.Initialize ("file", One_Arg ("-"));
      Test_Contexts.Set_Standard_Input (Context, "%PDF-1.7" & LF);
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "-: PDF document" & LF,
         "file classifies standard input operand");

      Context.Initialize ("file", Three_Args ("-m", Magic_Path, Magic_Data_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Magic_Data_Path & ": custom binary" & LF,
         "file applies external magic-file descriptions");

      Context.Initialize ("file", Four_Args ("-i", "-m", Magic_Path, Magic_Data_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Magic_Data_Path & ": application/x-custom" & LF,
         "file applies external magic-file MIME descriptions");

      Context.Initialize ("file", One_Arg (Missing_Path));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "file reports missing operand path as operational failure");
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "",
         "file missing path has no data output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "file: '" & Missing_Path & "': cannot open file" & LF,
         "file missing diagnostic");

      Context.Initialize ("file", No_Args);
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "file rejects missing operands");

      Context.Initialize ("file", One_Arg ("-z"));
      Posix_Tools.Commands.File.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "file rejects unknown options");

      Delete_If_Exists (Text_Path);
      Delete_If_Exists (Data_Path);
      Delete_If_Exists (Empty_Path);
      Delete_If_Exists (Dir_Path);
      Delete_If_Exists (Png_Path);
      Delete_If_Exists (Zip_Path);
      Delete_If_Exists (Script_Path);
      Delete_If_Exists (Tar_Path);
      Delete_If_Exists (Magic_Path);
      Delete_If_Exists (Magic_Data_Path);
   end Test_File;

   procedure Test_Du (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Work_Root    : constant String := Work_Path ("du");
      Small_Path   : constant String := Hostkit.Fs.Join (Work_Root, "du-small.bin");
      Large_Path   : constant String := Hostkit.Fs.Join (Work_Root, "du-large.bin");
      Dir_Path     : constant String := Hostkit.Fs.Join (Work_Root, "du-dir");
      Child_Path   : constant String := Hostkit.Fs.Join (Dir_Path, "child.bin");
      Missing_Path : constant String := Hostkit.Fs.Join (Work_Root, "du-missing.bin");
      LF           : constant Character := Character'Val (10);
      HT           : constant Character := Character'Val (9);

      procedure Delete_If_Exists (Path : String) is
      begin
         if Ada.Directories.Exists (Path) then
            if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
               Ada.Directories.Delete_Tree (Path);
            else
               Ada.Directories.Delete_File (Path);
            end if;
         end if;
      end Delete_If_Exists;
   begin
      Delete_If_Exists (Work_Root);
      Ada.Directories.Create_Path (Work_Root);

      Write_File (Small_Path, "x");
      Write_File (Large_Path, String'(1 .. 1025 => 'x'));
      Ada.Directories.Create_Directory (Dir_Path);
      Write_File (Child_Path, "child");

      Context.Initialize ("du", One_Arg (Small_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1" & HT & Small_Path & LF,
         "du reports top-level regular file");

      Context.Initialize ("du", Two_Args ("-k", Large_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "2" & HT & Large_Path & LF,
         "du -k reports KiB-rounded units");

      Context.Initialize ("du", Two_Args ("-a", Dir_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), HT & Child_Path & LF)
         and then Contains (Test_Contexts.Output (Context), HT & Dir_Path & LF),
         "du -a reports child and directory paths");

      Context.Initialize ("du", Two_Args ("-s", Dir_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), HT & Dir_Path & LF)
         and then not Contains (Test_Contexts.Output (Context), HT & Child_Path & LF),
         "du -s reports only the top-level directory summary");

      Context.Initialize ("du", Two_Args (Dir_Path, Dir_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Occurrences (Test_Contexts.Output (Context), HT & Dir_Path & LF) = 2,
         "du resets cycle tracking for each top-level operand");

      Context.Initialize ("du", One_Arg (Missing_Path));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "du reports missing path as operational failure");

      Context.Initialize ("du", One_Arg ("-z"));
      Posix_Tools.Commands.Du.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "du rejects unknown options");

      Delete_If_Exists (Work_Root);
   end Test_Du;

   procedure Test_Fold (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("fold-input.txt");
      Missing : constant String := Fixture_Path ("fold-missing.txt");
      LF      : constant Character := Character'Val (10);
      Wide    : constant String := Character'Val (16#E4#) & Character'Val (16#B8#) & Character'Val (16#AD#);

      procedure Delete_If_Exists (Name : String) is
      begin
         if Ada.Directories.Exists (Name) then
            Ada.Directories.Delete_File (Name);
         end if;
      end Delete_If_Exists;
   begin
      Context.Initialize ("fold", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdefghijklmnopqrstuvwxyz");
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abcdefghijklmnopqrstuvwxyz",
         "fold leaves short standard input unchanged");

      Context.Initialize ("fold", Two_Args ("-w", "5"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghijkl");
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abcde" & LF & "fghij" & LF & "kl",
         "fold -w wraps standard input");

      Context.Initialize ("fold", Two_Args ("-w", "4"));
      Test_Contexts.Set_Standard_Input (Context, Wide & Wide & "x");
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Wide & Wide & LF & "x",
         "fold wraps by display columns without splitting UTF-8 sequences");

      Context.Initialize ("fold", Two_Args ("-w4", Path));
      Delete_If_Exists (Path);
      Write_File (Path, "abcd" & LF & "efghi" & LF);
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abcd" & LF & "efgh" & LF & "i" & LF,
         "fold reads and wraps file operands");

      Context.Initialize ("fold", Three_Args ("-s", "-w", "8"));
      Test_Contexts.Set_Standard_Input (Context, "alpha beta gamma");
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "alpha " & LF & "beta " & LF & "gamma",
         "fold -s breaks at blanks");

      Context.Initialize ("fold", Two_Args ("-w", "0"));
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "fold rejects zero width");

      Context.Initialize ("fold", One_Arg (Missing));
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "fold reports missing file");

      Context.Initialize ("fold", Two_Args ("-w", "4"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Fold.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "fold returns operational failure after output failure");

      Delete_If_Exists (Path);
   end Test_Fold;

   procedure Test_Expand (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("expand-input.txt");
      Missing : constant String := Fixture_Path ("expand-missing.txt");
      LF      : constant Character := Character'Val (10);
      HT      : constant Character := Character'Val (9);
      BS      : constant Character := Character'Val (8);
      Wide    : constant String := Character'Val (16#E4#) & Character'Val (16#B8#) & Character'Val (16#AD#);
      Acute   : constant String := Character'Val (16#CC#) & Character'Val (16#81#);

      procedure Delete_If_Exists (Name : String) is
      begin
         if Ada.Directories.Exists (Name) then
            Ada.Directories.Delete_File (Name);
         end if;
      end Delete_If_Exists;
   begin
      Context.Initialize ("expand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & HT & "b");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a       b",
         "expand uses default eight-column tab stops");

      Context.Initialize ("expand", Two_Args ("-t", "4"));
      Test_Contexts.Set_Standard_Input (Context, "ab" & HT & "c" & LF & HT & "d");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab  c" & LF & "    d",
         "expand -t changes the tab width and resets after newline");

      Context.Initialize ("expand", Two_Args ("-t", "3,6"));
      Test_Contexts.Set_Standard_Input (Context, "a" & HT & "b" & HT & "c");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a  b  c",
         "expand supports comma-separated tab stop lists");

      Context.Initialize ("expand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, Wide & HT & "x" & LF & "e" & Acute & HT & "x");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Wide & "      x" & LF & "e" & Acute & "       x",
         "expand uses display columns for wide and combining UTF-8");

      Context.Initialize ("expand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc" & BS & HT & "x");
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abc" & BS & "      x",
         "expand treats backspace as moving one display column left");

      Delete_If_Exists (Path);
      Write_File (Path, "x" & HT & "y");
      Context.Initialize ("expand", Two_Args ("-t4", Path));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "x   y",
         "expand reads file operands");

      Context.Initialize ("expand", One_Arg ("-t4,3"));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "expand rejects non-increasing tab stop lists");

      Context.Initialize ("expand", Two_Args ("-t", "0"));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "expand rejects zero tab width");

      Context.Initialize ("expand", One_Arg (Missing));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "expand reports missing file");

      Context.Initialize ("expand", One_Arg ("-t4"));
      Test_Contexts.Set_Standard_Input (Context, "a" & HT);
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "expand returns operational failure after output failure");

      Delete_If_Exists (Path);
   end Test_Expand;

   procedure Test_Unexpand (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("unexpand-input.txt");
      Missing : constant String := Fixture_Path ("unexpand-missing.txt");
      LF      : constant Character := Character'Val (10);
      HT      : constant Character := Character'Val (9);
      Wide    : constant String := Character'Val (16#E4#) & Character'Val (16#B8#) & Character'Val (16#AD#);

      procedure Delete_If_Exists (Name : String) is
      begin
         if Ada.Directories.Exists (Name) then
            Ada.Directories.Delete_File (Name);
         end if;
      end Delete_If_Exists;
   begin
      Context.Initialize ("unexpand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "        x");
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = HT & "x",
         "unexpand compresses leading blanks by default");

      Context.Initialize ("unexpand", One_Arg ("-a"));
      Test_Contexts.Set_Standard_Input (Context, "x       y");
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "x" & HT & "y",
         "unexpand -a compresses non-leading blanks");

      Context.Initialize ("unexpand", Two_Args ("-a", "-t3,6"));
      Test_Contexts.Set_Standard_Input (Context, "   x  y");
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = HT & "x" & HT & "y",
         "unexpand supports comma-separated tab stop lists");

      Context.Initialize ("unexpand", One_Arg ("-a"));
      Test_Contexts.Set_Standard_Input (Context, Wide & "      x");
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Wide & HT & "x",
         "unexpand uses display columns for wide UTF-8");

      Delete_If_Exists (Path);
      Write_File (Path, "    x" & LF & "  y");
      Context.Initialize ("unexpand", Two_Args ("-t4", Path));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = HT & "x" & LF & "  y",
         "unexpand reads file operands and honors tab width");

      Context.Initialize ("unexpand", One_Arg ("-t4,3"));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "unexpand rejects non-increasing tab stop lists");

      Context.Initialize ("unexpand", Two_Args ("-t", "0"));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "unexpand rejects zero tab width");

      Context.Initialize ("unexpand", One_Arg (Missing));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "unexpand reports missing file");

      Context.Initialize ("unexpand", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "    x");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "unexpand returns operational failure after output failure");

      Delete_If_Exists (Path);
   end Test_Unexpand;

   procedure Test_Timeout_Statuses (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Args    : Posix_Tools.Arguments.Vector;
   begin
      Context.Initialize ("timeout", Two_Args ("1s", "timeout-ok"));
      Posix_Tools.Commands.Timeout.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "done" & Character'Val (10),
         "timeout propagates successful utility output and status");

      Context.Initialize ("timeout", Two_Args ("1", "timeout-status-7"));
      Posix_Tools.Commands.Timeout.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Code (7),
         "timeout propagates ordinary utility status");

      Context.Initialize ("timeout", Two_Args ("1", "timeout-slow"));
      Posix_Tools.Commands.Timeout.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Code (124),
         "timeout maps elapsed timeout to 124");

      Args.Append ("--preserve-status");
      Args.Append ("1");
      Args.Append ("timeout-slow");
      Context.Initialize ("timeout", Args);
      Posix_Tools.Commands.Timeout.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Code (124),
         "timeout preserve-status keeps adapter timeout status when supplied");

      Context.Initialize ("timeout", One_Arg ("1"));
      Posix_Tools.Commands.Timeout.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "timeout rejects missing utility operand");

      Context.Initialize ("timeout", Two_Args ("bad", "timeout-ok"));
      Posix_Tools.Commands.Timeout.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "timeout rejects invalid duration");

      Context.Initialize ("timeout", Two_Args ("999999999999999999999999999999999999999", "timeout-ok"));
      Posix_Tools.Commands.Timeout.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "timeout rejects overflowing duration");
   end Test_Timeout_Statuses;

   procedure Test_Env_Utility_Status (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("env", Two_Args ("-i", "false"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "env propagates utility status 1");

      Context.Initialize ("env", Two_Args ("-i", "xargs-cannot-invoke"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Cannot_Invoke,
         "env maps utility status 126 to 126");

      Context.Initialize ("env", Two_Args ("-i", "xargs-status-127"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "env maps utility status 127 to 127");

      Context.Initialize ("env", Two_Args ("-i", "missing-utility"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "env maps missing utility to 127");
   end Test_Env_Utility_Status;

   procedure Test_Command_Verbose_Output_Failures (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Source  : constant String := Fixture_Path ("verbose-source.txt");
      Target  : constant String := Fixture_Path ("verbose-target.txt");
      Link    : constant String := Fixture_Path ("verbose-link.txt");
      Moved   : constant String := Fixture_Path ("verbose-moved.txt");
      Removed : constant String := Fixture_Path ("verbose-removed.txt");

      procedure Remove_Any (Path : String) is
      begin
         if Hostkit.Fs.Is_Link (Path) then
            AUnit.Assertions.Assert (Hostkit.Fs.Delete_Link (Path), "cleanup link failed for " & Path);
         elsif Ada.Directories.Exists (Path) then
            if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
               Ada.Directories.Delete_Tree (Path);
            else
               Ada.Directories.Delete_File (Path);
            end if;
         end if;
      end Remove_Any;
   begin
      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Link);
      Remove_Any (Moved);
      Remove_Any (Removed);

      Write_File (Source, "copy");
      Context.Initialize ("cp", Three_Args ("-v", Source, Target));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cp -v reports stdout failure");

      Write_File (Source, "link");
      Remove_Any (Link);
      Context.Initialize ("ln", Three_Args ("-v", Source, Link));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "ln -v reports stdout failure");

      Write_File (Source, "move");
      Remove_Any (Moved);
      Context.Initialize ("mv", Three_Args ("-v", Source, Moved));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "mv -v reports stdout failure");

      Write_File (Removed, "remove");
      Context.Initialize ("rm", Two_Args ("-v", Removed));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "rm -v reports stdout failure");

      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Link);
      Remove_Any (Moved);
      Remove_Any (Removed);
   end Test_Command_Verbose_Output_Failures;

   procedure Test_Basename (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ".txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "file" & Character'Val (10), "basename output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename status");
   end Test_Basename;

   procedure Test_Basename_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("basename", One_Arg (""));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "" & LF, "basename command empty");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename empty status");

      Context.Initialize ("basename", One_Arg ("///"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "basename command root");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", "file.txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename suffix equal full name");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ".bin"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename suffix absent");

      Context.Initialize ("basename", Two_Args ("/tmp/file.txt", ""));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file.txt" & LF,
         "basename empty suffix");

      Context.Initialize ("basename", One_Arg ("a//b///"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF,
         "basename trailing repeated slash");

      Context.Initialize
        ("basename",
         Two_Args
           ("dir/" & Character'Val (16#C3#) & Character'Val (16#A6#) & ".txt",
            ".txt"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#C3#) & Character'Val (16#A6#) & LF,
         "basename non-ASCII suffix");

      Context.Initialize ("basename", One_Arg ("a\b"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a\b" & LF, "basename command backslash");
   end Test_Basename_Edge_Cases;

   procedure Test_Cat_Files (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-cat-first.bin");
      Second  : constant String := Fixture_Path ("reg-cat-second.bin");
   begin
      Write_File (First, "A" & Character'Val (0));
      Write_File (Second, "B");

      Context.Initialize ("cat", Two_Args (First, Second));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A" & Character'Val (0) & "B",
         "cat preserves ordered file bytes");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat files status");
   end Test_Cat_Files;

   procedure Test_Cat_Continues_After_Missing_File (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Missing : constant String := Fixture_Path ("missing-cat-file.bin");
      Later   : constant String := Fixture_Path ("reg-cat-later.bin");
   begin
      Write_File (Later, "later");

      Context.Initialize ("cat", Two_Args (Missing, Later));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "later", "cat continues after missing file");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "cat: '" & Missing & "': cannot read file" & Character'Val (10),
         "cat missing diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat aggregate failure status");
   end Test_Cat_Continues_After_Missing_File;

   procedure Test_Cat_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "A" & Character'Val (0) & "B");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A" & Character'Val (0) & "B",
         "cat implicit stdin preserves bytes");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat implicit stdin status");

      Context.Initialize ("cat", Two_Args ("-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "cat repeated stdin does not rewind");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat repeated stdin status");

      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "cat stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "cat: 'standard input': cannot read file" & Character'Val (10),
         "cat stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat stdin read failure status");

      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 3);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "cat stdin partial read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "cat: 'standard input': cannot read file" & Character'Val (10),
         "cat stdin partial read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat stdin partial read failure status");
   end Test_Cat_Standard_Input;

   procedure Test_Cat_Byte_Preservation_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#5054_0003#;

      function Next_Value return Word_32 is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Seed;
      end Next_Value;

      function Random_Natural (Modulo : Positive) return Natural is
      begin
         return Natural (Next_Value mod Word_32 (Modulo));
      end Random_Natural;

      function Generated_Bytes return String is
         Length : constant Natural := Random_Natural (513);
         Result : Ada.Strings.Unbounded.Unbounded_String;
      begin
         for I in 1 .. Length loop
            case Random_Natural (8) is
               when 0 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (0));
               when 1 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (10));
               when others =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (Random_Natural (256)));
            end case;
         end loop;

         return Ada.Strings.Unbounded.To_String (Result);
      end Generated_Bytes;
   begin
      for Case_Index in 1 .. 128 loop
         declare
            Context : Test_Contexts.Capturing_Context;
            Result  : Posix_Tools.Commands.Results.Result;
            Input   : constant String := Generated_Bytes;
            Label   : constant String := "seed 0x50540003 case" & Integer'Image (Case_Index);
         begin
            Context.Initialize ("cat", No_Args);
            Test_Contexts.Set_Standard_Input (Context, Input);
            Posix_Tools.Commands.Cat.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Input,
               "cat implicit stdin bytes for " & Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               "cat implicit stdin stderr for " & Label);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "cat implicit stdin status for " & Label);

            Context.Initialize ("cat", One_Arg ("-"));
            Test_Contexts.Set_Standard_Input (Context, Input);
            Posix_Tools.Commands.Cat.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Input,
               "cat explicit stdin bytes for " & Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               "cat explicit stdin stderr for " & Label);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "cat explicit stdin status for " & Label);
         end;
      end loop;
   end Test_Cat_Byte_Preservation_Property;

   procedure Test_Cat_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("cat", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 3);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "cat partial output before failure");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "cat output failure has no read diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cat output failure status");
   end Test_Cat_Output_Failure;

   procedure Test_Dirname (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("dirname", One_Arg ("/tmp/file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/tmp" & Character'Val (10), "dirname output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname status");
   end Test_Dirname;

   procedure Test_Dirname_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("dirname", One_Arg (""));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname command empty");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname empty status");

      Context.Initialize ("dirname", One_Arg ("///"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "dirname command root");

      Context.Initialize ("dirname", One_Arg ("a//b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname repeated separator");

      Context.Initialize ("dirname", One_Arg ("/tmp/file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/tmp" & LF, "dirname absolute path");

      Context.Initialize ("dirname", One_Arg ("a/b/"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname trailing slash");

      Context.Initialize ("dirname", One_Arg ("file"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname no slash");

      Context.Initialize ("dirname", One_Arg ("//tmp"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/" & LF, "dirname two leading slash");

      Context.Initialize ("dirname", One_Arg ("//a/b/"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/a" & LF, "dirname nested two leading slash");

      Context.Initialize ("dirname", One_Arg ("a\b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "." & LF, "dirname command backslash");
   end Test_Dirname_Edge_Cases;

   procedure Test_Basename_Dirname_Command_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#BA5E_D123#;
      LF   : constant Character := Character'Val (10);

      function Next_Value return Natural is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;

      function Generated_Path return String is
         Length : constant Natural := Next_Value mod 18;
         Result : Ada.Strings.Unbounded.Unbounded_String;
      begin
         for I in 1 .. Length loop
            case Next_Value mod 8 is
               when 0 | 1 =>
                  Ada.Strings.Unbounded.Append (Result, "/");
               when 2 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (16#5C#));
               when 3 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (16#C3#));
               when 4 =>
                  Ada.Strings.Unbounded.Append (Result, Character'Val (16#A6#));
               when others =>
                  Ada.Strings.Unbounded.Append
                    (Result,
                     Character'Val (Character'Pos ('a') + (I + Next_Value) mod 26));
            end case;
         end loop;

         return Ada.Strings.Unbounded.To_String (Result);
      end Generated_Path;

      function Generated_Suffix (Path : String) return String is
      begin
         case Next_Value mod 5 is
            when 0 =>
               return "";
            when 1 =>
               return ".txt";
            when 2 =>
               return "x";
            when 3 =>
               if Path'Length = 0 then
                  return "";
               else
                  return Path (Path'Last .. Path'Last);
               end if;
            when others =>
               return Character'Val (16#C3#) & Character'Val (16#A6#);
         end case;
      end Generated_Suffix;
   begin
      for Case_Index in 1 .. 64 loop
         declare
            Basename_Context : Test_Contexts.Capturing_Context;
            Dirname_Context  : Test_Contexts.Capturing_Context;
            Basename_Result  : Posix_Tools.Commands.Results.Result;
            Dirname_Result   : Posix_Tools.Commands.Results.Result;
            Path             : constant String := Generated_Path;
            Suffix           : constant String := Generated_Suffix (Path);
            Label            : constant String :=
              "basename dirname command property seed 0xBA5ED123 case" & Natural'Image (Case_Index);
         begin
            Basename_Context.Initialize ("basename", Two_Args (Path, Suffix));
            Posix_Tools.Commands.Basename.Run (Basename_Context, Basename_Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Basename_Context) = Posix_Tools.Paths.Basename (Path, Suffix) & LF,
               Label & " basename output");
            AUnit.Assertions.Assert
              (Basename_Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " basename status");

            Dirname_Context.Initialize ("dirname", One_Arg (Path));
            Posix_Tools.Commands.Dirname.Run (Dirname_Context, Dirname_Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Dirname_Context) = Posix_Tools.Paths.Dirname (Path) & LF,
               Label & " dirname output");
            AUnit.Assertions.Assert
              (Dirname_Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " dirname status");
         end;
      end loop;
   end Test_Basename_Dirname_Command_Property;

   procedure Test_Host_Identity_Commands (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("arch", No_Args);
      Posix_Tools.Commands.Arch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-machine" & LF,
         "arch uses context machine identity");

      Context.Initialize ("whoami", No_Args);
      Posix_Tools.Commands.Whoami.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-user" & LF,
         "whoami uses context user identity");

      Context.Initialize ("whoami", No_Args);
      Test_Contexts.Set_Current_User_Available (Context, False);
      Posix_Tools.Commands.Whoami.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = ""
         and then Contains (Test_Contexts.Error_Output (Context), "unsupported platform capability"),
         "whoami reports unavailable user identity");

      Context.Initialize ("logname", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LOGNAME", "login-user");
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "login-user" & LF,
         "logname prefers the command environment login name");

      Context.Initialize ("logname", No_Args);
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "session-user" & LF,
         "logname falls back to the context session login name");

      Context.Initialize ("id", No_Args);
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "uid=50000(test-user) gid=60000(test-primary) groups=60000(test-primary),60001(test-extra)" & LF,
         "id default output is decorated with context names");

      Context.Initialize ("id", One_Arg ("-u"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "50000" & LF,
         "id -u prints the numeric user id");

      Context.Initialize ("id", Two_Args ("-u", "-n"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-user" & LF,
         "id -un prints the user name");

      Context.Initialize ("id", One_Arg ("-G"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "60000 60001" & LF,
         "id -G prints numeric group ids");

      Context.Initialize ("id", Two_Args ("-G", "-n"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-primary test-extra" & LF,
         "id -Gn prints named group ids");

      Context.Initialize ("id", No_Args);
      Test_Contexts.Set_Current_Group_Available (Context, False);
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "unsupported platform capability"),
         "id reports unavailable group identity");

      Context.Initialize ("groups", No_Args);
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-primary test-extra" & LF,
         "groups prints current context group names");

      Context.Initialize ("groups", One_Arg ("named-user"));
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "named-user : named-extra test-primary" & LF,
         "groups prints named user group names");

      Context.Initialize ("groups", One_Arg ("missing-user"));
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "missing-user"),
         "groups reports unknown user group lookup failures");

      Context.Initialize ("hostname", No_Args);
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-node" & LF,
         "hostname prints context node name");

      Context.Initialize ("hostname", One_Arg ("new-node"));
      Test_Contexts.Set_Node_Name_Allowed (Context, True);
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Node_Name_Set_Called (Context)
         and then Test_Contexts.Captured_Node_Name (Context) = "new-node",
         "hostname delegates node-name updates through the context");

      Context.Initialize ("uname", Two_Args ("-s", "-n"));
      Posix_Tools.Commands.Uname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "test-node"),
         "uname -n includes the context node name");
   end Test_Host_Identity_Commands;

   procedure Test_Simple_Output_Failures (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("basename", One_Arg ("abc"));
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "basename partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "basename output status");

      Context.Initialize ("dirname", One_Arg ("a/b"));
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "dirname partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "dirname output status");

      Context.Initialize ("echo", Two_Args ("ab", "cd"));
      Test_Contexts.Set_Output_Failure_After (Context, 2);
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "echo partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "echo output status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Test_Contexts.Set_Output_Failure_After (Context, 3);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/ph", "pwd partial output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "pwd output status");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "simple output failure diagnostic");
   end Test_Simple_Output_Failures;

   procedure Test_Echo (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("echo", Three_Args ("", "-n", "x"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = " -n x" & Character'Val (10), "echo output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo status");
   end Test_Echo;

   procedure Test_Echo_Data_Edge_Cases (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("echo", Three_Args ("--", "a\b", "-n"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-- a\b -n" & LF,
         "echo treats -- backslash and -n as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo data edge status");

      Context.Initialize ("echo", Three_Args ("--help", "", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--help  value" & LF,
         "echo non-sole help preserves empty operand");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo non-sole help status");
   end Test_Echo_Data_Edge_Cases;

   procedure Test_Echo_Output_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#EC40_0001#;
      LF   : constant Character := Character'Val (10);

      function Next_Value return Natural is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;

      function Generated_Operand (Case_Index, Argument_Index : Positive) return String is
         pragma Unreferenced (Case_Index);
         Choices : constant Natural := Next_Value mod 10;
         Length  : Natural;
         Result  : Ada.Strings.Unbounded.Unbounded_String;
      begin
         case Choices is
            when 0 =>
               return "";
            when 1 =>
               return "-n";
            when 2 =>
               return "--";
            when 3 =>
               return "--help";
            when 4 =>
               return "--version";
            when 5 =>
               return "--posix-tools-identify";
            when others =>
               Length := 1 + Next_Value mod 8;
               for I in 1 .. Length loop
                  case Next_Value mod 7 is
                     when 0 =>
                        Ada.Strings.Unbounded.Append (Result, Character'Val (16#5C#));
                     when 1 =>
                        Ada.Strings.Unbounded.Append (Result, Character'Val (16#20#));
                     when 2 =>
                        Ada.Strings.Unbounded.Append (Result, Character'Val (16#C3#));
                     when 3 =>
                        Ada.Strings.Unbounded.Append (Result, Character'Val (16#A6#));
                     when others =>
                        Ada.Strings.Unbounded.Append
                          (Result,
                           Character'Val
                             (Character'Pos ('a') + (Argument_Index + I + Next_Value) mod 26));
                  end case;
               end loop;
               return Ada.Strings.Unbounded.To_String (Result);
         end case;
      end Generated_Operand;

      function Sole_Extension (Operand : String) return Boolean is
      begin
         return Operand = "--help"
           or else Operand = "--version"
           or else Operand = "--posix-tools-identify";
      end Sole_Extension;
   begin
      for Case_Index in 1 .. 64 loop
         declare
            Context     : Test_Contexts.Capturing_Context;
            Result      : Posix_Tools.Commands.Results.Result;
            Args        : Posix_Tools.Arguments.Vector;
            Expected    : Ada.Strings.Unbounded.Unbounded_String;
            Arg_Count   : constant Natural := Next_Value mod 9;
            Label       : constant String := "echo property seed 0xEC400001 case" & Natural'Image (Case_Index);
         begin
            for Index in 1 .. Arg_Count loop
               declare
                  Generated : constant String := Generated_Operand (Case_Index, Index);
                  Operand   : constant String :=
                    (if Arg_Count = 1 and then Sole_Extension (Generated) then "ordinary" else Generated);
               begin
                  Args.Append (Operand);
                  if Index > 1 then
                     Ada.Strings.Unbounded.Append (Expected, " ");
                  end if;
                  Ada.Strings.Unbounded.Append (Expected, Operand);
               end;
            end loop;
            Ada.Strings.Unbounded.Append (Expected, LF);

            Context.Initialize ("echo", Args);
            Posix_Tools.Commands.Echo.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Ada.Strings.Unbounded.To_String (Expected),
               Label & " output");
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               Label & " stderr");
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " status");
         end;
      end loop;
   end Test_Echo_Output_Property;

   procedure Test_Echo_Extensions_Are_Sole_Argument (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("echo", Two_Args ("--help", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--help value" & Character'Val (10),
         "echo treats non-sole --help as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo data status");

      Context.Initialize ("echo", One_Arg ("--version"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "echo (posix-tools) " & Posix_Tools.Version.Version_String & Character'Val (10),
         "echo version output");

      Context.Initialize ("echo", Two_Args ("--posix-tools-identify", "value"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "--posix-tools-identify value" & Character'Val (10),
         "echo treats non-sole identity as data");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo identity data status");
   end Test_Echo_Extensions_Are_Sole_Argument;

   procedure Test_End_Of_Options (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-end-of-options.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("basename", Two_Args ("--", "--help"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "--help" & LF, "basename -- operand output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename -- operand status");

      Context.Initialize ("dirname", Two_Args ("--", "a/b"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "dirname -- operand output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname -- operand status");

      Write_File (Path, "data");
      Context.Initialize ("cat", Two_Args ("--", Path));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "data", "cat skips end-of-options marker");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat -- file status");

      Context.Initialize ("pwd", One_Arg ("--"));
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "/physical" & LF, "pwd -- output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -- status");

      Context.Initialize ("pwd", Two_Args ("--", "extra"));
      Test_Contexts.Set_Physical_Current_Directory (Context, "/physical");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "pwd -- extra status");

      Write_File (Path, "a" & LF & "b" & LF);
      Context.Initialize ("head", Two_Args ("--", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head leading -- status");

      Context.Initialize ("head", Four_Args ("-n", "1", "--", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head skips -- after count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head -- status");

      Context.Initialize ("tail", Two_Args ("--", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "tail skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail leading -- status");

      Context.Initialize ("tail", Four_Args ("-n", "1", "--", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF, "tail skips -- after count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -- status");

      Context.Initialize ("wc", Two_Args ("--", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "2 2 4 " & Path & LF, "wc skips leading --");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc leading -- status");

      Context.Initialize ("wc", Three_Args ("-c", "--", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "4 " & Path & LF, "wc skips -- after option");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -- status");
   end Test_End_Of_Options;

   procedure Test_False (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("false", One_Arg ("ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Operational_Failure, "false status");
   end Test_False;

   procedure Test_False_Extension_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("false", One_Arg ("--version"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "false (posix-tools) " & Posix_Tools.Version.Version_String & LF,
         "false sole version");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "false version status");

      Context.Initialize ("false", Two_Args ("--version", "ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false non-sole version ignored");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "false non-sole version status");

      Context.Initialize ("false", Two_Args ("--posix-tools-identify", "ignored"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "false non-sole identity ignored");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "false non-sole identity status");
   end Test_False_Extension_Edges;

   procedure Test_Head_Counts (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-head-counts.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF & "c");

      Context.Initialize ("head", Two_Args ("-n2", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head -n2 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head -n2 status");

      Context.Initialize ("head", Three_Args ("-n", "0", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "head zero output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head zero status");

      Context.Initialize ("head", Three_Args ("-n", "9", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF & "c",
         "head preserves final partial line");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head large count status");

      Context.Initialize ("head", Five_Args ("-n", "1", "-n", "2", Path));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF,
         "head repeated -n uses last count");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head repeated -n status");
   end Test_Head_Counts;

   procedure Test_Head_Default_Limits (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Short   : constant String := Fixture_Path ("reg-head-default-short.txt");
      Long    : constant String := Fixture_Path ("reg-head-default-long.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Short, "1" & LF & "2" & LF & "3" & LF);
      Context.Initialize ("head", One_Arg (Short));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1" & LF & "2" & LF & "3" & LF,
         "head short default output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head short default status");

      Write_File
        (Long,
         "1" & LF & "2" & LF & "3" & LF & "4" & LF & "5" & LF & "6" & LF
         & "7" & LF & "8" & LF & "9" & LF & "10" & LF & "11" & LF & "12" & LF);
      Context.Initialize ("head", One_Arg (Long));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1" & LF & "2" & LF & "3" & LF & "4" & LF & "5" & LF & "6" & LF
           & "7" & LF & "8" & LF & "9" & LF & "10" & LF,
         "head long default output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head long default status");
   end Test_Head_Default_Limits;

   procedure Test_Head_Prefix_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-head-prefix.bin");
      LF      : constant Character := Character'Val (10);
      Seed    : Word_32 := 16#4845_4144#;
      Counts  : constant Count_Array := [0, 1, 2, 5, 11, 32];
      Lengths : constant Length_Array := [0, 1, 16, 17, 63, 256, 1025];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Expected_Prefix (Data : String; Count : Natural) return String is
         Lines : Natural := 0;
      begin
         if Count = 0 then
            return "";
         end if;

         for I in Data'Range loop
            if Data (I) = LF then
               Lines := Lines + 1;
               if Lines = Count then
                  return Data (Data'First .. I);
               end if;
            end if;
         end loop;

         return Data;
      end Expected_Prefix;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Character'Val (Natural ((Seed / 16#0100_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            if I mod 17 = 0 then
               Result (I) := LF;
            else
               Result (I) := Next_Byte;
            end if;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            Write_File (Path, Data);

            for Count of Counts loop
               Context.Initialize ("head", Three_Args ("-n", Decimal_Image (Count), Path));
               Posix_Tools.Commands.Head.Run (Context, Result);
               AUnit.Assertions.Assert
                 (Test_Contexts.Output (Context) = Expected_Prefix (Data, Count),
                  "head prefix property seed 0x48454144 length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Success,
                  "head prefix property status seed 0x48454144 length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
            end loop;
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Head_Prefix_Property;

   procedure Test_Head_Standard_Input_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      LF      : constant Character := Character'Val (10);
      Seed    : Word_32 := 16#4845_AD15#;
      Counts  : constant Count_Array := [0, 1, 3, 10, 33];
      Lengths : constant Length_Array := [0, 1, 9, 29, 128, 513];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Expected_Prefix (Data : String; Count : Natural) return String is
         Lines : Natural := 0;
      begin
         if Count = 0 then
            return "";
         end if;

         for I in Data'Range loop
            if Data (I) = LF then
               Lines := Lines + 1;
               if Lines = Count then
                  return Data (Data'First .. I);
               end if;
            end if;
         end loop;

         return Data;
      end Expected_Prefix;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_103_515_245 + 12_345;
         return Character'Val (Natural ((Seed / 16#0001_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            if I mod 11 = 0 then
               Result (I) := LF;
            else
               Result (I) := Next_Byte;
            end if;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            for Count of Counts loop
               declare
                  Context : Test_Contexts.Capturing_Context;
                  Result  : Posix_Tools.Commands.Results.Result;
               begin
                  Context.Initialize ("head", Two_Args ("-n", Decimal_Image (Count)));
                  Test_Contexts.Set_Standard_Input (Context, Data);
                  Posix_Tools.Commands.Head.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Test_Contexts.Output (Context) = Expected_Prefix (Data, Count),
                     "head stdin property seed 0x4845AD15 length"
                     & Natural'Image (Length) & " count" & Natural'Image (Count));
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success,
                     "head stdin property status seed 0x4845AD15 length"
                     & Natural'Image (Length) & " count" & Natural'Image (Count));
               end;
            end loop;
         end;
      end loop;
   end Test_Head_Standard_Input_Property;

   procedure Test_Head_Invalid_Count (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("head", One_Arg ("-nabc"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "head invalid count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: invalid line count '-nabc'" & Character'Val (10),
         "head invalid count diagnostic");

      Context.Initialize ("head", Two_Args ("-n", "-1"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head negative count status");

      Context.Initialize ("head", Two_Args ("-n", "+1"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head leading plus count status");

      Context.Initialize ("head", Two_Args ("-c", "abc"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head invalid byte count status");

      Context.Initialize ("head", Two_Args ("-n", "9223372036854775808"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head overflow count status");

      Context.Initialize ("head", One_Arg ("-n"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head missing count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: missing option argument '-n'" & Character'Val (10),
         "head missing count diagnostic");

      Context.Initialize ("head", One_Arg ("-c"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "head missing byte count status");
   end Test_Head_Invalid_Count;

   procedure Test_Head_Multiple_File_Headers (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-head-header-first.txt");
      Second  : constant String := Fixture_Path ("reg-head-header-second.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (First, "a" & LF & "b" & LF);
      Write_File (Second, "c" & LF & "d" & LF);

      Context.Initialize ("head", Four_Args ("-n", "1", First, Second));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> " & First & " <==" & LF
           & "a" & LF
           & LF
           & "==> " & Second & " <==" & LF
           & "c" & LF,
         "head multiple file headers");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head header status");
   end Test_Head_Multiple_File_Headers;

   procedure Test_Head_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("head", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF & "b" & LF, "head stdin output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head stdin status");

      Context.Initialize ("head", Three_Args ("-c", "3", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "head stdin byte output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head stdin byte status");

      Context.Initialize ("head", Two_Args ("-c0", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "head zero byte output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head zero byte status");

      Context.Initialize ("head", Five_Args ("-c", "2", "-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abc" & LF & "def" & LF);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc" & LF, "head last count option wins");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head last count status");

      Context.Initialize ("head", Three_Args ("-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head stdin avoids extra read");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "head stdin avoids extra read diagnostic");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head stdin avoids extra read status");

      Context.Initialize ("head", Four_Args ("-n", "1", "-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> - <==" & LF
           & "a" & LF
           & LF
           & "==> - <==" & LF,
         "head repeated stdin is not rewound");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head repeated stdin status");

      Context.Initialize ("head", Three_Args ("-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "head stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "head: 'standard input': cannot read file" & LF,
         "head stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "head stdin read failure status");
   end Test_Head_Standard_Input;

   procedure Test_Head_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("head", Three_Args ("-n", "3", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Test_Contexts.Set_Output_Failure_After (Context, 2);
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & LF, "head stops after failed write");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "head output failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "head output failure status");
   end Test_Head_Output_Failure;

   procedure Test_Help_And_Version (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("cat", One_Arg ("--help"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: cat [OPTION]... [OPERAND]..." & LF
           & "Ada implementation in the posix-tools package." & LF
           & "Options:" & LF
           & "  --help     display this help and exit" & LF
           & "  --version  display version information and exit" & LF,
         "cat help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat help status");

      Context.Initialize ("cat", One_Arg ("--version"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "cat (posix-tools) " & Posix_Tools.Version.Version_String & LF,
         "cat version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat version status");
   end Test_Help_And_Version;

   procedure Test_Help_Locales (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      declare
         Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "Danish help status");
         AUnit.Assertions.Assert (Contains (Text, "Brug: cat "), "Danish help usage heading");
         AUnit.Assertions.Assert (Contains (Text, "Valgmuligheder:"), "Danish help options heading");
         AUnit.Assertions.Assert (Contains (Text, "--help"), "Danish help preserves option spelling");
         AUnit.Assertions.Assert (not Contains (Text, "posix_tools."), "Danish help no message-key leak");
      end;

      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Locale (Context, "zz-ZZ");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      declare
         Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Contains (Text, "Usage: cat "), "unknown locale fallback usage");
         AUnit.Assertions.Assert (not Contains (Text, "posix_tools."), "unknown locale no message-key leak");
      end;

      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      declare
         Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "Spanish help status");
         AUnit.Assertions.Assert (Contains (Text, "Uso: cat "), "Spanish help usage heading");
         AUnit.Assertions.Assert (Contains (Text, "Opciones:"), "Spanish help options heading");
         AUnit.Assertions.Assert
           (Contains (Text, "muestra esta ayuda y termina"),
            "Spanish help option description");
         AUnit.Assertions.Assert (Contains (Text, "--version"), "Spanish help preserves option spelling");
         AUnit.Assertions.Assert (not Contains (Text, "posix_tools."), "Spanish help no message-key leak");
      end;

      AUnit.Assertions.Assert
        (Posix_Tools.Localization.Text
           ("es", "posix_tools.test.missing_message", "FALLBACK_TEXT") = "FALLBACK_TEXT",
         "missing message falls back to caller default");
   end Test_Help_Locales;

   procedure Test_Version_Locale_Invariance (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);

      procedure Check_Command (Command, Locale, Label : String) is
         Expected : constant String :=
           Command & " (posix-tools) " & Posix_Tools.Version.Version_String & LF;
      begin
         Context.Initialize (Command, One_Arg ("--version"));
         if Locale /= "" then
            Test_Contexts.Set_Locale (Context, Locale);
         end if;
         Run_Command_By_Name (Command, Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "version status " & Command & " " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Expected,
            "version output " & Command & " " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "version stderr " & Command & " " & Label);
      end Check_Command;

      procedure Check_Root (Locale, Label : String) is
         Expected : constant String :=
           "posix-tools " & Posix_Tools.Version.Version_String & LF;

         procedure Check_Root_Args
           (Args      : Posix_Tools.Arguments.Vector;
            Arg_Label : String)
         is
         begin
            Context.Initialize ("posix-tools", Args);
            if Locale /= "" then
               Test_Contexts.Set_Locale (Context, Locale);
            end if;
            Posix_Tools.Commands.Root.Run (Context, Result);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "root version status " & Label & " " & Arg_Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Expected,
               "root version output " & Label & " " & Arg_Label);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Context) = "",
               "root version stderr " & Label & " " & Arg_Label);
         end Check_Root_Args;
      begin
         Check_Root_Args (One_Arg ("--version"), "extension");
         Check_Root_Args (One_Arg ("version"), "subcommand");
      end Check_Root;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
         begin
            Check_Command (Command, "", "default");
            Check_Command (Command, "en", "en");
            Check_Command (Command, "da", "da");
            Check_Command (Command, "zz-ZZ", "unknown");
         end;
      end loop;

      Check_Root ("", "default");
      Check_Root ("en", "en");
      Check_Root ("da", "da");
      Check_Root ("zz-ZZ", "unknown");
   end Test_Version_Locale_Invariance;

   procedure Test_Diagnostic_Locales (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
      Missing : constant String := Fixture_Path ("missing-da-file.txt");
      Invalid : constant String := Fixture_Path ("invalid-da-utf8.bin");
   begin
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "Danish diagnostic status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: ekstra operand second" & LF,
         "Danish extra operand diagnostic");
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "Danish diagnostic stdout");

      Context.Initialize ("head", One_Arg ("-n"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "Danish missing option argument status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: mangler argument til valgmulighed -n" & LF,
         "Danish missing option argument diagnostic");

      Context.Initialize ("wc", One_Arg ("-z"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "Danish unknown option status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: ukendt valgmulighed -z" & LF,
         "Danish unknown option diagnostic");

      Context.Initialize ("head", One_Arg ("-nabc"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "Danish invalid line count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "head: ugyldigt linjeantal -nabc" & LF,
         "Danish invalid line count diagnostic");

      Context.Initialize ("cat", One_Arg (Missing));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish read failure status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "cat: '" & Missing & "': kan ikke læse fil" & LF,
         "Danish read failure diagnostic");

      Write_File (Invalid, "A" & Character'Val (16#C3#));
      Context.Initialize ("wc", Two_Args ("-m", Invalid));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish invalid UTF-8 status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Invalid & "': ugyldig UTF-8" & LF,
         "Danish invalid UTF-8 diagnostic");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Physical_Current_Directory (Context, "__raise_current_directory__");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish pwd failure status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "pwd: kan ikke bestemme aktuel mappe" & LF,
         "Danish pwd failure diagnostic");

      Context.Initialize ("tail", Two_Args ("-c", "2147483648"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "Danish count too large status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: antal er for stort" & LF,
         "Danish count too large diagnostic");

      Context.Initialize ("wc", One_Arg ("-z"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "Spanish unknown option status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: opcion desconocida -z" & LF,
         "Spanish unknown option diagnostic");
   end Test_Diagnostic_Locales;

   procedure Test_Presentation_Styling (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      ESC     : constant Character := Character'Val (27);
   begin
      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Never);
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (not Contains (Test_Contexts.Output (Context), "" & ESC), "unstyled help has no ANSI");
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "Usage: cat "), "unstyled semantic help");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Always);
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "" & ESC & "["), "styled help has ANSI");
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "Usage"), "styled help keeps usage text");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "--help"),
         "styled help keeps option spelling");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
      Context.Initialize ("cat", One_Arg ("--help"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, False);
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "" & ESC),
         "automatic redirected help has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "Usage: cat "),
         "automatic redirected help keeps usage");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Never);
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "" & ESC),
         "unstyled root help has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "Usage: posix-tools"),
         "unstyled root help");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Always);
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "" & ESC & "["), "styled root help has ANSI");
      AUnit.Assertions.Assert (Contains (Test_Contexts.Output (Context), "Usage"), "styled root help keeps usage");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "help, version, list, paths, verify"),
         "styled root help keeps commands");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, False);
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "" & ESC),
         "automatic redirected root help has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "Usage: posix-tools"),
         "automatic redirected root help keeps usage");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Never);
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Error_Output (Context), "" & ESC),
         "unstyled diagnostic has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "dirname: extra operand 'second'"),
         "unstyled diagnostic keeps text");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Always);
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, False);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "" & ESC & "["),
         "styled diagnostic has ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "dirname: extra operand 'second'"),
         "styled diagnostic keeps text");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, False);
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Error_Output (Context), "" & ESC),
         "automatic redirected diagnostic has no ANSI");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "dirname: extra operand 'second'"),
         "automatic redirected diagnostic keeps text");

      Posix_Tools.Presentation.Set_Style_Mode (Posix_Tools.Presentation.Automatic);
   end Test_Presentation_Styling;

   procedure Test_Identity (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      function Expected (Command : String) return String is
      begin
         return
           "schema=1" & Character'Val (10)
           & "project=posix-tools" & Character'Val (10)
           & "command=" & Command & Character'Val (10)
           & "version=" & Posix_Tools.Version.Version_String & Character'Val (10);
      end Expected;
   begin
      Context.Initialize ("basename", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Basename.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("basename"), "basename identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "basename identity status");

      Context.Initialize ("cat", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("cat"), "cat identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cat identity status");

      Context.Initialize ("dirname", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("dirname"), "dirname identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "dirname identity status");

      Context.Initialize ("echo", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Echo.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("echo"), "echo identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "echo identity status");

      Context.Initialize ("false", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.False_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("false"), "false identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "false identity status");

      Context.Initialize ("head", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Head.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("head"), "head identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "head identity status");

      Context.Initialize ("pwd", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("pwd"), "pwd identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd identity status");

      Context.Initialize ("tail", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("tail"), "tail identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail identity status");

      Context.Initialize ("true", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("true"), "true identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true identity status");

      Context.Initialize ("wc", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected ("wc"), "wc identity");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc identity status");
   end Test_Identity;

   procedure Test_Identity_Locale_Invariance (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      function Expected (Command : String) return String is
      begin
         return
           "schema=1" & Character'Val (10)
           & "project=posix-tools" & Character'Val (10)
           & "command=" & Command & Character'Val (10)
           & "version=" & Posix_Tools.Version.Version_String & Character'Val (10);
      end Expected;

      procedure Check_Command (Command, Locale, Label : String) is
      begin
         Context.Initialize (Command, One_Arg ("--posix-tools-identify"));
         if Locale /= "" then
            Test_Contexts.Set_Locale (Context, Locale);
         end if;
         Run_Command_By_Name (Command, Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "identity status " & Command & " " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Expected (Command),
            "identity output " & Command & " " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "identity stderr " & Command & " " & Label);
      end Check_Command;

      procedure Check_Root (Locale, Label : String) is
      begin
         Context.Initialize ("posix-tools", One_Arg ("--posix-tools-identify"));
         if Locale /= "" then
            Test_Contexts.Set_Locale (Context, Locale);
         end if;
         Posix_Tools.Commands.Root.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "root identity status " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Expected ("posix-tools"),
            "root identity output " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "root identity stderr " & Label);
      end Check_Root;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
         begin
            Check_Command (Command, "", "default");
            Check_Command (Command, "en", "en");
            Check_Command (Command, "da", "da");
            Check_Command (Command, "zz-ZZ", "unknown");
         end;
      end loop;

      Check_Root ("", "default");
      Check_Root ("en", "en");
      Check_Root ("da", "da");
      Check_Root ("zz-ZZ", "unknown");
   end Test_Identity_Locale_Invariance;

   procedure Test_Pwd_Context_Fallbacks (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Physical : constant String := "/physical/fallback";
      Logical  : constant String := "/logical/default";
      LF       : constant Character := Character'Val (10);
   begin
      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Logical & LF, "pwd default logical output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd default logical status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Test_Contexts.Set_Logical_Pwd_Matches_Current_Directory (Context, False);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd stale PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd stale PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd empty PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd empty PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "relative/path");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd relative PWD fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd relative PWD status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/./test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd dot component fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd dot component status");

      Context.Initialize ("pwd", No_Args);
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/../test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & LF,
         "pwd dot-dot component fallback output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd dot-dot component status");

      Context.Initialize ("pwd", Two_Args ("-P", "-L"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Logical & LF, "pwd -P -L last option output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -P -L status");
   end Test_Pwd_Context_Fallbacks;

   procedure Test_Pwd_Options (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Physical : constant String := "/physical/test";
   begin
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");

      Context.Initialize ("pwd", One_Arg ("-L"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "/logical/test" & Character'Val (10),
         "pwd -L output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -L status");

      Context.Initialize ("pwd", One_Arg ("-P"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & Character'Val (10),
         "pwd -P output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd -P status");

      Context.Initialize ("pwd", Two_Args ("-L", "-P"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Test_Contexts.Set_Environment_Value (Context, "PWD", "/logical/test");
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Physical & Character'Val (10),
         "pwd last option wins");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "pwd precedence status");

      Context.Initialize ("pwd", One_Arg ("operand"));
      Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
      Posix_Tools.Commands.Pwd.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "pwd operand status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "pwd: invalid operand 'operand'" & Character'Val (10),
         "pwd operand diagnostic");
   end Test_Pwd_Options;

   procedure Test_Pwd_Option_Precedence_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;

      Seed     : Word_32 := 16#5057_4431#;
      Physical : constant String := "/physical/property";
      Logical  : constant String := "/logical/property";
      LF       : constant Character := Character'Val (10);

      function Next_Value return Natural is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;
   begin
      for Case_Index in 1 .. 64 loop
         declare
            Context   : Test_Contexts.Capturing_Context;
            Result    : Posix_Tools.Commands.Results.Result;
            Args      : Posix_Tools.Arguments.Vector;
            Use_Logical : Boolean := True;
            Count     : constant Natural := Next_Value mod 9;
            Label     : constant String :=
              "pwd option precedence property seed 0x50574431 case" & Natural'Image (Case_Index);
         begin
            for Index in 1 .. Count loop
               if Next_Value mod 2 = 0 then
                  Args.Append ("-L");
                  Use_Logical := True;
               else
                  Args.Append ("-P");
                  Use_Logical := False;
               end if;
            end loop;

            Context.Initialize ("pwd", Args);
            Test_Contexts.Set_Physical_Current_Directory (Context, Physical);
            Test_Contexts.Set_Environment_Value (Context, "PWD", Logical);
            Posix_Tools.Commands.Pwd.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) =
                 (if Use_Logical then Logical & LF else Physical & LF),
               Label & " output");
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " status");
         end;
      end loop;
   end Test_Pwd_Option_Precedence_Property;

   procedure Test_Root_List (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Expected : constant String := Inventory_List_Output;
   begin
      Context.Initialize ("posix-tools", One_Arg ("list"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Expected, "root list output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root list status");
   end Test_Root_List;

   procedure Test_Root_List_Inventory_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("list"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Inventory_List_Output,
         "root list must match command inventory order");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "root inventory list status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "",
         "root inventory list stderr");
   end Test_Root_List_Inventory_Property;

   procedure Test_Root_List_Locale_Invariance (T : in out Fixture) is
      pragma Unreferenced (T);
      Context  : Test_Contexts.Capturing_Context;
      Result   : Posix_Tools.Commands.Results.Result;
      Expected : constant String := Inventory_List_Output;

      procedure Check (Locale, Label : String) is
      begin
         Context.Initialize ("posix-tools", One_Arg ("list"));
         if Locale /= "" then
            Test_Contexts.Set_Locale (Context, Locale);
         end if;
         Posix_Tools.Commands.Root.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "root list locale status " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Expected,
            "root list locale output " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "root list locale stderr " & Label);
      end Check;
   begin
      Check ("", "default");
      Check ("en", "en");
      Check ("da", "da");
      Check ("zz-ZZ", "unknown");
   end Test_Root_List_Locale_Invariance;

   procedure Test_Root_Usage_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("posix-tools", Two_Args ("list", "extra"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root list extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: extra operand 'extra'" & LF,
         "root list extra diagnostic");

      Context.Initialize ("posix-tools", Three_Args ("help", "cat", "extra"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root help extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: extra operand 'extra'" & LF,
         "root help extra diagnostic");

      Context.Initialize ("posix-tools", Two_Args ("help", "missing"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root help unknown status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: unknown command 'missing'" & LF,
         "root help unknown diagnostic");
   end Test_Root_Usage_Edges;

   procedure Test_Root_Paths (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("paths"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      declare
         Output_Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root paths status");
         AUnit.Assertions.Assert (Contains (Output_Text, "basename: "), "root paths basename line");
         AUnit.Assertions.Assert (Contains (Output_Text, "cat: "), "root paths cat line");
         AUnit.Assertions.Assert (Contains (Output_Text, "dirname: "), "root paths dirname line");
         AUnit.Assertions.Assert (Contains (Output_Text, "echo: "), "root paths echo line");
         AUnit.Assertions.Assert (Contains (Output_Text, "false: "), "root paths false line");
         AUnit.Assertions.Assert (Contains (Output_Text, "head: "), "root paths head line");
         AUnit.Assertions.Assert (Contains (Output_Text, "pwd: "), "root paths pwd line");
         AUnit.Assertions.Assert (Contains (Output_Text, "tail: "), "root paths tail line");
         AUnit.Assertions.Assert (Contains (Output_Text, "true: "), "root paths true line");
         AUnit.Assertions.Assert (Contains (Output_Text, "wc: "), "root paths wc line");
      end;
   end Test_Root_Paths;

   procedure Test_Root_Verify (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("verify"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      declare
         Output_Text : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root verify status");
         AUnit.Assertions.Assert (Contains (Output_Text, "basename: "), "root verify basename line");
         AUnit.Assertions.Assert (Contains (Output_Text, "cat: "), "root verify cat line");
         AUnit.Assertions.Assert (Contains (Output_Text, "dirname: "), "root verify dirname line");
         AUnit.Assertions.Assert (Contains (Output_Text, "echo: "), "root verify echo line");
         AUnit.Assertions.Assert (Contains (Output_Text, "false: "), "root verify false line");
         AUnit.Assertions.Assert (Contains (Output_Text, "head: "), "root verify head line");
         AUnit.Assertions.Assert (Contains (Output_Text, "pwd: "), "root verify pwd line");
         AUnit.Assertions.Assert (Contains (Output_Text, "tail: "), "root verify tail line");
         AUnit.Assertions.Assert (Contains (Output_Text, "true: "), "root verify true line");
         AUnit.Assertions.Assert (Contains (Output_Text, "wc: "), "root verify wc line");
      end;
   end Test_Root_Verify;

   procedure Test_Root_Verify_Status_Locales (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);

      function Is_Danish_Status (Status : String) return Boolean is
      begin
         return
           Status = "mangler"
           or else Status = "ikke eksekverbar"
           or else Status = "ok"
           or else Status = "skygget"
           or else Status = "kan ikke verificeres"
           or else Status = "forkert projekt"
           or else Status = "forkert version";
      end Is_Danish_Status;

      function Is_English_Status (Status : String) return Boolean is
      begin
         return
           Status = "missing"
           or else Status = "not executable"
           or else Status = "ok"
           or else Status = "shadowed"
           or else Status = "unverifiable"
           or else Status = "wrong project"
           or else Status = "wrong version";
      end Is_English_Status;

      procedure Assert_Verify_Status_Lines
        (Output_Text : String;
         Label       : String;
         Danish      : Boolean)
      is
         Position : Natural := Output_Text'First;
      begin
         for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
            declare
               Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
               Prefix  : constant String := Command & ": ";
               Start   : Natural;
               Stop    : Natural;
            begin
               AUnit.Assertions.Assert
                 (Position + Prefix'Length - 1 <= Output_Text'Last
                  and then Output_Text (Position .. Position + Prefix'Length - 1) = Prefix,
                  Label & " prefix for " & Command);
               Start := Position + Prefix'Length;
               Stop := Start;
               while Stop <= Output_Text'Last and then Output_Text (Stop) /= LF loop
                  Stop := Stop + 1;
               end loop;
               AUnit.Assertions.Assert
                 (Stop <= Output_Text'Last and then Output_Text (Stop) = LF,
                  Label & " line terminator for " & Command);
               AUnit.Assertions.Assert
                 (Start < Stop,
                  Label & " nonempty status for " & Command);
               declare
                  Status : constant String := Output_Text (Start .. Stop - 1);
               begin
                  AUnit.Assertions.Assert
                    ((if Danish then Is_Danish_Status (Status) else Is_English_Status (Status)),
                     Label & " localized status for " & Command & ": " & Status);
               end;
               Position := Stop + 1;
            end;
         end loop;

         AUnit.Assertions.Assert
           (Position = Output_Text'Last + 1,
            Label & " extra output after inventory lines");
      end Assert_Verify_Status_Lines;

      procedure Check (Locale, Label : String; Danish : Boolean) is
      begin
         Context.Initialize ("posix-tools", One_Arg ("verify"));
         Test_Contexts.Set_Locale (Context, Locale);
         Posix_Tools.Commands.Root.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "root verify locale status " & Label);
         Assert_Verify_Status_Lines (Test_Contexts.Output (Context), Label, Danish);
         AUnit.Assertions.Assert
           (not Contains (Test_Contexts.Output (Context), "posix_tools."),
            "root verify locale no message-key leak " & Label);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) = "",
            "root verify locale stderr " & Label);
      end Check;
   begin
      Check ("da", "da", True);
      Check ("zz-ZZ", "unknown", False);
   end Test_Root_Verify_Status_Locales;

   procedure Test_Root_Paths_Verify_Inventory_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("paths"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "root paths inventory status");
      Assert_Inventory_Status_Lines
        (Test_Contexts.Output (Context),
         "root paths inventory");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "",
         "root paths inventory stderr");

      Context.Initialize ("posix-tools", One_Arg ("verify"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "root verify inventory status");
      Assert_Inventory_Status_Lines
        (Test_Contexts.Output (Context),
         "root verify inventory");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "",
         "root verify inventory stderr");
   end Test_Root_Paths_Verify_Inventory_Property;

   procedure Test_Root_Command_Help_Uses_Command_Metadata (T : in out Fixture) is
      pragma Unreferenced (T);
      Cat_Context  : Test_Contexts.Capturing_Context;
      Root_Context : Test_Contexts.Capturing_Context;
      Cat_Result   : Posix_Tools.Commands.Results.Result;
      Root_Result  : Posix_Tools.Commands.Results.Result;
   begin
      Cat_Context.Initialize ("cat", One_Arg ("--help"));
      Posix_Tools.Commands.Cat.Run (Cat_Context, Cat_Result);

      Root_Context.Initialize ("posix-tools", Two_Args ("help", "cat"));
      Posix_Tools.Commands.Root.Run (Root_Context, Root_Result);

      AUnit.Assertions.Assert
        (Cat_Result.Status = Posix_Tools.Exit_Status.Success,
         "cat direct help status");
      AUnit.Assertions.Assert
        (Root_Result.Status = Posix_Tools.Exit_Status.Success,
         "root command help status");
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Root_Context) = Test_Contexts.Output (Cat_Context),
         "root command help must reuse command metadata");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Root_Context) = "",
         "root command help stderr");
   end Test_Root_Command_Help_Uses_Command_Metadata;

   procedure Test_Root_Command_Help_Inventory_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      Direct_Context : Test_Contexts.Capturing_Context;
      Root_Context   : Test_Contexts.Capturing_Context;
      Direct_Result  : Posix_Tools.Commands.Results.Result;
      Root_Result    : Posix_Tools.Commands.Results.Result;
   begin
      for Index in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         declare
            Command : constant String := Posix_Tools.Command_Inventory.Executable (Index);
         begin
            Direct_Context.Initialize (Command, One_Arg ("--help"));
            Run_Command_By_Name (Command, Direct_Context, Direct_Result);

            Root_Context.Initialize ("posix-tools", Two_Args ("help", Command));
            Posix_Tools.Commands.Root.Run (Root_Context, Root_Result);

            AUnit.Assertions.Assert
              (Direct_Result.Status = Posix_Tools.Exit_Status.Success,
               "direct help status for " & Command);
            AUnit.Assertions.Assert
              (Root_Result.Status = Posix_Tools.Exit_Status.Success,
               "root help status for " & Command);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Root_Context) = Test_Contexts.Output (Direct_Context),
               "root help must match direct help for " & Command);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Root_Context) = "",
               "root help stderr for " & Command);
            AUnit.Assertions.Assert
              (Test_Contexts.Error_Output (Direct_Context) = "",
               "direct help stderr for " & Command);
         end;
      end loop;
   end Test_Root_Command_Help_Inventory_Property;

   procedure Test_Root_Version_And_Help (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", One_Arg ("version"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "posix-tools " & Posix_Tools.Version.Version_String & Character'Val (10),
         "root version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root version status");

      Context.Initialize ("posix-tools", One_Arg ("--version"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "posix-tools " & Posix_Tools.Version.Version_String & Character'Val (10),
         "root --version output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root --version status");

      Context.Initialize ("posix-tools", One_Arg ("--help"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: posix-tools [OPTION]... [OPERAND]..." & Character'Val (10)
           & "Ada implementation in the posix-tools package." & Character'Val (10)
           & "Options:" & Character'Val (10)
           & "  --help     display this help and exit" & Character'Val (10)
           & "  --version  display version information and exit" & Character'Val (10),
         "root --help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root --help status");

      Context.Initialize ("posix-tools", One_Arg ("--posix-tools-identify"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "schema=1" & Character'Val (10)
           & "project=posix-tools" & Character'Val (10)
           & "command=posix-tools" & Character'Val (10)
           & "version=" & Posix_Tools.Version.Version_String & Character'Val (10),
         "root identity output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root identity status");

      Context.Initialize ("posix-tools", No_Args);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: posix-tools <command> [operand]" & Character'Val (10)
           & "Commands: help, version, list, paths, verify" & Character'Val (10),
         "root default help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root default help status");
   end Test_Root_Version_And_Help;

   procedure Test_Root_Localized_Help (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Brug: posix-tools <command> [operand]" & LF
           & "Kommandoer: help, version, list, paths, verify" & LF,
         "root localized help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root localized help status");

      Context.Initialize ("posix-tools", One_Arg ("bogus"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root localized unknown subcommand status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: ukendt underkommando bogus" & LF,
         "root localized unknown subcommand diagnostic");

      Context.Initialize ("posix-tools", Two_Args ("help", "bogus"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "root localized unknown help topic status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "posix-tools: ukendt kommando bogus" & LF,
         "root localized unknown help topic diagnostic");

      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Uso: posix-tools <command> [operand]" & LF
           & "Comandos: help, version, list, paths, verify" & LF,
         "root Spanish help output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "root Spanish help status");
   end Test_Root_Localized_Help;

   procedure Test_Root_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("posix-tools", No_Args);
      Test_Contexts.Set_Output_Failure_After (Context, 5);
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "Usage", "root partial output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "root output failure status");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "root output failure diagnostic");
   end Test_Root_Output_Failure;

   procedure Test_Nl (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("nl-input.txt");
      Missing : constant String := Fixture_Path ("nl-missing.txt");
      LF      : constant Character := Character'Val (10);
      HT      : constant Character := Character'Val (9);

      procedure Delete_If_Exists (Name : String) is
      begin
         if Ada.Directories.Exists (Name) then
            Ada.Directories.Delete_File (Name);
         end if;
      end Delete_If_Exists;
   begin
      Context.Initialize ("nl", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & LF & "b");
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "     1" & HT & "a" & LF & "      " & HT & LF
           & "     2" & HT & "b",
         "nl numbers non-empty stdin lines by default");

      Context.Initialize ("nl", One_Arg ("-ba"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "     1" & HT & "a" & LF & "     2" & HT & LF,
         "nl -ba numbers blank lines");

      Context.Initialize ("nl", One_Arg ("-bn"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "      " & HT & "a" & LF,
         "nl -bn suppresses numbering");

      Delete_If_Exists (Path);
      Write_File (Path, "x" & LF & "y" & LF);
      Context.Initialize ("nl", Six_Args ("-v", "3", "-i", "2", "-w2", Path));
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = " 3" & HT & "x" & LF & " 5" & HT & "y" & LF,
         "nl honors start increment width and file operands");

      Context.Initialize ("nl", Three_Args ("-s", ": ", "-ba"));
      Test_Contexts.Set_Standard_Input (Context, "z" & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "     1: z" & LF,
         "nl honors custom separators");

      Context.Initialize ("nl", Four_Args ("-ha", "-fa", "-ba", "-v3"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "\:\:\:" & LF
         & "head" & LF
         & "\:\:" & LF
         & "body" & LF
         & "\:" & LF
         & "foot" & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "     3" & HT & "head" & LF
           & "     4" & HT & "body" & LF
           & "     5" & HT & "foot" & LF,
         "nl processes default logical page delimiters");

      Context.Initialize ("nl", Five_Args ("-p", "-ha", "-d", "%%", "-v7"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "%%%%%%" & LF
         & "first" & LF
         & "%%%%%%" & LF
         & "second" & LF);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "     7" & HT & "first" & LF
           & "     8" & HT & "second" & LF,
         "nl honors custom delimiters and no-restart");

      Context.Initialize ("nl", Two_Args ("-i", "0"));
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "nl rejects zero increment");

      Context.Initialize ("nl", One_Arg (Missing));
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "nl reports missing files");

      Context.Initialize ("nl", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "x");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Nl.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "nl reports output failures");

      Delete_If_Exists (Path);
   end Test_Nl;

   procedure Test_Seq (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("seq", One_Arg ("3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1" & LF & "2" & LF & "3" & LF,
         "seq one operand starts at one");

      Context.Initialize ("seq", Two_Args ("3", "5"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "3" & LF & "4" & LF & "5" & LF,
         "seq two operands uses unit increment");

      Context.Initialize ("seq", Three_Args ("5", "-2", "1"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "5" & LF & "3" & LF & "1" & LF,
         "seq supports negative increments");

      Context.Initialize ("seq", Three_Args ("0.1", "0.1", "0.3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0.1" & LF & "0.2" & LF & "0.3" & LF,
         "seq supports deterministic decimal increments");

      Context.Initialize ("seq", Three_Args ("1e1", "5e0", "2e1"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "10" & LF & "15" & LF & "20" & LF,
         "seq supports positive exponent notation");

      Context.Initialize ("seq", Three_Args ("1e-1", "1e-1", "3e-1"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0.1" & LF & "0.2" & LF & "0.3" & LF,
         "seq supports negative exponent notation");

      Context.Initialize ("seq", One_Arg ("1e999999999999999999999999999999999999999"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects overflowing exponent");

      Context.Initialize ("seq", One_Arg ("0.99999999999999999999"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects overflowing mantissa");

      Context.Initialize ("seq", Three_Args ("0.1", "0.1", "0.3"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0,1" & LF & "0,2" & LF & "0,3" & LF,
         "seq uses locale decimal separator");

      Context.Initialize ("seq", Three_Args ("0.1", "0.1", "0.3"));
      Test_Contexts.Set_Locale (Context, "en");
      Test_Contexts.Set_Environment_Value (Context, "LC_NUMERIC", "da");
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0,1" & LF & "0,2" & LF & "0,3" & LF,
         "seq LC_NUMERIC overrides context locale");

      Context.Initialize ("seq", Four_Args ("-s", ",", "1", "3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1,2,3" & LF,
         "seq supports custom separators");

      Context.Initialize ("seq", Three_Args ("-w", "8", "10"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "08" & LF & "09" & LF & "10" & LF,
         "seq supports equal-width output");

      Context.Initialize ("seq", Five_Args ("-f", "n=%04.1f", "1", "1", "3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "n=01.0" & LF & "n=02.0" & LF & "n=03.0" & LF,
         "seq supports printf-style decimal formatting");

      Context.Initialize
        ("seq", Three_Args ("-f%999999999999999999999999999999f", "1", "2"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1" & LF & "2" & LF,
         "seq overflowing format width uses default formatting");

      Context.Initialize ("seq", Five_Args ("-f", "n=%04.1f", "1", "1", "3"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "n=01,0" & LF & "n=02,0" & LF & "n=03,0" & LF,
         "seq formats numbers through locale data");

      Context.Initialize ("seq", Three_Args ("1", "0", "3"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects zero increment");

      Context.Initialize ("seq", One_Arg ("abc"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects invalid integers");

      Context.Initialize ("seq", Four_Args ("1", "2", "3", "4"));
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "seq rejects extra operands");

      Context.Initialize ("seq", One_Arg ("3"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Seq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "seq reports output failure");
   end Test_Seq;

   procedure Test_Unlink (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("unlink-target.txt");
      Dash_Path : constant String := Fixture_Path ("-");

      procedure Delete_If_Exists (Name : String) is
      begin
         if Ada.Directories.Exists (Name) then
            Ada.Directories.Delete_File (Name);
         end if;
      end Delete_If_Exists;
   begin
      Delete_If_Exists (Path);
      Delete_If_Exists (Dash_Path);
      Write_File (Path, "x");

      Context.Initialize ("unlink", One_Arg (Path));
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Path)
         and then Test_Contexts.Output (Context) = "",
         "unlink removes one file without output");

      Write_File (Dash_Path, "x");
      Context.Initialize ("unlink", Two_Args ("--", Dash_Path));
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Dash_Path),
         "unlink accepts end-of-options before operand");

      Context.Initialize ("unlink", No_Args);
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "unlink rejects missing operand");

      Context.Initialize ("unlink", Two_Args ("a", "b"));
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "unlink rejects extra operands");

      Context.Initialize ("unlink", One_Arg (Path));
      Posix_Tools.Commands.Unlink.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "unlink reports missing path");
   end Test_Unlink;

   procedure Test_Tail_Byte_Mode_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-byte-mode.bin");
      Spill_Path : constant String := Fixture_Path ("reg-tail-byte-spill.bin");
   begin
      Write_File (Path, "abcdef");

      Context.Initialize ("tail", Three_Args ("-c", "0", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail -c 0 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c 0 status");

      Context.Initialize ("tail", Three_Args ("-c", "3", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "tail -c 3 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c 3 status");

      Context.Initialize ("tail", Three_Args ("-c", "20", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "tail -c larger than input output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail -c larger than input status");

      Context.Initialize ("tail", Three_Args ("-c", "+4", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "tail -c +4 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c +4 status");

      Context.Initialize ("tail", Three_Args ("-c", "6", Spill_Path));
      Test_Contexts.Set_Tail_Resource_Limits (Context, 3, 64);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "fghij" & Character'Val (10),
         "tail -c spill output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c spill status");

      Context.Initialize ("tail", Three_Args ("-c", "6", Spill_Path));
      Test_Contexts.Set_Tail_Resource_Limits (Context, 3, 4);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail max spill failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: count too large" & Character'Val (10),
         "tail max spill diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail max spill failure status");
   end Test_Tail_Byte_Mode_Edges;

   procedure Test_Tail_Compact_Counts (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-compact.bin");
   begin
      Write_File (Path, "abcdef");

      Context.Initialize ("tail", Two_Args ("-c2", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ef", "tail -c2 compact output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c2 status");

      Context.Initialize ("tail", Two_Args ("-c+4", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "tail -c+4 compact output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -c+4 status");

      Context.Initialize ("tail", Five_Args ("-n", "1", "-c", "2", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ef", "tail later -c overrides earlier -n");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail later -c status");

      Context.Initialize ("tail", Five_Args ("-c", "2", "-n", "1", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "tail later -n overrides earlier -c");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail later -n status");
   end Test_Tail_Compact_Counts;

   procedure Test_Tail_Follow_Live (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-follow-option.txt");
      Reopen  : constant String := Fixture_Path ("reg-tail-follow-reopen.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF);

      Context.Initialize ("tail", Four_Args ("-f", "-n", "1", Path));
      Test_Contexts.Set_Tail_Follow_Poll_Limit (Context, 2);
      Test_Contexts.Set_Tail_Follow_Append (Context, Path, 1, "c" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail -f live output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail -f live diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail -f live status");

      Write_File (Path, "a" & LF & "b" & LF);
      Context.Initialize ("tail", Four_Args ("-n", "1", "-f", Path));
      Test_Contexts.Set_Tail_Follow_Poll_Limit (Context, 2);
      Test_Contexts.Set_Tail_Follow_Append (Context, Path, 1, "c" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail -f after count live output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail -f after count live diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail -f after count live status");

      Write_File (Reopen, "older" & LF);
      Context.Initialize ("tail", Four_Args ("-F", "-n", "1", Reopen));
      Test_Contexts.Set_Tail_Follow_Poll_Limit (Context, 2);
      Test_Contexts.Set_Tail_Follow_Replace (Context, Reopen, 1, "n" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "older" & LF & "n" & LF, "tail -F reopen output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail -F reopen diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail -F reopen status");

      Write_File (Path, "a" & LF & "b" & LF);
      Context.Initialize ("tail", Four_Args ("--follow", "-n", "1", Path));
      Test_Contexts.Set_Tail_Follow_Poll_Limit (Context, 2);
      Test_Contexts.Set_Tail_Follow_Append (Context, Path, 1, "c" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail --follow live output");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail --follow live diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail --follow live status");

      Ada.Directories.Delete_File (Path);
      Ada.Directories.Delete_File (Reopen);
   end Test_Tail_Follow_Live;

   procedure Test_Tail_Plus_Origin (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-plus.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF & "c" & LF);

      Context.Initialize ("tail", Three_Args ("-n", "+2", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF & "c" & LF,
         "tail -n +2 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -n +2 status");

      Context.Initialize ("tail", Two_Args ("-n+2", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail -n+2 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -n+2 status");
   end Test_Tail_Plus_Origin;

   procedure Test_Tail_Invalid_Count (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("tail", One_Arg ("-cabc"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "tail invalid count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: invalid count '-cabc'" & Character'Val (10),
         "tail invalid count diagnostic");

      Context.Initialize ("tail", Two_Args ("-n", "-1"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail negative count status");

      Context.Initialize ("tail", Two_Args ("-n", "+"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail lone plus count status");

      Context.Initialize ("tail", Two_Args ("-c", "9223372036854775808"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail overflow count status");

      Context.Initialize ("tail", One_Arg ("-n"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail missing -n count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: missing option argument '-n'" & Character'Val (10),
         "tail missing -n diagnostic");

      Context.Initialize ("tail", One_Arg ("-c"));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tail missing -c count status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: missing option argument '-c'" & Character'Val (10),
         "tail missing -c diagnostic");
   end Test_Tail_Invalid_Count;

   procedure Test_Tail_Line_Mode_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-tail-line-mode.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a" & LF & "b" & LF & "c");

      Context.Initialize ("tail", One_Arg (Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF & "c",
         "tail default ten lines from end output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail default ten lines from end status");

      Context.Initialize ("tail", Three_Args ("-n", "0", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail -n 0 output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail -n 0 status");

      Context.Initialize ("tail", Three_Args ("-n", "20", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & LF & "b" & LF & "c",
         "tail line count larger than input output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail line count larger than input status");

      Context.Initialize ("tail", Three_Args ("-n", "1", Path));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "c", "tail final partial line output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail final partial status");

      Context.Initialize ("tail", Three_Args ("-n", "2", Path));
      Test_Contexts.Set_Tail_Resource_Limits (Context, 2, 64);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF & "c",
         "tail line spill final partial output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail line spill final partial status");

      Context.Initialize ("tail", Three_Args ("-n", "2", Path));
      Test_Contexts.Set_Tail_Resource_Limits (Context, 2, 4);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail line max spill failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "tail: count too large" & LF,
         "tail line max spill diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail line max spill failure status");
   end Test_Tail_Line_Mode_Edges;

   procedure Test_Tail_Multiple_File_Headers (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-tail-head-first.txt");
      Second  : constant String := Fixture_Path ("reg-tail-head-second.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (First, "a" & LF & "b" & LF);
      Write_File (Second, "c" & LF & "d" & LF);

      Context.Initialize ("tail", Four_Args ("-n", "1", First, Second));
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> " & First & " <==" & LF
           & "b" & LF
           & LF
           & "==> " & Second & " <==" & LF
           & "d" & LF,
         "tail multiple file headers");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail header status");
   end Test_Tail_Multiple_File_Headers;

   procedure Test_Tail_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("tail", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF & "c" & LF, "tail stdin output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail stdin status");

      Context.Initialize ("tail", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Test_Contexts.Set_Tail_Resource_Limits (Context, 2, 64);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & LF & "c" & LF,
         "tail stdin line spill output");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "tail stdin line spill status");

      Context.Initialize ("tail", Four_Args ("-n", "1", "-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "==> - <==" & LF
           & "b" & LF
           & LF
           & "==> - <==" & LF,
         "tail repeated stdin is not rewound");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tail repeated stdin status");

      Context.Initialize ("tail", Three_Args ("-n", "1", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "tail stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "tail: 'standard input': cannot read file" & LF,
         "tail stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail stdin read failure status");
   end Test_Tail_Standard_Input;

   procedure Test_Tail_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("tail", Three_Args ("-n", "2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & LF & "b" & LF & "c" & LF);
      Test_Contexts.Set_Output_Failure_After (Context, 2);
      Posix_Tools.Commands.Tail.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & LF, "tail stops after failed write");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "tail output failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tail output failure status");
   end Test_Tail_Output_Failure;

   procedure Test_Tail_Byte_Suffix_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-tail-c.bin");
      Seed    : Word_32 := 16#5441_494C#;
      Counts  : constant Count_Array := [0, 1, 2, 7, 32, 255, 2048];
      Lengths : constant Length_Array := [0, 1, 2, 31, 256, 1025];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Expected_Suffix (Data : String; Count : Natural) return String is
      begin
         if Count = 0 then
            return "";
         elsif Count >= Data'Length then
            return Data;
         else
            return Data (Data'Last - Count + 1 .. Data'Last);
         end if;
      end Expected_Suffix;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Character'Val (Natural ((Seed / 16#0100_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            Result (I) := Next_Byte;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            Write_File (Path, Data);

            for Count of Counts loop
               Context.Initialize ("tail", Three_Args ("-c", Decimal_Image (Count), Path));
               Posix_Tools.Commands.Tail.Run (Context, Result);
               AUnit.Assertions.Assert
                 (Test_Contexts.Output (Context) = Expected_Suffix (Data, Count),
                  "tail -c property seed 0x5441494C length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Success,
                  "tail -c property status seed 0x5441494C length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
            end loop;
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Tail_Byte_Suffix_Property;

   procedure Test_Tail_Standard_Input_Byte_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      Seed    : Word_32 := 16#5441_4953#;
      Counts  : constant Count_Array := [0, 1, 2, 9, 64, 512];
      Lengths : constant Length_Array := [0, 1, 8, 65, 300, 900];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Expected_Suffix (Data : String; Count : Natural) return String is
      begin
         if Count = 0 then
            return "";
         elsif Count >= Data'Length then
            return Data;
         else
            return Data (Data'Last - Count + 1 .. Data'Last);
         end if;
      end Expected_Suffix;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_103_515_245 + 12_345;
         return Character'Val (Natural ((Seed / 16#0001_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            Result (I) := Next_Byte;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            for Count of Counts loop
               declare
                  Context : Test_Contexts.Capturing_Context;
                  Result  : Posix_Tools.Commands.Results.Result;
               begin
                  Context.Initialize ("tail", Two_Args ("-c", Decimal_Image (Count)));
                  Test_Contexts.Set_Standard_Input (Context, Data);
                  Posix_Tools.Commands.Tail.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Test_Contexts.Output (Context) = Expected_Suffix (Data, Count),
                     "tail stdin -c property seed 0x54414953 length"
                     & Natural'Image (Length) & " count" & Natural'Image (Count));
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success,
                     "tail stdin -c property status seed 0x54414953 length"
                     & Natural'Image (Length) & " count" & Natural'Image (Count));
               end;
            end loop;
         end;
      end loop;
   end Test_Tail_Standard_Input_Byte_Property;

   procedure Test_Tail_Line_Suffix_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-tail-n.bin");
      LF      : constant Character := Character'Val (10);
      Seed    : Word_32 := 16#5441_494E#;
      Counts  : constant Count_Array := [0, 1, 2, 5, 17, 64];
      Lengths : constant Length_Array := [0, 1, 12, 13, 63, 257, 1024];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Line_Count (Data : String) return Natural is
         Result : Natural := 0;
      begin
         for Ch of Data loop
            if Ch = LF then
               Result := Result + 1;
            end if;
         end loop;

         if Data'Length > 0 and then Data (Data'Last) /= LF then
            Result := Result + 1;
         end if;

         return Result;
      end Line_Count;

      function Expected_Line_Suffix (Data : String; Count : Natural) return String is
         Lines_To_Skip : constant Natural := (if Line_Count (Data) > Count then Line_Count (Data) - Count else 0);
         Skipped       : Natural := 0;
      begin
         if Count = 0 or else Data'Length = 0 then
            return "";
         elsif Lines_To_Skip = 0 then
            return Data;
         end if;

         for I in Data'Range loop
            if Data (I) = LF then
               Skipped := Skipped + 1;
               if Skipped = Lines_To_Skip then
                  if I = Data'Last then
                     return "";
                  else
                     return Data (I + 1 .. Data'Last);
                  end if;
               end if;
            end if;
         end loop;

         return Data;
      end Expected_Line_Suffix;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Character'Val (Natural ((Seed / 16#0100_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            if I mod 13 = 0 then
               Result (I) := LF;
            else
               Result (I) := Next_Byte;
            end if;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            Write_File (Path, Data);

            for Count of Counts loop
               Context.Initialize ("tail", Three_Args ("-n", Decimal_Image (Count), Path));
               Posix_Tools.Commands.Tail.Run (Context, Result);
               AUnit.Assertions.Assert
                 (Test_Contexts.Output (Context) = Expected_Line_Suffix (Data, Count),
                  "tail -n property seed 0x5441494E length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Success,
                  "tail -n property status seed 0x5441494E length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
            end loop;
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Tail_Line_Suffix_Property;

   procedure Test_Usage_Errors (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      ESC     : constant Character := Character'Val (16#1B#);
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("dirname", Two_Args ("first", "second"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "dirname extra status");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: extra operand 'second'" & LF,
         "dirname extra diagnostic");

      Context.Initialize ("dirname", Two_Args ("first", "bad" & LF & ESC & "[31m"));
      Posix_Tools.Commands.Dirname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "dirname: extra operand 'bad\x0A\x1B[31m'" & LF,
         "usage diagnostic escapes control characters");

      Context.Initialize ("cat", One_Arg (Fixture_Path ("missing" & LF & ESC & "[31m")));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "cat: '" & Fixture_Path ("missing\x0A\x1B[31m") & "': cannot read file" & LF,
         "subject diagnostic escapes control characters");

      Context.Initialize ("posix-tools", One_Arg ("unknown"));
      Posix_Tools.Commands.Root.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "root unknown status");
   end Test_Usage_Errors;

   procedure Test_True (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("true", One_Arg ("ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true status");
   end Test_True;

   procedure Test_True_Extension_Edges (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("true", One_Arg ("--help"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "Usage: true [OPTION]... [OPERAND]..." & LF
           & "Ada implementation in the posix-tools package." & LF
           & "Options:" & LF
           & "  --help     display this help and exit" & LF
           & "  --version  display version information and exit" & LF,
         "true sole help");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true help status");

      Context.Initialize ("true", Two_Args ("--help", "ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true non-sole help ignored");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true non-sole help status");

      Context.Initialize ("true", Two_Args ("--posix-tools-identify", "ignored"));
      Posix_Tools.Commands.True_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "true non-sole identity ignored");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "true non-sole identity status");
   end Test_True_Extension_Edges;

   procedure Test_True_False_Operand_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;

      Seed : Word_32 := 16#7F00_F15E#;

      function Next_Value return Natural is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Natural ((Seed / 16#0100_0000#) mod 256);
      end Next_Value;

      function Generated_Operand (Argument_Index : Positive) return String is
         Choices : constant Natural := Next_Value mod 9;
         Length  : Natural;
         Result  : Ada.Strings.Unbounded.Unbounded_String;
      begin
         case Choices is
            when 0 =>
               return "";
            when 1 =>
               return "-n";
            when 2 =>
               return "--";
            when 3 =>
               return "--help";
            when 4 =>
               return "--version";
            when 5 =>
               return "--posix-tools-identify";
            when others =>
               Length := 1 + Next_Value mod 8;
               for I in 1 .. Length loop
                  Ada.Strings.Unbounded.Append
                    (Result,
                     Character'Val
                       (Character'Pos ('a') + (Argument_Index + I + Next_Value) mod 26));
               end loop;
               return Ada.Strings.Unbounded.To_String (Result);
         end case;
      end Generated_Operand;

      function Sole_Extension (Operand : String) return Boolean is
      begin
         return Operand = "--help"
           or else Operand = "--version"
           or else Operand = "--posix-tools-identify";
      end Sole_Extension;
   begin
      for Case_Index in 1 .. 64 loop
         declare
            True_Context  : Test_Contexts.Capturing_Context;
            False_Context : Test_Contexts.Capturing_Context;
            True_Result   : Posix_Tools.Commands.Results.Result;
            False_Result  : Posix_Tools.Commands.Results.Result;
            Args          : Posix_Tools.Arguments.Vector;
            Arg_Count     : constant Natural := Next_Value mod 9;
            Label         : constant String :=
              "true false operand property seed 0x7F00F15E case" & Natural'Image (Case_Index);
         begin
            for Index in 1 .. Arg_Count loop
               declare
                  Generated : constant String := Generated_Operand (Index);
                  Operand   : constant String :=
                    (if Arg_Count = 1 and then Sole_Extension (Generated) then "ordinary" else Generated);
               begin
                  Args.Append (Operand);
               end;
            end loop;

            True_Context.Initialize ("true", Args);
            Posix_Tools.Commands.True_Command.Run (True_Context, True_Result);
            AUnit.Assertions.Assert (Test_Contexts.Output (True_Context) = "", Label & " true output");
            AUnit.Assertions.Assert (Test_Contexts.Error_Output (True_Context) = "", Label & " true stderr");
            AUnit.Assertions.Assert
              (True_Result.Status = Posix_Tools.Exit_Status.Success,
               Label & " true status");

            False_Context.Initialize ("false", Args);
            Posix_Tools.Commands.False_Command.Run (False_Context, False_Result);
            AUnit.Assertions.Assert (Test_Contexts.Output (False_Context) = "", Label & " false output");
            AUnit.Assertions.Assert (Test_Contexts.Error_Output (False_Context) = "", Label & " false stderr");
            AUnit.Assertions.Assert
              (False_Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
               Label & " false status");
         end;
      end loop;
   end Test_True_False_Operand_Property;

   procedure Test_Tty (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("tty", No_Args);
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, True);
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "/dev/test-tty" & Character'Val (10),
         "tty prints the terminal name");

      Context.Initialize ("tty", No_Args);
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, False);
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "not a tty" & Character'Val (10),
         "tty reports non-terminal standard input");

      Context.Initialize ("tty", One_Arg ("-s"));
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, False);
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "tty -s suppresses output");

      Context.Initialize ("tty", One_Arg ("-x"));
      Posix_Tools.Commands.Tty.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tty rejects unknown options");
   end Test_Tty;

   procedure Test_Wc_Text_Counts (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-wc-utf8.txt");
   begin
      Write_File (Path, "A " & Character'Val (16#C3#) & Character'Val (16#A6#) & Character'Val (10));

      Context.Initialize ("wc", Two_Args ("-m", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "4 " & Path & Character'Val (10), "wc -m output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -m status");
   end Test_Wc_Text_Counts;

   procedure Test_Wc_Default_And_Mixed_Text (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-wc-default.txt");
      Invalid : constant String := Fixture_Path ("reg-wc-mixed-invalid.bin");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (Path, "a b" & LF & "c");

      Context.Initialize ("wc", One_Arg (Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1 3 5 " & Path & LF,
         "wc default field order");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc default status");

      Write_File (Invalid, "A" & Character'Val (16#C3#));
      Context.Initialize ("wc", One_Arg (Invalid));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc default invalid suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Invalid & "': invalid UTF-8" & LF,
         "wc default invalid diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc default invalid status");

      Context.Initialize ("wc", Two_Args ("-cm", Invalid));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc mixed invalid suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Invalid & "': invalid UTF-8" & LF,
         "wc mixed invalid diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc mixed invalid status");

      Write_File (Path, "ab" & LF & Character'Val (9) & "c" & LF & "abcd");
      Context.Initialize ("wc", Two_Args ("-L", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "9 " & Path & LF,
         "wc -L maximum line length output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -L status");

      Context.Initialize ("wc", Two_Args ("-lL", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "2 9 " & Path & LF,
         "wc -lL output ordering");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "wc -lL status");
   end Test_Wc_Default_And_Mixed_Text;

   procedure Test_Wc_Text_Invalid_UTF_8 (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("reg-wc-invalid.bin");
   begin
      Write_File (Path, "A" & Character'Val (16#C3#));

      Context.Initialize ("wc", Two_Args ("-c", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "2 " & Path & Character'Val (10), "wc -c raw output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -c raw status");

      Context.Initialize ("wc", Two_Args ("-l", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "0 " & Path & Character'Val (10), "wc -l raw output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -l raw status");

      Context.Initialize ("wc", Two_Args ("-cl", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0 2 " & Path & Character'Val (10),
         "wc -cl raw output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc -cl raw status");

      Context.Initialize ("wc", Two_Args ("-m", Path));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc -m invalid suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Path & "': invalid UTF-8" & Character'Val (10),
         "wc -m invalid diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc -m invalid status");
   end Test_Wc_Text_Invalid_UTF_8;

   procedure Test_Wc_Text_Malformed_UTF_8 (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Overlong : constant String := Fixture_Path ("reg-wc-overlong.bin");
      Bad_Continuation : constant String := Fixture_Path ("reg-wc-bad-continuation.bin");
      Surrogate : constant String := Fixture_Path ("reg-wc-surrogate.bin");
      Out_Of_Range : constant String := Fixture_Path ("reg-wc-out-of-range.bin");
   begin
      Write_File (Overlong, Character'Val (16#C0#) & Character'Val (16#AF#));
      Context.Initialize ("wc", Two_Args ("-m", Overlong));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc overlong suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Overlong & "': invalid UTF-8" & Character'Val (10),
         "wc overlong diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc overlong status");

      Write_File (Bad_Continuation, Character'Val (16#E2#) & "A");
      Context.Initialize ("wc", Two_Args ("-w", Bad_Continuation));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc bad continuation suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "wc: '" & Bad_Continuation & "': invalid UTF-8" & Character'Val (10),
         "wc bad continuation diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc bad continuation status");

      Write_File
        (Surrogate,
         Character'Val (16#ED#) & Character'Val (16#A0#) & Character'Val (16#80#));
      Context.Initialize ("wc", Two_Args ("-m", Surrogate));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc surrogate suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: '" & Surrogate & "': invalid UTF-8" & Character'Val (10),
         "wc surrogate diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc surrogate status");

      Write_File
        (Out_Of_Range,
         Character'Val (16#F4#) & Character'Val (16#90#)
         & Character'Val (16#80#) & Character'Val (16#80#));
      Context.Initialize ("wc", Two_Args ("-m", Out_Of_Range));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc out-of-range suppresses output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "wc: '" & Out_Of_Range & "': invalid UTF-8" & Character'Val (10),
         "wc out-of-range diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc out-of-range status");
   end Test_Wc_Text_Malformed_UTF_8;

   procedure Test_Wc_Multiple_Files (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      First   : constant String := Fixture_Path ("reg-wc-first.txt");
      Second  : constant String := Fixture_Path ("reg-wc-second.txt");
      LF      : constant Character := Character'Val (10);
   begin
      Write_File (First, "a b" & LF);
      Write_File (Second, "c" & LF & "d" & LF);

      Context.Initialize ("wc", Three_Args ("-lw", First, Second));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1 2 " & First & LF
           & "2 2 " & Second & LF
           & "3 4 total" & LF,
         "wc multiple file totals");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc multiple status");

      Context.Initialize ("wc", Four_Args ("-l", First, Fixture_Path ("reg-wc-missing.txt"), Second));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1 " & First & LF
           & "2 " & Second & LF
           & "3 total" & LF,
         "wc totals successful files after failed file");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "reg-wc-missing.txt"),
         "wc missing file diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc failed file aggregate status");
   end Test_Wc_Multiple_Files;

   procedure Test_Wc_Standard_Input (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("wc", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a b" & LF);
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "1 2 4" & LF, "wc stdin default output");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc stdin default status");

      Context.Initialize ("wc", Three_Args ("-c", "-", "-"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "3 -" & LF
           & "0 -" & LF
           & "3 total" & LF,
         "wc repeated stdin is not rewound");
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "wc repeated stdin status");

      Context.Initialize ("wc", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a b" & LF);
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc stdin read failure output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) =
           "wc: 'standard input': cannot read file" & LF,
         "wc stdin read failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc stdin read failure status");
   end Test_Wc_Standard_Input;

   procedure Test_Wc_Byte_Count_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-wc-c.bin");
      LF      : constant Character := Character'Val (10);
      Seed    : Word_32 := 16#5EED_C0DE#;
      Lengths : constant Length_Array := [0, 1, 2, 7, 31, 64, 127, 256, 513];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_664_525 + 1_013_904_223;
         return Character'Val (Natural ((Seed / 16#0100_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            Result (I) := Next_Byte;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            Write_File (Path, Data);
            Context.Initialize ("wc", Two_Args ("-c", Path));
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Length) & " " & Path & LF,
               "wc -c property seed 0x5EEDC0DE length" & Natural'Image (Length));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc -c property status seed 0x5EEDC0DE length" & Natural'Image (Length));
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Wc_Byte_Count_Property;

   procedure Test_Wc_Standard_Input_Byte_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Length_Array is array (Positive range <>) of Natural;

      LF      : constant Character := Character'Val (10);
      Seed    : Word_32 := 16#57C0_0001#;
      Lengths : constant Length_Array := [0, 1, 4, 33, 128, 777];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_103_515_245 + 12_345;
         return Character'Val (Natural ((Seed / 16#0001_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            Result (I) := Next_Byte;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Context : Test_Contexts.Capturing_Context;
            Result  : Posix_Tools.Commands.Results.Result;
            Data    : constant String := Generated (Length);
         begin
            Context.Initialize ("wc", One_Arg ("-c"));
            Test_Contexts.Set_Standard_Input (Context, Data);
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Length) & LF,
               "wc stdin -c property seed 0x57C00001 length" & Natural'Image (Length));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc stdin -c property status seed 0x57C00001 length" & Natural'Image (Length));
         end;
      end loop;
   end Test_Wc_Standard_Input_Byte_Property;

   procedure Test_Wc_Line_Count_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-wc-l.bin");
      LF      : constant Character := Character'Val (10);
      Seed    : Word_32 := 16#1F1E_5EED#;
      Lengths : constant Length_Array := [0, 1, 3, 8, 17, 64, 129, 512, 1_025];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_103_515_245 + 12_345;
         if Seed mod 11 = 0 then
            return LF;
         end if;

         return Character'Val (Natural ((Seed / 16#0001_0000#) mod 255) + 1);
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            Result (I) := Next_Byte;
         end loop;

         return Result;
      end Generated;

      function LF_Count (Data : String) return Natural is
         Count : Natural := 0;
      begin
         for C of Data loop
            if C = LF then
               Count := Count + 1;
            end if;
         end loop;

         return Count;
      end LF_Count;
   begin
      for Length of Lengths loop
         declare
            Data  : constant String := Generated (Length);
            Lines : constant Natural := LF_Count (Data);
         begin
            Write_File (Path, Data);
            Context.Initialize ("wc", Two_Args ("-l", Path));
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Lines) & " " & Path & LF,
               "wc -l property seed 0x1F1E5EED length" & Natural'Image (Length)
               & " lines" & Natural'Image (Lines));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc -l property status seed 0x1F1E5EED length" & Natural'Image (Length));
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Wc_Line_Count_Property;

   procedure Test_Wc_Standard_Input_Line_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      type Word_32 is mod 2 ** 32;
      type Length_Array is array (Positive range <>) of Natural;

      LF      : constant Character := Character'Val (10);
      Seed    : Word_32 := 16#57C0_000A#;
      Lengths : constant Length_Array := [0, 1, 5, 34, 130, 778];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Next_Byte return Character is
      begin
         Seed := Seed * 1_103_515_245 + 12_345;
         if Seed mod 13 = 0 then
            return LF;
         end if;

         return Character'Val (Natural ((Seed / 16#0001_0000#) mod 255) + 1);
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            Result (I) := Next_Byte;
         end loop;

         return Result;
      end Generated;

      function LF_Count (Data : String) return Natural is
         Count : Natural := 0;
      begin
         for C of Data loop
            if C = LF then
               Count := Count + 1;
            end if;
         end loop;

         return Count;
      end LF_Count;
   begin
      for Length of Lengths loop
         declare
            Context : Test_Contexts.Capturing_Context;
            Result  : Posix_Tools.Commands.Results.Result;
            Data    : constant String := Generated (Length);
            Lines   : constant Natural := LF_Count (Data);
         begin
            Context.Initialize ("wc", One_Arg ("-l"));
            Test_Contexts.Set_Standard_Input (Context, Data);
            Posix_Tools.Commands.Wc.Run (Context, Result);
            AUnit.Assertions.Assert
              (Test_Contexts.Output (Context) = Decimal_Image (Lines) & LF,
               "wc stdin -l property seed 0x57C0000A length" & Natural'Image (Length)
               & " lines" & Natural'Image (Lines));
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success,
               "wc stdin -l property status seed 0x57C0000A length" & Natural'Image (Length));
         end;
      end loop;
   end Test_Wc_Standard_Input_Line_Property;

   procedure Test_Wc_Output_Failure (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("wc", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "0", "wc partial output before failure");
      AUnit.Assertions.Assert (Test_Contexts.Error_Output (Context) = "", "wc output failure diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "wc output failure status");
   end Test_Wc_Output_Failure;

   procedure Test_Yes (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      LF      : constant Character := Character'Val (10);
   begin
      Context.Initialize ("yes", No_Args);
      Test_Contexts.Set_Output_Failure_After (Context, 6);
      Posix_Tools.Commands.Yes.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "y" & LF & "y" & LF & "y" & LF,
         "yes repeats default y until output failure");

      Context.Initialize ("yes", Two_Args ("ok", "now"));
      Test_Contexts.Set_Output_Failure_After (Context, 14);
      Posix_Tools.Commands.Yes.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "ok now" & LF & "ok now" & LF,
         "yes repeats joined operands until output failure");
   end Test_Yes;
end Command_Tests;
