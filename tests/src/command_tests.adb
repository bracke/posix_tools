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
with Posix_Tools.Commands.Head;
with Posix_Tools.Commands.Id;
with Posix_Tools.Commands.Kill;
with Posix_Tools.Commands.Link;
with Posix_Tools.Commands.Ln;
with Posix_Tools.Commands.Logname;
with Posix_Tools.Commands.Ls;
with Posix_Tools.Commands.Mkdir;
with Posix_Tools.Commands.Mv;
with Posix_Tools.Commands.Nl;
with Posix_Tools.Commands.Od;
with Posix_Tools.Commands.Paste;
with Posix_Tools.Commands.Pathchk;
with Posix_Tools.Commands.Printf;
with Posix_Tools.Commands.Pwd;
with Posix_Tools.Commands.Readlink;
with Posix_Tools.Commands.Realpath;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rm;
with Posix_Tools.Commands.Rmdir;
with Posix_Tools.Commands.Root;
with Posix_Tools.Commands.Sleep;
with Posix_Tools.Commands.Split;
with Posix_Tools.Commands.Sort;
with Posix_Tools.Commands.Tail;
with Posix_Tools.Commands.Tee;
with Posix_Tools.Commands.Test_Command;
with Posix_Tools.Commands.Timeout;
with Posix_Tools.Commands.Touch;
with Posix_Tools.Commands.Tr;
with Posix_Tools.Commands.True_Command;
with Posix_Tools.Commands.Tty;
with Posix_Tools.Commands.Unexpand;
with Posix_Tools.Commands.Uname;
with Posix_Tools.Commands.Uniq;
with Posix_Tools.Commands.Wc;
with Posix_Tools.Commands.Whoami;
with Posix_Tools.Commands.Xargs;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Signals;
with Posix_Tools.Localization;
with Posix_Tools.Paths;
with Posix_Tools.Presentation;
with Posix_Tools.Version;
with Test_Contexts;

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

   function Contains (Text, Pattern : String) return Boolean is
   begin
      if Pattern = "" then
         return True;
      elsif Text'Length < Pattern'Length then
         return False;
      end if;

      for I in Text'First .. Text'Last - Pattern'Length + 1 loop
         if Text (I .. I + Pattern'Length - 1) = Pattern then
            return True;
         end if;
      end loop;

      return False;
   end Contains;

   procedure Run_Command_By_Name
     (Name    : String;
      Context : in out Test_Contexts.Capturing_Context;
      Result  : out Posix_Tools.Commands.Results.Result) is
   begin
      if Name = "basename" then
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
      elsif Name = "head" then
         Posix_Tools.Commands.Head.Run (Context, Result);
      elsif Name = "id" then
         Posix_Tools.Commands.Id.Run (Context, Result);
      elsif Name = "kill" then
         Posix_Tools.Commands.Kill.Run (Context, Result);
      elsif Name = "link" then
         Posix_Tools.Commands.Link.Run (Context, Result);
      elsif Name = "ln" then
         Posix_Tools.Commands.Ln.Run (Context, Result);
      elsif Name = "logname" then
         Posix_Tools.Commands.Logname.Run (Context, Result);
      elsif Name = "ls" then
         Posix_Tools.Commands.Ls.Run (Context, Result);
      elsif Name = "mkdir" then
         Posix_Tools.Commands.Mkdir.Run (Context, Result);
      elsif Name = "mv" then
         Posix_Tools.Commands.Mv.Run (Context, Result);
      elsif Name = "nl" then
         Posix_Tools.Commands.Nl.Run (Context, Result);
      elsif Name = "od" then
         Posix_Tools.Commands.Od.Run (Context, Result);
      elsif Name = "paste" then
         Posix_Tools.Commands.Paste.Run (Context, Result);
      elsif Name = "pathchk" then
         Posix_Tools.Commands.Pathchk.Run (Context, Result);
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
      elsif Name = "sleep" then
         Posix_Tools.Commands.Sleep.Run (Context, Result);
      elsif Name = "split" then
         Posix_Tools.Commands.Split.Run (Context, Result);
      elsif Name = "sort" then
         Posix_Tools.Commands.Sort.Run (Context, Result);
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
      elsif Name = "uname" then
         Posix_Tools.Commands.Uname.Run (Context, Result);
      elsif Name = "uniq" then
         Posix_Tools.Commands.Uniq.Run (Context, Result);
      elsif Name = "wc" then
         Posix_Tools.Commands.Wc.Run (Context, Result);
      elsif Name = "whoami" then
         Posix_Tools.Commands.Whoami.Run (Context, Result);
      elsif Name = "xargs" then
         Posix_Tools.Commands.Xargs.Run (Context, Result);
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

   procedure Test_Expanded_Command_Smoke (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Ada.Calendar.Time;
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Source  : constant String := Fixture_Path ("expanded-source.txt");
      Target  : constant String := Fixture_Path ("expanded-target.txt");
      Large_Source : constant String := Fixture_Path ("expanded-large-source.bin");
      Large_Target : constant String := Fixture_Path ("expanded-large-target.bin");
      Dash_Target : constant String := Fixture_Path ("expanded-dash-target.txt");
      Linked  : constant String := Fixture_Path ("expanded-linked.txt");
      Link_Command_Target : constant String := Fixture_Path ("expanded-link-command.txt");
      Symlinked : constant String := Fixture_Path ("expanded-symlinked.txt");
      Cp_Symlinked : constant String := Fixture_Path ("expanded-cp-symlinked.txt");
      Link_Dir : constant String := Fixture_Path ("expanded-ln-dir");
      Moved   : constant String := Fixture_Path ("expanded-moved.txt");
      Made    : constant String := Fixture_Path ("expanded-dir");
      Symbolic_Mode_Dir : constant String := Fixture_Path ("expanded-symbolic-mode-dir");
      Relative_Mode_Dir : constant String := Fixture_Path ("expanded-relative-mode-dir");
      Remove_Dir : constant String := Fixture_Path ("expanded-rm-dir");
      Rm_Interactive : constant String := Fixture_Path ("expanded-rm-interactive.txt");
      Multi   : constant String := Fixture_Path ("expanded-multi");
      Other   : constant String := Fixture_Path ("expanded-other.txt");
      Tree    : constant String := Fixture_Path ("expanded-tree");
      Tree_Copy : constant String := Fixture_Path ("expanded-tree-copy");
      Sort_Out : constant String := Fixture_Path ("expanded-sort-output.txt");
      Empty   : constant String := Fixture_Path ("expanded-empty");
      Cp_Directory_Source : constant String := Fixture_Path ("expanded-cp-directory-source");
      Cp_Directory_Target : constant String := Fixture_Path ("expanded-cp-directory-target");
      Cp_FIFO_Source : constant String := Fixture_Path ("expanded-cp-fifo-source");
      Cp_FIFO_Target : constant String := Fixture_Path ("expanded-cp-fifo-target");
      Cp_Socket_Source : constant String := Fixture_Path ("expanded-cp-socket-source");
      Cp_Socket_Target : constant String := Fixture_Path ("expanded-cp-socket-target");
      Parent_Block : constant String := Fixture_Path ("expanded-parent-block");
      Option_Dir : constant String := Fixture_Path ("expanded-option-operands");
      Touched : constant String := Fixture_Path ("expanded-touch.txt");
      No_Create : constant String := Fixture_Path ("expanded-no-create.txt");
      Tee_Out : constant String := Fixture_Path ("expanded-tee.txt");
      Chmod_Target : constant String := Fixture_Path ("expanded-chmod.txt");
      Cksum_File : constant String := Fixture_Path ("expanded-cksum.txt");
      Cmp_First : constant String := Fixture_Path ("expanded-cmp-first.txt");
      Cmp_Second : constant String := Fixture_Path ("expanded-cmp-second.txt");
      Paste_First : constant String := Fixture_Path ("expanded-paste-first.txt");
      Paste_Second : constant String := Fixture_Path ("expanded-paste-second.txt");
      Cut_File : constant String := Fixture_Path ("expanded-cut.txt");
      Comm_First : constant String := Fixture_Path ("expanded-comm-first.txt");
      Comm_Second : constant String := Fixture_Path ("expanded-comm-second.txt");
      Od_File : constant String := Fixture_Path ("expanded-od.bin");
      Ls_Dir : constant String := Fixture_Path ("expanded-ls-dir");
      Ls_Other_Dir : constant String := Fixture_Path ("expanded-ls-other-dir");
      Split_Input : constant String := Fixture_Path ("expanded-split.txt");
      Split_Prefix : constant String := Fixture_Path ("expanded-split-out-");
      Split_Long_Prefix : constant String := Fixture_Path ("expanded-split-long-");
      EOL     : constant Character := Character'Val (10);

      procedure Remove_Any (Path : String) is
      begin
         if Hostkit.Fs.Is_Link (Path) then
            AUnit.Assertions.Assert (Hostkit.Fs.Delete_Link (Path), "cleanup link failed for " & Path);
         elsif Ada.Directories.Exists (Path) then
            if Ada.Directories.Kind (Path) = Ada.Directories.Directory then
               Ada.Directories.Delete_Tree (Path);
            else
               declare
                  Deleted : Boolean := False;
               begin
                  GNAT.OS_Lib.Delete_File (Path, Deleted);
                  if not Deleted then
                     Ada.Directories.Delete_File (Path);
                  end if;
               end;
            end if;
         end if;
      exception
         when others =>
            AUnit.Assertions.Assert (False, "cleanup failed for " & Path);
      end Remove_Any;

      procedure Assert_Mode_When_Available (Path : String; Expected : Natural; Label : String) is
         Available : Boolean;
         Actual    : constant Natural := Hostkit.Metadata.File_Permission_Bits (Path, Available);
      begin
         if Hostkit.Metadata.Permissions_Supported and then Available then
            AUnit.Assertions.Assert (Actual mod 8#1000# = Expected, Label);
         end if;
      end Assert_Mode_When_Available;

      procedure Assert_Full_Mode_When_Available (Path : String; Expected : Natural; Label : String) is
         Available : Boolean;
         Actual    : constant Natural := Hostkit.Metadata.File_Permission_Bits (Path, Available);
      begin
         if Hostkit.Metadata.Permissions_Supported and then Available then
            AUnit.Assertions.Assert (Actual mod 8#10000# = Expected, Label);
         end if;
      end Assert_Full_Mode_When_Available;

      function Time_Near (Actual, Expected : Ada.Calendar.Time) return Boolean is
         Difference : constant Duration := Actual - Expected;
      begin
         return abs Difference <= 2.0;
      end Time_Near;

      function Large_Copy_Data return String is
         Data : String (1 .. 70 * 1024);
      begin
         for I in Data'Range loop
            Data (I) := Character'Val ((I - Data'First) mod 256);
         end loop;

         return Data;
      end Large_Copy_Data;

      function Trim_Natural (Value : Natural) return String is
      begin
         return Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Left);
      end Trim_Natural;
   begin
      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Large_Source);
      Remove_Any (Large_Target);
      Remove_Any (Dash_Target);
      Remove_Any (Linked);
      Remove_Any (Link_Command_Target);
      Remove_Any (Symlinked);
      Remove_Any (Cp_Symlinked);
      Remove_Any (Link_Dir);
      Remove_Any (Moved);
      Remove_Any (Made);
      Remove_Any (Symbolic_Mode_Dir);
      Remove_Any (Relative_Mode_Dir);
      Remove_Any (Remove_Dir);
      Remove_Any (Rm_Interactive);
      Remove_Any (Multi);
      Remove_Any (Other);
      Remove_Any (Tree);
      Remove_Any (Tree_Copy);
      Remove_Any (Sort_Out);
      Remove_Any (Empty);
      Remove_Any (Cp_Directory_Source);
      Remove_Any (Cp_Directory_Target);
      Remove_Any (Cp_FIFO_Source);
      Remove_Any (Cp_FIFO_Target);
      Remove_Any (Cp_Socket_Source);
      Remove_Any (Cp_Socket_Target);
      Remove_Any (Parent_Block);
      Remove_Any (Option_Dir);
      Remove_Any (Touched);
      Remove_Any (No_Create);
      Remove_Any (Tee_Out);
      Remove_Any (Chmod_Target);
      Remove_Any (Cksum_File);
      Remove_Any (Cmp_First);
      Remove_Any (Cmp_Second);
      Remove_Any (Paste_First);
      Remove_Any (Paste_Second);
      Remove_Any (Cut_File);
      Remove_Any (Comm_First);
      Remove_Any (Comm_Second);
      Remove_Any (Od_File);
      Remove_Any (Ls_Dir);
      Remove_Any (Ls_Other_Dir);
      Remove_Any (Split_Input);
      Remove_Any (Split_Prefix & "aa");
      Remove_Any (Split_Prefix & "ab");
      Remove_Any (Split_Long_Prefix & "aaa");
      Remove_Any (Split_Long_Prefix & "aab");
      Remove_Any (Split_Long_Prefix & "aac");

      Write_File (Source, "copy-data");
      Context.Initialize ("cp", Two_Args (Source, Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp status");

      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "copy-data", "cp copied data");

      declare
         Data : constant String := Large_Copy_Data;
      begin
         Write_File (Large_Source, Data);
         Context.Initialize ("cp", Two_Args (Large_Source, Large_Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "REG-CP-0001 cp copies large binary file");

         Context.Initialize ("cat", One_Arg (Large_Target));
         Posix_Tools.Commands.Cat.Run (Context, Result);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Data,
            "REG-CP-0001 cp preserves large binary file bytes");
      end;

      Ada.Directories.Create_Directory (Option_Dir);
      Ada.Directories.Create_Directory (Hostkit.Fs.Join (Option_Dir, "copies"));
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "plain-data");
      Write_File (Hostkit.Fs.Join (Option_Dir, "-v"), "dash-data");
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("cp", Three_Args ("plain", "-v", "copies"));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Hostkit.Fs.Join (Option_Dir, "copies"), "plain"))
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Hostkit.Fs.Join (Option_Dir, "copies"), "-v")),
         "cp treats option-like words after first operand as operands");

      Context.Initialize ("cp", Two_Args (Source, Source));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "same file"),
         "cp rejects same source and destination");

      Ada.Directories.Create_Directory (Cp_Directory_Source);
      Context.Initialize ("cp", Two_Args (Cp_Directory_Source, Cp_Directory_Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "is a directory"),
         "cp diagnoses non-recursive directory source");

      Remove_Any (Linked);
      if Hostkit.Fs.Create_Hard_Link (Source, Linked) then
         Context.Initialize ("cp", Two_Args (Source, Linked));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
            and then Contains (Test_Contexts.Error_Output (Context), "same file"),
            "cp rejects destination hard link to source");
         Remove_Any (Linked);
      end if;

      if Hostkit.Fs.Create_Link (Source, Symlinked) then
         declare
            Target_Text : Unbounded_String;
         begin
            Remove_Any (Target);
            Context.Initialize ("cp", Three_Args ("-P", Symlinked, Cp_Symlinked));
            Posix_Tools.Commands.Cp.Run (Context, Result);
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success
               and then Hostkit.Fs.Is_Link (Cp_Symlinked)
               and then Hostkit.Fs.Read_Link_Target (Cp_Symlinked, Target_Text)
               and then To_String (Target_Text) = Source,
               "cp -P copies symbolic link itself");

            Remove_Any (Symlinked);
            Remove_Any (Cp_Symlinked);
         end;
      end if;

      if Hostkit.Metadata.Permissions_Supported then
         GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
           (Source,
            GNAT.OS_Lib.GM_Time_Of (2022, 3, 4, 5, 6, 7));
         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#640#),
            "test source mode setup");
         Remove_Any (Target);
         Context.Initialize ("cp", Three_Args ("-p", Source, Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -p status");
         Assert_Mode_When_Available (Target, 8#640#, "cp -p preserves source mode");
         AUnit.Assertions.Assert
           (Time_Near (Ada.Directories.Modification_Time (Target), Ada.Directories.Modification_Time (Source)),
            "cp -p preserves source modification time");
         declare
            Source_User      : Natural;
            Source_Group     : Natural;
            Source_Available : Boolean;
            Target_User      : Natural;
            Target_Group     : Natural;
            Target_Available : Boolean;
         begin
            Hostkit.Metadata.File_Ownership (Source, Source_User, Source_Group, Source_Available);
            Hostkit.Metadata.File_Ownership (Target, Target_User, Target_Group, Target_Available);
            if Hostkit.Metadata.Ownership_Supported and then Source_Available and then Target_Available then
               AUnit.Assertions.Assert
                 (Source_User = Target_User and then Source_Group = Target_Group,
                  "cp -p preserves source ownership when available");
            end if;
         end;
         Write_File (Source, "copy-data");
      end if;

      Context.Initialize ("cp", Two_Args ("-", Dash_Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cp treats - as missing file operand");

      if Ada.Directories.Exists ("/dev/null")
        and then Ada.Directories.Kind ("/dev/null") = Ada.Directories.Special_File
      then
         Context.Initialize ("cp", Two_Args ("/dev/null", Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "cp reports portable special file creation failure");
      end if;

      if Hostkit.Fs.Create_FIFO (Cp_FIFO_Source, 8#600#) then
         Context.Initialize ("cp", Two_Args (Cp_FIFO_Source, Cp_FIFO_Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         declare
            Info : constant Hostkit.Fs.Special_File_Info := Hostkit.Fs.Special_File_Info_Of (Cp_FIFO_Target);
         begin
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success
               and then Info.Available
               and then Info.Kind = Hostkit.Fs.FIFO,
               "REG-CP-0003 cp recreates FIFO special files through hostkit");
         end;
      end if;

      if Hostkit.Fs.Create_Socket (Cp_Socket_Source, 8#600#) then
         Context.Initialize ("cp", Two_Args (Cp_Socket_Source, Cp_Socket_Target));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         declare
            Info : constant Hostkit.Fs.Special_File_Info := Hostkit.Fs.Special_File_Info_Of (Cp_Socket_Target);
         begin
            AUnit.Assertions.Assert
              (Result.Status = Posix_Tools.Exit_Status.Success
               and then Info.Available
               and then Info.Kind = Hostkit.Fs.Socket,
               "REG-CP-0004 cp recreates Unix-domain socket files through hostkit");
         end;
      end if;

      Ada.Directories.Create_Directory (Tree);
      Write_File (Tree & "/child.txt", "child");
      Write_File (Target, "ordinary-target");
      Context.Initialize ("cp", Three_Args ("-R", Tree, Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "not a directory"),
         "cp -R rejects existing non-directory destination");
      Remove_Any (Tree);

      Context.Initialize ("cp", Two_Args ("-fp", Source));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cp grouped -fp still requires target");

      Context.Initialize ("cp", Two_Args ("-i", Source));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cp accepts -i before validating operands");

      Write_File (Target, "existing-data");
      Context.Initialize ("cp", Three_Args ("-i", Source, Target));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Error_Output (Context) = "cp: overwrite '" & Target & "'?" & EOL,
         "cp -i declines overwrite status and prompt");
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "existing-data", "cp -i decline preserves target");

      Context.Initialize ("cp", Three_Args ("-i", Source, Target));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -i confirms status");
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "copy-data", "cp -i confirm overwrites target");

      Write_File (Target, "existing-data");
      Context.Initialize ("cp", Three_Args ("-if", Source, Target));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Error_Output (Context) = "",
         "cp -if uses final force option");
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "copy-data", "cp -if overwrites target");

      Write_File (Target, "existing-data");
      Context.Initialize ("cp", Three_Args ("-fi", Source, Target));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -fi uses final interactive option");
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "existing-data", "cp -fi preserves target");

      Context.Initialize ("cp", Three_Args ("-i", Source, Target));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Error_Output (Context) = "cp: overskriv '" & Target & "'?" & EOL,
         "REG-CP-0002 cp localizes interactive overwrite prompt");

      Ada.Directories.Create_Path (Tree & "/sub");
      Write_File (Tree & "/sub/file.txt", "tree-data");
      Context.Initialize ("cp", Three_Args ("-R", Tree, Tree_Copy));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -R status");
      Context.Initialize ("cat", One_Arg (Tree_Copy & "/sub/file.txt"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "tree-data", "cp -R copied nested data");

      Context.Initialize ("cp", Three_Args ("-R", Tree, Tree & "/inside"));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Error_Output (Context), "same file")
         and then not Ada.Directories.Exists (Tree & "/inside"),
         "cp -R rejects copying directory into itself");

      Remove_Any (Tree_Copy);
      Context.Initialize ("cp", Three_Args ("-Rp", Tree, Tree_Copy));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "cp -Rp status");

      Context.Initialize ("ln", Two_Args (Source, Linked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "ln status");
      AUnit.Assertions.Assert (Hostkit.Metadata.Same_File (Source, Linked), "ln creates hard link");

      Remove_Any (Linked);
      Context.Initialize ("ln", Three_Args ("--", Source, Linked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "ln -- status");
      AUnit.Assertions.Assert (Hostkit.Metadata.Same_File (Source, Linked), "ln -- creates hard link");

      Write_File (Linked, "old-link-target");
      Write_File (Source, "copy-data");
      Context.Initialize ("ln", Three_Args ("-f", Source, Linked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "ln -f status");
      Context.Initialize ("cat", One_Arg (Linked));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "copy-data", "ln -f replaced target data");
      AUnit.Assertions.Assert (Hostkit.Metadata.Same_File (Source, Linked), "ln -f creates hard link");

      Remove_Any (Linked);
      Context.Initialize ("ln", Three_Args ("-v", Source, Linked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Hostkit.Metadata.Same_File (Source, Linked)
         and then Test_Contexts.Output (Context) = "'" & Source & "' -> '" & Linked & "'" & EOL,
         "ln verbose output");

      Remove_Any (Linked);
      Context.Initialize ("ln", Three_Args ("-v", Source, Linked));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "ln verbose output failure status");
      Remove_Any (Linked);
      Write_File (Linked, "move-data");

      Context.Initialize ("ln", Three_Args ("-s", Source, Symlinked));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      if Result.Status = Posix_Tools.Exit_Status.Success then
         declare
            Target_Text : Unbounded_String;
         begin
            AUnit.Assertions.Assert (Hostkit.Fs.Is_Link (Symlinked), "ln -s creates symbolic link");
            AUnit.Assertions.Assert
              (Hostkit.Fs.Read_Link_Target (Symlinked, Target_Text)
               and then To_String (Target_Text) = Source,
               "ln -s records requested target");
         end;
      else
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "ln -s reports host refusal as operational failure");
      end if;

      Ada.Directories.Create_Directory (Link_Dir);
      Write_File (Other, "other-data");
      Context.Initialize ("ln", Three_Args (Source, Other, Link_Dir));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "ln directory target status");
      AUnit.Assertions.Assert
        (Hostkit.Metadata.Same_File (Source, Hostkit.Fs.Join (Link_Dir, "expanded-source.txt"))
         and then Hostkit.Metadata.Same_File (Other, Hostkit.Fs.Join (Link_Dir, "expanded-other.txt")),
         "ln creates links inside directory target");

      Context.Initialize ("link", Two_Args (Source, Link_Command_Target));
      Posix_Tools.Commands.Link.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Hostkit.Metadata.Same_File (Source, Link_Command_Target),
         "link creates hard link");

      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("readlink", One_Arg (Symlinked));
         Posix_Tools.Commands.Readlink.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = Source & EOL,
            "readlink writes symbolic link target");
      end if;

      Context.Initialize ("realpath", One_Arg (Source));
      Posix_Tools.Commands.Realpath.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Hostkit.Fs.Real_Path (Source) & EOL,
         "realpath writes resolved path");

      Write_File (Chmod_Target, "mode-data");
      Context.Initialize ("chmod", Two_Args ("600", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod status");
      Assert_Mode_When_Available (Chmod_Target, 8#600#, "chmod applies octal mode");

      Context.Initialize ("chmod", Two_Args ("u=rw,go=", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod symbolic assignment status");
      Assert_Mode_When_Available (Chmod_Target, 8#600#, "chmod applies symbolic assignment mode");

      Context.Initialize ("chmod", Two_Args ("g+r,o+r", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod symbolic add status");
      Assert_Mode_When_Available (Chmod_Target, 8#644#, "chmod applies symbolic add mode");

      Context.Initialize ("chmod", Two_Args ("-w", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod symbolic hyphen-start status");
      Assert_Mode_When_Available (Chmod_Target, 8#444#, "chmod treats -w as a symbolic mode");

      Context.Initialize ("chmod", Two_Args ("u+x,g=u,o=g", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chmod symbolic copy status");
      Assert_Mode_When_Available (Chmod_Target, 8#555#, "chmod applies symbolic copy mode");

      Context.Initialize ("chmod", Two_Args ("u+", Chmod_Target));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "chmod rejects incomplete symbolic mode");

      declare
         User      : Natural;
         Group     : Natural;
         Available : Boolean;
      begin
         Hostkit.Metadata.File_Ownership (Chmod_Target, User, Group, Available);
         if Available then
            Context.Initialize ("chown", Two_Args (Trim_Natural (User), Chmod_Target));
            Posix_Tools.Commands.Chown.Run (Context, Result);
            AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chown current user status");
            Context.Initialize ("chgrp", Two_Args (Trim_Natural (Group), Chmod_Target));
            Posix_Tools.Commands.Chgrp.Run (Context, Result);
            AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "chgrp current group status");
         end if;
      end;

      Context.Initialize ("uname", No_Args);
      Posix_Tools.Commands.Uname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 1,
         "uname writes system name");

      Context.Initialize ("uname", One_Arg ("-a"));
      Posix_Tools.Commands.Uname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), " ")
         and then not Contains (Test_Contexts.Output (Context), "unknown"),
         "uname -a writes multiple system fields");

      Context.Initialize ("sleep", One_Arg ("0"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "sleep zero status");

      Context.Initialize ("id", One_Arg ("-u"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 1,
         "id -u writes identity");

      Context.Initialize ("id", One_Arg ("-G"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 1,
         "id -G writes group list");

      Context.Initialize ("whoami", No_Args);
      Posix_Tools.Commands.Whoami.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 1,
         "whoami writes name");

      Context.Initialize ("logname", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LOGNAME", "test-login");
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-login" & EOL,
         "logname writes context login name");

      Context.Initialize ("logname", No_Args);
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context)'Length > 1,
         "logname falls back to host login database");

      Context.Initialize ("kill", One_Arg ("-l"));
      Posix_Tools.Commands.Kill.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context)'Length > 0,
         "kill -l lists signals");

      Context.Initialize ("mv", Three_Args ("-ff", Linked, Moved));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "mv grouped -f status");

      Write_File (Linked, "move-data");
      Write_File (Moved, "existing-data");
      Context.Initialize ("mv", Three_Args ("-i", Linked, Moved));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Linked)
         and then Ada.Directories.Exists (Moved)
         and then Test_Contexts.Error_Output (Context) = "mv: overwrite '" & Moved & "'?" & EOL,
         "mv -i declines overwrite");

      Context.Initialize ("mv", Three_Args ("-i", Linked, Moved));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Linked)
         and then Ada.Directories.Exists (Moved),
         "mv -i confirms overwrite");

      Write_File (Linked, "move-data");
      Write_File (Moved, "existing-data");
      Context.Initialize ("mv", Three_Args ("-if", Linked, Moved));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Linked)
         and then Test_Contexts.Error_Output (Context) = "",
         "mv -if uses final force option");

      Write_File (Linked, "move-data");
      Write_File (Moved, "existing-data");
      Context.Initialize ("mv", Three_Args ("-fi", Linked, Moved));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Linked)
         and then Ada.Directories.Exists (Moved),
         "mv -fi uses final interactive option");
      Remove_Any (Linked);
      Remove_Any (Moved);

      Write_File (Moved, "move-data");
      Context.Initialize ("rm", One_Arg (Moved));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "rm status");

      Write_File (Rm_Interactive, "interactive-data");
      Context.Initialize ("rm", Two_Args ("-i", Rm_Interactive));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Rm_Interactive)
         and then Test_Contexts.Error_Output (Context) = "rm: remove '" & Rm_Interactive & "'?" & EOL,
         "rm -i declines removal");

      Context.Initialize ("rm", Two_Args ("-i", Rm_Interactive));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Rm_Interactive),
         "rm -i confirms removal");

      Write_File (Rm_Interactive, "interactive-data");
      Context.Initialize ("rm", Two_Args ("-if", Rm_Interactive));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Rm_Interactive),
         "rm -if uses final force option");

      Write_File (Rm_Interactive, "interactive-data");
      Context.Initialize ("rm", Two_Args ("-fi", Rm_Interactive));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Rm_Interactive),
         "rm -fi uses final interactive option");
      Remove_Any (Rm_Interactive);

      Write_File (Linked, "move-data");
      Context.Initialize ("mv", Four_Args ("-f", "--", Linked, Moved));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Moved),
         "mv accepts -- after -f");
      Remove_Any (Moved);

      Context.Initialize ("mv", One_Arg ("-z"));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mv rejects unknown grouped option");

      Context.Initialize ("mv", One_Arg ("-i"));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mv accepts -i before validating operands");

      Ada.Directories.Create_Directory (Remove_Dir);
      Context.Initialize ("rm", Two_Args ("-d", Remove_Dir));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Remove_Dir),
         "rm -d removed empty directory");

      Context.Initialize ("mkdir", Four_Args ("-m", "755", "-p", Made));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Made), "mkdir created directory");
      Assert_Mode_When_Available (Made, 8#755#, "mkdir applied separate mode");

      Remove_Any (Made);
      Context.Initialize ("mkdir", Two_Args ("-pm755", Made));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Made),
         "mkdir accepts grouped -pm mode");
      Assert_Mode_When_Available (Made, 8#755#, "mkdir applied grouped mode");

      Context.Initialize ("mkdir", Three_Args ("-m", "u=rwx,go=rx", Symbolic_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Symbolic_Mode_Dir),
         "mkdir accepts symbolic assignment mode");
      Assert_Mode_When_Available (Symbolic_Mode_Dir, 8#755#, "mkdir applied symbolic assignment mode");

      Context.Initialize ("mkdir", Three_Args ("-m", "a=,u+rwx,go+rx", Relative_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Relative_Mode_Dir),
         "mkdir accepts symbolic relative mode clauses");
      Assert_Mode_When_Available (Relative_Mode_Dir, 8#755#, "mkdir applied symbolic relative mode");

      Remove_Any (Relative_Mode_Dir);
      Context.Initialize ("mkdir", Three_Args ("-m", "u=rwx,g=u,o=g", Relative_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Relative_Mode_Dir),
         "mkdir accepts symbolic copy mode clauses");
      Assert_Mode_When_Available (Relative_Mode_Dir, 8#777#, "mkdir applied symbolic copy mode");

      Remove_Any (Relative_Mode_Dir);
      Context.Initialize ("mkdir", Three_Args ("-m", "u=rwxs,g=rxs,o=rxt", Relative_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Relative_Mode_Dir),
         "mkdir accepts symbolic special bits");
      Assert_Full_Mode_When_Available (Relative_Mode_Dir, 8#7755#, "mkdir applied symbolic special bits");

      Remove_Any (Relative_Mode_Dir);
      Context.Initialize ("mkdir", Three_Args ("-m", "a=rwX", Relative_Mode_Dir));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Relative_Mode_Dir),
         "mkdir accepts symbolic conditional execute");
      Assert_Mode_When_Available (Relative_Mode_Dir, 8#777#, "mkdir applied symbolic conditional execute");

      Context.Initialize ("mkdir", Two_Args ("-m", "bad"));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mkdir rejects invalid mode");

      Context.Initialize ("mkdir", One_Arg ("-pmbad"));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mkdir rejects invalid attached mode");

      Context.Initialize ("mkdir", One_Arg ("-q"));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "mkdir rejects unknown option");

      Ada.Directories.Create_Directory (Multi);
      Write_File (Other, "other-data");
      Context.Initialize ("cp", Three_Args (Source, Other, Multi));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Multi & "/expanded-source.txt")
         and then Ada.Directories.Exists (Multi & "/expanded-other.txt"),
         "cp multiple sources into directory");

      Remove_Any (Target);
      Context.Initialize ("cp", Three_Args ("-v", Source, Target));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "'" & Source & "' -> '" & Target & "'" & EOL,
         "cp verbose output");

      Remove_Any (Target);
      Context.Initialize ("cp", Three_Args ("-v", Source, Target));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "cp verbose output failure status");

      Context.Initialize
        ("mv",
         Three_Args
           (Multi & "/expanded-source.txt",
            Multi & "/expanded-other.txt",
            Made));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Ada.Directories.Exists (Made & "/expanded-source.txt")
         and then Ada.Directories.Exists (Made & "/expanded-other.txt"),
         "mv multiple sources into directory");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      Ada.Directories.Create_Directory (Hostkit.Fs.Join (Option_Dir, "moves"));
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "plain-data");
      Write_File (Hostkit.Fs.Join (Option_Dir, "-v"), "dash-data");
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("mv", Three_Args ("plain", "-v", "moves"));
         Posix_Tools.Commands.Mv.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Hostkit.Fs.Join (Option_Dir, "moves"), "plain"))
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Hostkit.Fs.Join (Option_Dir, "moves"), "-v"))
         and then Test_Contexts.Output (Context) = "",
         "mv treats option-like words after first operand as operands");

      Write_File (Source, "move-verbose-data");
      Remove_Any (Target);
      Context.Initialize ("mv", Three_Args ("-v", Source, Target));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Target)
         and then Test_Contexts.Output (Context) = "'" & Source & "' -> '" & Target & "'" & EOL,
         "mv verbose output");

      Write_File (Source, "move-verbose-data");
      Remove_Any (Target);
      Context.Initialize ("mv", Three_Args ("-v", Source, Target));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "mv verbose output failure status");
      Write_File (Source, "copy-data");
      Remove_Any (Target);

      Ada.Directories.Create_Path (Empty & "/a/b");
      Context.Initialize ("rmdir", Two_Args ("-p", Empty & "/a/b"));
      Posix_Tools.Commands.Rmdir.Run (Context, Result);
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Empty), "rmdir removed parent path");

      Ada.Directories.Create_Path (Remove_Dir & "/a/b");
      Context.Initialize ("rmdir", Three_Args ("-p", "--", Remove_Dir & "/a/b"));
      Posix_Tools.Commands.Rmdir.Run (Context, Result);
      AUnit.Assertions.Assert (not Ada.Directories.Exists (Remove_Dir), "rmdir accepts -- after -p");

      Ada.Directories.Create_Path (Parent_Block & "/a/b");
      Write_File (Parent_Block & "/keep.txt", "keep");
      Context.Initialize ("rmdir", Two_Args ("-p", Parent_Block & "/a/b"));
      Posix_Tools.Commands.Rmdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Ada.Directories.Exists (Parent_Block)
         and then not Ada.Directories.Exists (Parent_Block & "/a"),
         "rmdir -p reports blocked parent after removing empty components");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Test_Contexts.Error_Output (Context), Parent_Block) > 0,
         "rmdir -p diagnostic names blocked parent");

      Context.Initialize ("rmdir", One_Arg ("-z"));
      Posix_Tools.Commands.Rmdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "rmdir rejects unknown option");

      Write_File (Rm_Interactive, "remove-data");
      Context.Initialize ("rm", Two_Args ("-i", Rm_Interactive));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Exists (Rm_Interactive)
         and then Test_Contexts.Output (Context) = "",
         "rm -i without response declines removal");
      Remove_Any (Rm_Interactive);

      Write_File (Rm_Interactive, "remove-data");
      Context.Initialize ("rm", Two_Args ("-v", Rm_Interactive));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (Rm_Interactive)
         and then Test_Contexts.Output (Context) = "removed '" & Rm_Interactive & "'" & EOL,
         "rm verbose output");

      Write_File (Rm_Interactive, "remove-data");
      Context.Initialize ("rm", Two_Args ("-v", Rm_Interactive));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then not Ada.Directories.Exists (Rm_Interactive),
         "rm verbose output failure status");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);

         Context.Initialize ("mkdir", Two_Args ("plain", "-p"));
         Posix_Tools.Commands.Mkdir.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Ada.Directories.Exists ("plain")
            and then Ada.Directories.Exists ("-p"),
            "mkdir treats option-like words after first operand as operands");
         Ada.Directories.Delete_Directory ("plain");
         Ada.Directories.Delete_Directory ("-p");

         Write_File ("plain-link-source", "link-data");
         Write_File ("-s", "dash-link-data");
         Ada.Directories.Create_Directory ("links");
         Context.Initialize ("ln", Three_Args ("plain-link-source", "-s", "links"));
         Posix_Tools.Commands.Ln.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Ada.Directories.Exists (Hostkit.Fs.Join ("links", "plain-link-source"))
            and then Ada.Directories.Exists (Hostkit.Fs.Join ("links", "-s")),
            "ln treats option-like words after first operand as operands");

         Write_File ("plain-file", "remove-data");
         Write_File ("-f", "remove-data");
         Context.Initialize ("rm", Two_Args ("plain-file", "-f"));
         Posix_Tools.Commands.Rm.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then not Ada.Directories.Exists ("plain-file")
            and then not Ada.Directories.Exists ("-f"),
            "rm treats option-like words after first operand as operands");

         Ada.Directories.Create_Directory ("plain-dir");
         Ada.Directories.Create_Directory ("-p");
         Context.Initialize ("rmdir", Two_Args ("plain-dir", "-p"));
         Posix_Tools.Commands.Rmdir.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then not Ada.Directories.Exists ("plain-dir")
            and then not Ada.Directories.Exists ("-p"),
            "rmdir treats option-like words after first operand as operands");

         Context.Initialize ("touch", Two_Args ("plain-touch", "-c"));
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Ada.Directories.Exists ("plain-touch")
            and then Ada.Directories.Exists ("-c"),
            "touch treats option-like words after first operand as operands");

         Context.Initialize ("tee", Two_Args ("plain-tee", "-a"));
         Test_Contexts.Set_Standard_Input (Context, "tee-boundary");
         Posix_Tools.Commands.Tee.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "tee-boundary"
            and then Ada.Directories.Exists ("plain-tee")
            and then Ada.Directories.Exists ("-a"),
            "tee treats option-like words after first operand as operands");

         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;

      Context.Initialize ("touch", One_Arg (Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Touched), "touch created file");

      Write_File (Touched, "touch-data");
      Context.Initialize ("touch", One_Arg (Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "touch existing status");
      Context.Initialize ("cat", One_Arg (Touched));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "touch-data", "touch preserves existing data");

      Context.Initialize ("touch", Two_Args ("-c", No_Create));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (No_Create),
         "touch -c leaves missing file absent");

      Context.Initialize ("touch", Two_Args ("-am", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "touch -am status");

      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Touched,
         GNAT.OS_Lib.GM_Time_Of
           (2026,
            8,
            12,
            10,
            0,
            0));
      Context.Initialize ("touch", Three_Args ("-a", "-t202608121540.11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (10 * 3_600))),
         "touch -a leaves modification timestamp unchanged");
      declare
         Expected_Access : constant Ada.Calendar.Time :=
           Ada.Calendar.Time_Of (1970, 1, 1) + 1_786_542_011.0;
         Available : Boolean;
         Accessed  : constant Ada.Calendar.Time := Hostkit.Metadata.File_Access_Time (Touched, Available);
      begin
         if Available then
            AUnit.Assertions.Assert
              (Time_Near (Accessed, Expected_Access),
               "touch -a applies explicit access timestamp");
         end if;
      end;

      Context.Initialize ("touch", Three_Args ("-m", "-t202608121540.11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 40 * 60 + 11))),
         "touch -m applies explicit modification timestamp");

      Context.Initialize ("touch", Three_Args ("-r", Source, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near (Ada.Directories.Modification_Time (Touched), Ada.Directories.Modification_Time (Source)),
         "touch -r status and timestamp");

      Context.Initialize ("touch", Two_Args ("-r" & Source, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near (Ada.Directories.Modification_Time (Touched), Ada.Directories.Modification_Time (Source)),
         "touch compact -r status and timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121530.45", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 30 * 60 + 45))),
         "touch -t status and timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121531", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 31 * 60))),
         "touch -t explicit century minute timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121531.46", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 31 * 60 + 46))),
         "touch -t explicit century seconds timestamp");

      Context.Initialize ("touch", Two_Args ("-t08121530", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of
              (Ada.Calendar.Year (Ada.Calendar.Clock), 8, 12, Duration (15 * 3_600 + 30 * 60))),
         "touch compact -t status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "202608121631.05", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 31 * 60 + 5))),
         "touch -d status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d202608121632.06", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 32 * 60 + 6))),
         "touch compact -d status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:33:07", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 33 * 60 + 7))),
         "touch -d ISO date-time status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-12 16:34:08", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 34 * 60 + 8))),
         "touch compact -d spaced date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:35:09Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 35 * 60 + 9))),
         "touch -d UTC date-time status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-12 16:36:10Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 36 * 60 + 10))),
         "touch compact -d UTC spaced date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:35:09+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (14 * 3_600 + 5 * 60 + 9))),
         "touch -d positive numeric offset status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12 16:36:10-0330", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (20 * 3_600 + 6 * 60 + 10))),
         "touch -d negative numeric offset status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, 0.0)),
         "touch -d date-only status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-13T17:45", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 45 * 60))),
         "touch compact -d minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:46Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 46 * 60))),
         "touch -d UTC minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:47+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (15 * 3_600 + 17 * 60))),
         "touch -d positive offset minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026/08/13 17:48:11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 48 * 60 + 11))),
         "touch -d slash date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13t17:49:12Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 49 * 60 + 12))),
         "touch -d lowercase-t UTC date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:50:13.987+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (15 * 3_600 + 20 * 60 + 13))),
         "touch -d fractional offset date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Aug 13 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 51 * 60 + 14))),
         "touch -d abbreviated month-name date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "August 13, 2026 17:52", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 52 * 60))),
         "touch -d full month-name minute timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Sep 14 2026", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 9, 14, 0.0)),
         "touch -d month-name date-only timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "13 Aug 2026 17:53:16", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 53 * 60 + 16))),
         "touch -d day-first abbreviated month-name timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "14 September 2026", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 9, 14, 0.0)),
         "touch -d day-first full month-name date-only timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "noon", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      declare
         Year : Ada.Calendar.Year_Number;
         Month : Ada.Calendar.Month_Number;
         Day : Ada.Calendar.Day_Number;
         Seconds : Duration;
      begin
         Ada.Calendar.Split (Ada.Calendar.Clock, Year, Month, Day, Seconds);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near
              (Ada.Directories.Modification_Time (Touched),
               Ada.Calendar.Time_Of (Year, Month, Day, Duration (12 * 3_600))),
            "touch -d noon timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "2 hours ago", Touched));
      declare
         Expected : constant Ada.Calendar.Time := Ada.Calendar.Clock - Duration (2 * 3_600);
      begin
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near (Ada.Directories.Modification_Time (Touched), Expected),
            "touch -d relative hours ago timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "+1 day", Touched));
      declare
         Expected : constant Ada.Calendar.Time := Ada.Calendar.Clock + 86_400.0;
      begin
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near (Ada.Directories.Modification_Time (Touched), Expected),
            "touch -d relative plus day timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "bad", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid -d timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Nope 13 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid month-name -d timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "32 Aug 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid day-first month-name -d timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202613121530", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid timestamp");

      Context.Initialize ("touch", Three_Args ("-r", No_Create, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "touch missing reference status");

      Context.Initialize ("touch", Two_Args ("-ac", No_Create));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (No_Create),
         "touch grouped -ac leaves missing file absent");

      Context.Initialize ("dd", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "abcdef"
         and then Test_Contexts.Error_Output (Context) = "0+1 records in" & EOL & "0+1 records out" & EOL,
         "dd default block size records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "abc"
         and then Test_Contexts.Error_Output (Context) = "3+0 records in" & EOL & "3+0 records out" & EOL,
         "dd count output and records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=0"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "0+0 records in" & EOL & "0+0 records out" & EOL,
         "dd count zero copies no records");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Error_Output (Context) = "",
         "dd reports standard-output failure");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1b"));
      Test_Contexts.Set_Standard_Input (Context, String'(1 .. 520 => 'x'));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length = 512, "dd count b suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=1K"));
      Test_Contexts.Set_Standard_Input (Context, String'(1 .. 1_030 => 'x'));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length = 1_024, "dd count K suffix output");

      Context.Initialize ("dd", Two_Args ("count=1", "bs=1M"));
      Test_Contexts.Set_Standard_Input (Context, "x");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "x", "dd M suffix block size output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3w"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd count w suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=3c"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "dd count c suffix output");

      Context.Initialize ("dd", Two_Args ("bs=1", "count=2x3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd count x multiplier output");

      Context.Initialize ("dd", Three_Args ("bs=1", "count=2", "count=4"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcd", "dd later count operand wins");

      Context.Initialize ("dd", Two_Args ("bs=2", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcd", "dd block count output");

      Context.Initialize ("dd", Two_Args ("bs=2x3", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd block x multiplier output");

      Context.Initialize ("dd", Three_Args ("files=1", "bs=1", "count=3"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "dd files operand output");

      Context.Initialize ("dd", One_Arg ("files=0"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects zero files operand");

      Context.Initialize ("dd", Two_Args ("ibs=3", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abcdef", "dd ibs count output");

      Context.Initialize ("dd", Three_Args ("bs=2", "skip=1", "count=2"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "cdef", "dd skip output");

      Context.Initialize ("dd", Three_Args ("ibs=3", "skip=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "dd ibs skip output");

      Context.Initialize ("dd", Three_Args ("ibs=3", "iseek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "def", "dd iseek alias output");

      Context.Initialize ("dd", Three_Args ("bs=2", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & "ab",
         "dd seek output");

      Context.Initialize ("dd", Four_Args ("ibs=1", "obs=3", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & Character'Val (0) & "a",
         "dd obs seek output");

      Context.Initialize ("dd", Four_Args ("ibs=1", "obs=3", "oseek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (0) & Character'Val (0) & Character'Val (0) & "a",
         "dd oseek alias output");

      Context.Initialize ("dd", One_Arg ("conv=ucase"));
      Test_Contexts.Set_Standard_Input (Context, "aBz 12");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ABZ 12", "dd conv=ucase output");

      Context.Initialize ("dd", One_Arg ("conv=ucase,lcase"));
      Test_Contexts.Set_Standard_Input (Context, "aBz 12");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abz 12", "dd later conversion wins output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ebcdic"));
      Test_Contexts.Set_Standard_Input (Context, "Az09");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (193) & Character'Val (169) & Character'Val (240) & Character'Val (249),
         "dd conv=ebcdic byte table output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ascii"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (193) & Character'Val (169) & Character'Val (240) & Character'Val (249));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "Az09" & EOL, "dd conv=ascii byte table output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=ibm"));
      Test_Contexts.Set_Standard_Input (Context, "AZ");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (193) & Character'Val (233) & Character'Val (64) & Character'Val (64),
         "dd conv=ibm byte table output");

      Context.Initialize ("dd", One_Arg ("conv=ascii"));
      Test_Contexts.Set_Standard_Input (Context, "abcd");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd conv=ascii requires cbs");

      Context.Initialize ("dd", One_Arg ("conv=swab"));
      Test_Contexts.Set_Standard_Input (Context, "abcde");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "badce", "dd conv=swab odd output");

      Context.Initialize ("dd", One_Arg ("conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "abc",
         "dd conv=noerror normal input output");

      Context.Initialize ("dd", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "dd input failure without noerror status");

      Context.Initialize ("dd", One_Arg ("conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab",
         "dd conv=noerror retains readable prefix");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=noerror"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab"
         and then Contains (Test_Contexts.Error_Output (Context), "cannot read file")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records in"),
         "dd conv=noerror omits failed unsynchronized block tail");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=noerror,sync"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 2);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab" & Character'Val (0) & Character'Val (0)
         and then Contains (Test_Contexts.Error_Output (Context), "cannot read file")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records in")
         and then Contains (Test_Contexts.Error_Output (Context), "0+1 records out"),
         "dd conv=noerror sync pads failed input block");

      Context.Initialize ("dd", Two_Args ("ibs=4", "conv=sync"));
      Test_Contexts.Set_Standard_Input (Context, "ab");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ab" & Character'Val (0) & Character'Val (0),
         "dd conv=sync pads short block");

      Context.Initialize ("dd", Three_Args ("ibs=4", "count=1", "conv=sync,swab"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ba" & Character'Val (0) & "c",
         "dd conv=sync swab output");

      Context.Initialize ("dd", Three_Args ("bs=1", "conv=swab,ucase", "count=4"));
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "BADC", "dd conv=swab ucase output");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "bcdef" & EOL & "xy");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a   " & "bcde" & "xy  ", "dd conv=block output");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Error_Output (Context), "1 truncated record"),
         "dd conv=block reports singular truncated record");

      Context.Initialize ("dd", Two_Args ("cbs=2", "conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "abc" & EOL & "def" & EOL);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "ab" & "de"
         and then Contains (Test_Contexts.Error_Output (Context), "2 truncated records"),
         "dd conv=block reports plural truncated records");

      Context.Initialize ("dd", Three_Args ("ibs=4", "cbs=4", "conv=sync,block"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a   ",
         "dd conv=sync block pads with spaces");

      Context.Initialize ("dd", Two_Args ("cbs=4", "conv=unblock"));
      Test_Contexts.Set_Standard_Input (Context, "a   bcde");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "bcde" & EOL, "dd conv=unblock output");

      Context.Initialize ("dd", Three_Args ("ibs=4", "cbs=4", "conv=sync,unblock"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL,
         "dd conv=sync unblock pads with spaces");

      Context.Initialize ("dd", One_Arg ("conv=block"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd conv=block requires cbs");

      Write_File (Target, "abcdef");
      Context.Initialize ("dd", Four_Args ("of=" & Target, "bs=1", "count=2", "conv=notrunc"));
      Test_Contexts.Set_Standard_Input (Context, "XY");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "XYcdef", "dd conv=notrunc preserves tail");

      Write_File (Target, "abcdef");
      Context.Initialize ("dd", Five_Args ("of=" & Target, "bs=2", "seek=1", "count=1", "conv=notrunc"));
      Test_Contexts.Set_Standard_Input (Context, "XY");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      Context.Initialize ("cat", One_Arg (Target));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abXYef", "dd conv=notrunc honors seek offset");

      Context.Initialize ("dd", Four_Args ("of=" & Target, "obs=1M", "seek=1", "count=1"));
      Test_Contexts.Set_Standard_Input (Context, "Z");
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Ada.Directories.Size (Target) = Ada.Directories.File_Size (1_048_577),
         "dd output file seek uses file offset");

      Context.Initialize ("dd", One_Arg ("bs=1q"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects unsupported numeric suffix");

      Context.Initialize ("dd", One_Arg ("bs=999999999999999999999999999999G"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects overflow numeric suffix");

      Context.Initialize ("dd", One_Arg ("bs=2x"));
      Posix_Tools.Commands.Dd.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "dd rejects empty multiplier factor");

      Context.Initialize ("printf", Two_Args ("%s\n", "value"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "value" & EOL, "printf output");

      Context.Initialize ("printf", Three_Args ("%s\n", "one", "two"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "one" & EOL & "two" & EOL,
         "printf format reuse output");

      Context.Initialize ("printf", Two_Args ("%d\n", "42"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "42" & EOL, "printf decimal output");

      Context.Initialize ("printf", Three_Args ("%d\n", "+0007", "-0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf canonical decimal output");

      Context.Initialize ("printf", Three_Args ("%i\n", "+0007", "-0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf signed integer output");

      Context.Initialize ("printf", Three_Args ("%u\n", "+0007", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7" & EOL & "0" & EOL,
         "printf unsigned decimal output");

      Context.Initialize ("printf", Four_Args ("%o:%x:%X", "15", "255", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "17:ff:FF",
         "printf unsigned base output");

      Context.Initialize ("printf", Two_Args ("%b", "a\nb"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b", "printf percent b newline");

      Context.Initialize ("printf", Two_Args ("%b", "\101\102"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "AB", "printf percent b octal");

      Context.Initialize ("printf", Three_Args ("%5s:%3d\n", "x", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "    x:  7" & EOL,
         "printf minimum width output");

      Context.Initialize ("printf", Three_Args ("%-5s:%-3d\n", "x", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x    :7  " & EOL,
         "printf left-justified width output");

      Context.Initialize ("printf", Two_Args ("%.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "printf string precision output");

      Context.Initialize ("printf", Two_Args ("%5.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  abc", "printf width precision output");

      Context.Initialize ("printf", Two_Args ("%-5.3s", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc  ", "printf left width precision output");

      Context.Initialize ("printf", Three_Args ("%*s", "5", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "    x", "printf star width output");

      Context.Initialize ("printf", Three_Args ("%*s", "-5", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "x    ", "printf negative star width output");

      Context.Initialize ("printf", Three_Args ("%.*s", "3", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "printf star precision output");

      Context.Initialize ("printf", Four_Args ("%*.*d", "6", "4", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  0007", "printf star width precision output");

      Context.Initialize ("printf", Three_Args ("%.4d:%.4d", "7", "-7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0007:-0007",
         "printf decimal precision output");

      Context.Initialize ("printf", Three_Args ("%6.4d:%-6.4d", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0007:0007  ",
         "printf decimal width precision output");

      Context.Initialize ("printf", Three_Args ("%6.4u:%-6.4u", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0007:0007  ",
         "printf unsigned width precision output");

      Context.Initialize ("printf", Three_Args ("%6.4x:%-6.4o", "255", "9"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  00ff:0011  ",
         "printf base width precision output");

      Context.Initialize ("printf", Four_Args ("%#o:%#x:%#X", "9", "255", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "011:0xff:0XFF",
         "printf alternate base output");

      Context.Initialize ("printf", Four_Args ("%#o:%#x:%#X", "0", "0", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0:0:0",
         "printf alternate zero output");

      Context.Initialize ("printf", Two_Args ("%#08x", "255"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0x0000ff",
         "printf alternate zero-padded hex output");

      Context.Initialize ("printf", Four_Args ("%+d:% d:%+ d", "7", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+7: 7:+7",
         "printf signed flag output");

      Context.Initialize ("printf", Three_Args ("%f:%.2f", "1.5", "-2.345"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000:-2.35",
         "printf fixed floating output");

      Context.Initialize ("printf", Three_Args ("%8.2f:%-8.1f", "1.5", "2"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "    1.50:2.0     ",
         "printf fixed floating width output");

      Context.Initialize ("printf", Three_Args ("%+07.2f:% 5.1f", "1.5", "2"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+001.50:  2.0",
         "printf fixed floating flags output");

      Context.Initialize ("printf", Three_Args ("%e:%.2E", "1.5", "-0.01234"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000e+00:-1.23E-02",
         "printf scientific floating output");

      Context.Initialize ("printf", Two_Args ("%.2e", "1.2e3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.20e+03",
         "printf scientific exponent input output");

      Context.Initialize ("printf", Two_Args ("%+010.2e", "12.34"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+01.23e+01",
         "printf scientific floating flags output");

      Context.Initialize ("printf", Four_Args ("%g:%g:%G", "1234", "0.0000123", "0.0000123"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1234:1.23e-05:1.23E-05",
         "printf general floating output");

      Context.Initialize ("printf", Three_Args ("%#.4g:%8.3g", "12.3", "12.3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "12.30:    12.3",
         "printf general floating flags output");

      Context.Initialize ("printf", Three_Args ("%+i:%.4i", "7", "-7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+7:-0007",
         "printf signed integer flag precision output");

      Context.Initialize ("printf", Three_Args ("%f:%.2e", "1.5", "-12.3"));
      Test_Contexts.Set_Environment_Value (Context, "LC_NUMERIC", "da");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1,500000:-1,23e+01",
         "printf uses LC_NUMERIC decimal separator");

      Context.Initialize ("printf", Three_Args ("%f:%.2e", "1.5", "-12.3"));
      Test_Contexts.Set_Environment_Value (Context, "LC_NUMERIC", "da");
      Test_Contexts.Set_Environment_Value (Context, "LC_ALL", "en");
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1.500000:-1.23e+01",
         "printf LC_ALL overrides LC_NUMERIC");

      Context.Initialize ("printf", Four_Args ("%05d:%05d:%05u", "7", "-7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "00007:-0007:00007",
         "printf zero padding output");

      Context.Initialize ("printf", Three_Args ("%-05d:%05.3d", "7", "7"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "7    :  007",
         "printf flag precedence output");

      Context.Initialize ("printf", Two_Args ("%5.3b", "abcdef"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  abc", "printf percent b width precision");

      Context.Initialize ("printf", Three_Args ("%b%s", "a\cignored", "later"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a", "printf percent b c stops output");

      Context.Initialize ("printf", Two_Args ("%.0d", "0"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "printf zero decimal precision output");

      Context.Initialize ("printf", One_Arg ("%d:%u:%x:%f:%.1g"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "0:0:0:0.000000:0",
         "printf missing numeric operands default to zero");

      Context.Initialize ("printf", Two_Args ("%*d:%.*s", "3"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "  0:",
         "printf missing star and numeric operands default deterministically");

      Context.Initialize ("printf", Two_Args ("%s", "blocked"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "printf reports standard-output failure");

      Context.Initialize ("printf", Two_Args ("%u", "-1"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid unsigned status");

      Context.Initialize ("printf", Three_Args ("%*s", "bad", "x"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid star width status");

      Context.Initialize ("printf", Two_Args ("%x", "-1"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid hex status");

      Context.Initialize ("printf", Two_Args ("%d", "abc"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid decimal status");

      Context.Initialize ("printf", Two_Args ("%f", "abc"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid float status");

      Context.Initialize ("printf", Two_Args ("%i", "abc"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "printf invalid signed integer status");

      Context.Initialize ("printf", Three_Args ("%c", "alpha", "beta"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "printf character reuse output");

      Context.Initialize ("printf", Three_Args ("%3c:%-3c", "alpha", "beta"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "  a:b  ", "printf character width output");

      Context.Initialize ("printf", One_Arg ("%3c"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "   ", "printf missing character width output");

      Context.Initialize ("printf", One_Arg ("%%\t\\"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "%" & Character'Val (9) & "\",
         "printf escapes");

      Context.Initialize ("printf", One_Arg ("\a\b\f\v"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "" & Character'Val (7) & Character'Val (8) & Character'Val (12) & Character'Val (11),
         "printf control escapes");

      Context.Initialize ("printf", One_Arg ("\0101\0102"));
      Posix_Tools.Commands.Printf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "AB",
         "printf octal escapes");

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "sort output");

      Context.Initialize ("sort", Two_Args ("-ru", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & EOL & "a" & EOL, "sort -ru output");

      Context.Initialize ("sort", Two_Args ("-f", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "A" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "A" & EOL & "b" & EOL, "sort -f output");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#85#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#C3#) & Character'Val (16#85#) & EOL,
         "sort -f folds UTF-8 Latin-1 case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#CE#) & Character'Val (16#91#) & EOL
         & Character'Val (16#CE#) & Character'Val (16#B1#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#CE#) & Character'Val (16#91#) & EOL,
         "sort -f folds UTF-8 Greek case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#D0#) & Character'Val (16#AF#) & EOL
         & Character'Val (16#D1#) & Character'Val (16#8F#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = Character'Val (16#D0#) & Character'Val (16#AF#) & EOL,
         "sort -f folds UTF-8 Cyrillic case pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C4#) & Character'Val (16#80#) & EOL
         & Character'Val (16#C4#) & Character'Val (16#81#) & EOL
         & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
         & Character'Val (16#D5#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#83#) & Character'Val (16#90#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C4#) & Character'Val (16#80#) & EOL
           & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
           & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL,
         "sort -f folds UTF-8 Latin Extended Armenian and Georgian pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C6#) & Character'Val (16#81#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#93#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#94#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#90#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#9B#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C6#) & Character'Val (16#81#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#90#) & EOL,
         "sort -f folds UTF-8 Latin Extended-B pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL
         & Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#A8#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL,
         "sort -f folds UTF-8 Deseret pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
         & Character'Val (16#EA#) & Character'Val (16#AD#) & Character'Val (16#B0#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BD#) & Character'Val (16#81#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
           & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL,
         "sort -f folds UTF-8 Cherokee and Fullwidth Latin pairs");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#9F#) & EOL
         & "ss" & EOL
         & Character'Val (16#EF#) & Character'Val (16#AC#) & Character'Val (16#83#) & EOL
         & "ffi" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#EF#) & Character'Val (16#AC#) & Character'Val (16#83#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#9F#) & EOL,
         "sort -f folds Unicode multi-code-point case mappings");

      Context.Initialize ("sort", Two_Args ("-fu", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AA#) & EOL
         & "k" & EOL
         & Character'Val (16#CF#) & Character'Val (16#82#) & EOL
         & Character'Val (16#CF#) & Character'Val (16#83#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AA#) & EOL
           & Character'Val (16#CF#) & Character'Val (16#82#) & EOL,
         "sort -f folds Unicode compatibility and final-sigma mappings");

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
         & "z" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL
         & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "a" & EOL
           & "z" & EOL
           & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL
           & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL,
         "sort uses Danish locale collation order");

      Context.Initialize ("sort", No_Args);
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "d" & EOL & "ch" & EOL & "c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c" & EOL & "ch" & EOL & "d" & EOL,
         "sort uses Spanish multibyte collation symbols");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         "z" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success,
         "sort -c uses Danish locale collation order");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A6#) & EOL
         & "z" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -c rejects Danish locale unordered input");

      Context.Initialize ("sort", Two_Args ("-b", "-"));
      Test_Contexts.Set_Standard_Input (Context, "  b" & EOL & " a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = " a" & EOL & "  b" & EOL, "sort -b output");

      Context.Initialize ("sort", Two_Args ("-bf", "-"));
      Test_Contexts.Set_Standard_Input (Context, "  beta" & EOL & " Alpha" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = " Alpha" & EOL & "  beta" & EOL,
         "sort grouped -bf output");

      Context.Initialize ("sort", Two_Args ("-d", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a 10" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 10" & EOL & "a!1" & EOL & "a#2" & EOL,
         "sort -d output");

      Context.Initialize ("sort", Two_Args ("-cd", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -cd rejects dictionary unordered input");

      Context.Initialize ("sort", Two_Args ("-i", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a1" & EOL & "a" & Character'Val (1) & "2" & EOL,
         "sort -i output");

      Context.Initialize ("sort", Two_Args ("-ci", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -ci rejects ignore-nonprinting unordered input");

      Context.Initialize ("sort", Two_Args ("-k2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b 2" & EOL & "a 1" & EOL & "c 3" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 1" & EOL & "b 2" & EOL & "c 3" & EOL,
         "sort -k attached field key output");

      Context.Initialize ("sort", Two_Args ("-k2", "-"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "x d" & EOL & "x ch" & EOL & "x c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x c" & EOL & "x ch" & EOL & "x d" & EOL,
         "sort -k uses locale collation order");

      Context.Initialize ("sort", Four_Args ("-t", ":", "-k", "2"));
      Test_Contexts.Set_Standard_Input (Context, "x:b" & EOL & "z:a" & EOL & "y:c" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "z:a" & EOL & "x:b" & EOL & "y:c" & EOL,
         "sort -t -k separated field key output");

      Context.Initialize ("sort", Two_Args ("-k2,2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 2 z" & EOL & "b 1 y" & EOL & "c 3 x" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b 1 y" & EOL & "a 2 z" & EOL & "c 3 x" & EOL,
         "sort -k start end field key output");

      Context.Initialize ("sort", Two_Args ("-k1.2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "x3" & EOL & "z1" & EOL & "y2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "z1" & EOL & "y2" & EOL & "x3" & EOL,
         "sort -k start character key output");

      Context.Initialize ("sort", Three_Args ("-k", "2.2,2.2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a b3" & EOL & "b a1" & EOL & "c c2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b a1" & EOL & "c c2" & EOL & "a b3" & EOL,
         "sort -k separated character range output");

      Context.Initialize ("sort", Three_Args ("-n", "-k2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 10" & EOL & "b 2" & EOL & "c -1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c -1" & EOL & "b 2" & EOL & "a 10" & EOL,
         "sort -n -k field key output");

      Context.Initialize ("sort", Two_Args ("-k2n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 10" & EOL & "b 2" & EOL & "c -1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "c -1" & EOL & "b 2" & EOL & "a 10" & EOL,
         "sort -k numeric modifier output");

      Context.Initialize ("sort", Two_Args ("-k1f", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "B" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "B" & EOL,
         "sort -k fold-case modifier output");

      Context.Initialize ("sort", Two_Args ("-k1d", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a#2" & EOL & "a 10" & EOL & "a!1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 10" & EOL & "a!1" & EOL & "a#2" & EOL,
         "sort -k dictionary modifier output");

      Context.Initialize ("sort", Two_Args ("-k1i", "-"));
      Test_Contexts.Set_Standard_Input
        (Context, "a" & Character'Val (1) & "2" & EOL & "a1" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a1" & EOL & "a" & Character'Val (1) & "2" & EOL,
         "sort -k ignore-nonprinting modifier output");

      Context.Initialize ("sort", Four_Args ("-t", ":", "-k", "2b"));
      Test_Contexts.Set_Standard_Input (Context, "a:  b" & EOL & "b: a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b: a" & EOL & "a:  b" & EOL,
         "sort -k ignore-leading-blanks modifier output");

      Context.Initialize ("sort", Two_Args ("-k1r", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "b" & EOL & "a" & EOL,
         "sort -k reverse modifier output");

      Context.Initialize ("sort", Three_Args ("-k1,1", "-k2n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b 2" & EOL & "b 1" & EOL & "a 3" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 3" & EOL & "b 1" & EOL & "b 2" & EOL,
         "sort multiple keys output");

      Context.Initialize ("sort", Three_Args ("-k1,1", "-k2nr", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a 1" & EOL & "a 3" & EOL & "b 2" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a 3" & EOL & "a 1" & EOL & "b 2" & EOL,
         "sort multiple keys reverse numeric output");

      Context.Initialize ("sort", Two_Args ("-m", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "c" & EOL & "b" & EOL & "d" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL & "c" & EOL & "d" & EOL,
         "sort -m output");

      Context.Initialize ("sort", Two_Args ("-k0", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects zero key field");

      Context.Initialize ("sort", Two_Args ("-k3,2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects decreasing key field range");

      Context.Initialize ("sort", Two_Args ("-k2.3,2.2", "-"));
      Test_Contexts.Set_Standard_Input (Context, "data" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "sort rejects decreasing key character range");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "10 ten" & EOL & " 2 two" & EOL & "-1 minus" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1 minus" & EOL & " 2 two" & EOL & "10 ten" & EOL,
         "sort -n output");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2.50 two" & EOL & "-1.25 minus" & EOL & "2.05 low" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1.25 minus" & EOL & "2.05 low" & EOL & "2.50 two" & EOL,
         "sort -n decimal output");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context, "2,50 two" & EOL & "-1,25 minus" & EOL & "2,05 low" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-1,25 minus" & EOL & "2,05 low" & EOL & "2,50 two" & EOL,
         "sort -n uses locale decimal separator");

      Context.Initialize ("sort", Two_Args ("-n", "-"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "1e3 high" & EOL
         & "2.5e-1 low" & EOL
         & "-1e2 minus" & EOL
         & "3 middle" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
         "-1e2 minus" & EOL
         & "2.5e-1 low" & EOL
         & "3 middle" & EOL
         & "1e3 high" & EOL,
         "sort -n exponent output");

      Context.Initialize ("sort", Two_Args ("-ns", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2 z" & EOL & "2 a" & EOL & "1 one" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1 one" & EOL & "2 z" & EOL & "2 a" & EOL,
         "sort -ns preserves equal numeric input order");

      Context.Initialize ("sort", Two_Args ("-ub", "-"));
      Test_Contexts.Set_Standard_Input (Context, " apple" & EOL & "  apple" & EOL & "banana" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = " apple" & EOL & "banana" & EOL,
         "sort -ub output");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -c accepts ordered input");

      Context.Initialize ("sort", Two_Args ("-cn", "-"));
      Test_Contexts.Set_Standard_Input (Context, "1.5" & EOL & "1.25" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cn rejects decimal unordered input");

      Context.Initialize ("sort", Two_Args ("-cn", "-"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "1,5" & EOL & "1,25" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cn uses locale decimal separator");

      Context.Initialize ("sort", Two_Args ("-cns", "-"));
      Test_Contexts.Set_Standard_Input (Context, "2 z" & EOL & "2 a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -cns accepts stable equal numeric input order");

      Context.Initialize ("sort", Two_Args ("-c", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -c rejects unordered input");

      Context.Initialize ("sort", Two_Args ("-Cr", "-"));
      Test_Contexts.Set_Standard_Input (Context, "b" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "",
         "sort -Cr accepts reverse ordered input");

      Context.Initialize ("sort", Two_Args ("-cu", "-"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL);
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure and then Test_Contexts.Output (Context) = "",
         "sort -cu rejects duplicates");

      Context.Initialize ("sort", Three_Args ("-o", Sort_Out, Source));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Sort_Out), "sort -o output file");
      Context.Initialize ("cat", One_Arg (Sort_Out));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "copy-data" & EOL,
         "sort -o writes sorted file data");

      Context.Initialize ("sort", Three_Args ("-o", Made, Source));
      Posix_Tools.Commands.Sort.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "sort -o reports output-file failure");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "b" & EOL);
      Write_File (Hostkit.Fs.Join (Option_Dir, "-r"), "a" & EOL);
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("sort", Two_Args ("plain", "-r"));
         Posix_Tools.Commands.Sort.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL,
         "sort treats option-like words after first file operand as file operands");

      Remove_Any (Option_Dir);
      Ada.Directories.Create_Directory (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "x" & EOL);
      declare
         Original_Directory : constant String := Ada.Directories.Current_Directory;
      begin
         Ada.Directories.Set_Directory (Option_Dir);
         Context.Initialize ("uniq", Two_Args ("plain", "-c"));
         Posix_Tools.Commands.Uniq.Run (Context, Result);
         Ada.Directories.Set_Directory (Original_Directory);
      exception
         when others =>
            Ada.Directories.Set_Directory (Original_Directory);
            raise;
      end;
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Ada.Directories.Exists (Hostkit.Fs.Join (Option_Dir, "-c")),
         "uniq treats option-like words after first file operand as file operands");

      Context.Initialize ("cat", One_Arg (Hostkit.Fs.Join (Option_Dir, "-c")));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "x" & EOL,
         "uniq output operand receives filtered data");

      Context.Initialize ("uniq", Two_Args (Source, Made));
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "uniq reports output-file failure");

      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "tee-data");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "tee-data", "tee output");

      Write_File (Tee_Out, "old");
      Context.Initialize ("tee", Three_Args ("-ai", "--", Tee_Out));
      Test_Contexts.Set_Standard_Input (Context, "new");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "new", "tee -ai stdout");
      Context.Initialize ("cat", One_Arg (Tee_Out));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "oldnew", "tee -a appends file");

      if Posix_Tools.Host_Adapters.Signals.Is_Supported (Posix_Tools.Host_Adapters.Signals.Interrupt) then
         declare
            Before : Posix_Tools.Host_Adapters.Signals.Disposition;
            After  : Posix_Tools.Host_Adapters.Signals.Disposition;
            Got_Before : constant Boolean :=
              Posix_Tools.Host_Adapters.Signals.Current_Disposition
                (Posix_Tools.Host_Adapters.Signals.Interrupt, Before);
         begin
            AUnit.Assertions.Assert (Got_Before, "tee -i can inspect interrupt disposition");
            Context.Initialize ("tee", Two_Args ("-i", "--"));
            Test_Contexts.Set_Standard_Input (Context, "signal-safe");
            Posix_Tools.Commands.Tee.Run (Context, Result);
            AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "tee -i status");
            AUnit.Assertions.Assert
              (Posix_Tools.Host_Adapters.Signals.Current_Disposition
                 (Posix_Tools.Host_Adapters.Signals.Interrupt, After)
               and then After = Before,
               "tee -i restores interrupt disposition");
         end;
      end if;

      Context.Initialize ("tee", One_Arg (Made));
      Test_Contexts.Set_Standard_Input (Context, "blocked");
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "blocked"
         and then Ada.Strings.Fixed.Index (Test_Contexts.Error_Output (Context), Made) > 0,
         "tee reports failed file output");

      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "blocked");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tee reports standard-output failure");

      Context.Initialize ("tee", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abcdef");
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 3);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "abc",
         "tee streams readable prefix before input failure");

      Context.Initialize ("tee", One_Arg ("-z"));
      Test_Contexts.Set_Standard_Input_Failure_After (Context, 0);
      Posix_Tools.Commands.Tee.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "tee validates options before reading stdin");

      Context.Initialize ("tr", Two_Args ("abc", "xyz"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr output");

      Context.Initialize ("tr", Two_Args ("a-c", "x-z"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr range output");

      Context.Initialize ("tr", Two_Args ("\n\t", "NL"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & Character'Val (9) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "aNLb", "tr control escape output");

      Context.Initialize ("tr", Two_Args ("\\", "/"));
      Test_Contexts.Set_Standard_Input (Context, "a\b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a/b", "tr backslash escape output");

      Context.Initialize ("tr", Two_Args ("\101\102", "xy"));
      Test_Contexts.Set_Standard_Input (Context, "ABC");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xyC", "tr octal escape output");

      Context.Initialize ("tr", Two_Args ("\141-\143", "x-z"));
      Test_Contexts.Set_Standard_Input (Context, "cab");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zxy", "tr octal range output");

      Context.Initialize ("tr", Two_Args ("\011-\012", "TN"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (9) & Character'Val (10) & "x");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "TNx", "tr control range output");

      Context.Initialize ("tr", Two_Args ("-d", "\n"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "tr delete newline escape output");

      Context.Initialize ("tr", Two_Args ("[:lower:]", "[:upper:]"));
      Test_Contexts.Set_Standard_Input (Context, "a1z");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "A1Z", "tr lower upper class output");

      Context.Initialize ("tr", Two_Args ("-d", "[:digit:]"));
      Test_Contexts.Set_Standard_Input (Context, "a1b2");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ab", "tr digit class delete output");

      Context.Initialize ("tr", Two_Args ("-d", "[:xdigit:]"));
      Test_Contexts.Set_Standard_Input (Context, "aFgZ19-");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "gZ-", "tr xdigit class delete output");

      Context.Initialize ("tr", Two_Args ("-d", "[:punct:]"));
      Test_Contexts.Set_Standard_Input (Context, "a,b.c!");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abc", "tr punct class delete output");

      Context.Initialize ("tr", Two_Args ("-s", "[:blank:]"));
      Test_Contexts.Set_Standard_Input (Context, "a  " & Character'Val (9) & Character'Val (9) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a " & Character'Val (9) & "b",
         "tr blank class squeeze output");

      Context.Initialize ("tr", Two_Args ("[:cntrl:]", "?"));
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (0) & Character'Val (127));
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a??", "tr cntrl class translate output");

      Context.Initialize ("tr", Two_Args ("-cd", "[:print:]"));
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (0) & " ");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a ", "tr print class complement output");

      Context.Initialize ("tr", Two_Args ("-d", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "d", "tr delete range output");

      Context.Initialize ("tr", Two_Args ("-cd", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "ca", "tr delete complement output");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "X"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "caX", "tr complement translate output");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "XY"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (0) & "d");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "XY", "tr ordered complement translate output");

      Context.Initialize ("tr", Three_Args ("-C", "a-c", "X"));
      Test_Contexts.Set_Standard_Input (Context, "cad");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "caX", "tr uppercase complement translate output");

      Test_Contexts.Set_Locale (Context, "da");
      Context.Initialize ("tr", Three_Args ("-c", "a-c", "XYZ"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "defA");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XYZZ",
         "tr locale collation orders complement translation");

      Context.Initialize ("tr", Two_Args ("-s", "a-c"));
      Test_Contexts.Set_Standard_Input (Context, "aaabbbdd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "abdd", "tr squeeze output");

      Context.Initialize ("tr", Three_Args ("-s", "a-c", "x"));
      Test_Contexts.Set_Standard_Input (Context, "abcccd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xd", "tr translate squeeze output");

      Context.Initialize ("tr", Three_Args ("-ds", "a-c", "d"));
      Test_Contexts.Set_Standard_Input (Context, "abdddde");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "de", "tr delete squeeze output");

      Context.Initialize ("tr", Two_Args ("abc", "[x*3]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xxx", "tr repeated set output");

      Context.Initialize ("tr", Two_Args ("abc", "[x*]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "xxx", "tr shorthand repeated set output");

      Context.Initialize ("tr", Two_Args ("a-i", "[x*010]y"));
      Test_Contexts.Set_Standard_Input (Context, "abcdefghi");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xxxxxxxxy",
         "tr leading-zero repeat count is octal");

      Context.Initialize ("tr", Three_Args ("-c", "a-c", "[z*]"));
      Test_Contexts.Set_Standard_Input (Context, Character'Val (0) & "d");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "zz", "tr shorthand repeat covers complement domain");

      Context.Initialize ("tr", Two_Args ("abc", "[\n*2]"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = EOL & EOL & EOL,
         "tr repeated escaped set output");

      Context.Initialize ("tr", Two_Args ("[=a=][.b.]", "xy"));
      Test_Contexts.Set_Standard_Input (Context, "aba");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xyx",
         "tr single-byte equivalence and collating output");

      Context.Initialize ("tr", Two_Args ("[=\n=]", "N"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "aNb", "tr escaped equivalence output");

      Context.Initialize ("tr", Two_Args ("[=a=]", "X"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "a" & Character'Val (16#C3#) & Character'Val (16#A1#) & "b");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XXXb",
         "tr locale equivalence expands accented UTF-8 bytes");

      Context.Initialize ("tr", Two_Args ("[.ab.][=cd=]", "XY"));
      Test_Contexts.Set_Standard_Input (Context, "abcd");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XYYY",
         "tr multibyte identity bracket output");

      Context.Initialize ("tr", Two_Args ("[.ch.]", "X"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "chico");
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XXiXo",
         "tr locale collating symbol expands as a multibyte element");

      Context.Initialize ("tr", Two_Args ("[.a\n.]", "XY"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "XY",
         "tr escaped multibyte collating output");

      Context.Initialize ("tr", Two_Args ("abc", "xyz"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Test_Contexts.Set_Output_Failure_After (Context, 1);
      Posix_Tools.Commands.Tr.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "tr output failure status");

      Context.Initialize ("uniq", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "uniq output");

      Context.Initialize ("uniq", One_Arg ("-c"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "      2 a" & EOL & "      1 b" & EOL,
         "uniq -c output");

      Context.Initialize ("uniq", One_Arg ("-d"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL, "uniq -d output");

      Context.Initialize ("uniq", One_Arg ("-u"));
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL & "a" & EOL & "b" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "b" & EOL, "uniq -u output");

      Context.Initialize ("uniq", Two_Args ("-f", "1"));
      Test_Contexts.Set_Standard_Input (Context, "1 same" & EOL & "2 same" & EOL & "3 other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "1 same" & EOL & "3 other" & EOL,
         "uniq -f output");

      Context.Initialize ("uniq", Two_Args ("-f", "1"));
      Test_Contexts.Set_Standard_Input
        (Context,
         "1" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
         & "2" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
         & "3" & Character'Val (16#C2#) & Character'Val (16#A0#) & "other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "1" & Character'Val (16#C2#) & Character'Val (16#A0#) & "same" & EOL
           & "3" & Character'Val (16#C2#) & Character'Val (16#A0#) & "other" & EOL,
         "uniq -f uses Unicode whitespace");

      Context.Initialize ("uniq", One_Arg ("-s1"));
      Test_Contexts.Set_Standard_Input (Context, "asame" & EOL & "bsame" & EOL & "cother" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "asame" & EOL & "cother" & EOL,
         "uniq -s output");

      Context.Initialize ("uniq", One_Arg ("-s1"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A6#) & "same" & EOL
         & Character'Val (16#C3#) & Character'Val (16#B8#) & "same" & EOL
         & Character'Val (16#C3#) & Character'Val (16#A5#) & "other" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C3#) & Character'Val (16#A6#) & "same" & EOL
           & Character'Val (16#C3#) & Character'Val (16#A5#) & "other" & EOL,
         "uniq -s skips UTF-8 characters");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input (Context, "Alpha" & EOL & "alpha" & EOL & "Beta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "Alpha" & EOL & "Beta" & EOL,
         "uniq -i output");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#CE#) & Character'Val (16#A3#) & EOL
         & Character'Val (16#CF#) & Character'Val (16#83#) & EOL
         & Character'Val (16#D0#) & Character'Val (16#AF#) & EOL
         & Character'Val (16#D1#) & Character'Val (16#8F#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#CE#) & Character'Val (16#A3#) & EOL
           & Character'Val (16#D0#) & Character'Val (16#AF#) & EOL,
         "uniq -i folds UTF-8 Greek and Cyrillic case pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C4#) & Character'Val (16#80#) & EOL
         & Character'Val (16#C4#) & Character'Val (16#81#) & EOL
         & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
         & Character'Val (16#D5#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL
         & Character'Val (16#E1#) & Character'Val (16#83#) & Character'Val (16#90#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C4#) & Character'Val (16#80#) & EOL
           & Character'Val (16#D4#) & Character'Val (16#B1#) & EOL
           & Character'Val (16#E1#) & Character'Val (16#B2#) & Character'Val (16#90#) & EOL,
         "uniq -i folds UTF-8 Latin Extended Armenian and Georgian pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C6#) & Character'Val (16#81#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#93#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#94#) & EOL
         & Character'Val (16#C6#) & Character'Val (16#90#) & EOL
         & Character'Val (16#C9#) & Character'Val (16#9B#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#C6#) & Character'Val (16#81#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#86#) & EOL
           & Character'Val (16#C6#) & Character'Val (16#90#) & EOL,
         "uniq -i folds UTF-8 Latin Extended-B pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL
         & Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#A8#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#F0#) & Character'Val (16#90#) & Character'Val (16#90#) & Character'Val (16#80#) & EOL,
         "uniq -i folds UTF-8 Deseret pairs");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
         & Character'Val (16#EA#) & Character'Val (16#AD#) & Character'Val (16#B0#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL
         & Character'Val (16#EF#) & Character'Val (16#BD#) & Character'Val (16#81#) & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Character'Val (16#E1#) & Character'Val (16#8E#) & Character'Val (16#A0#) & EOL
           & Character'Val (16#EF#) & Character'Val (16#BC#) & Character'Val (16#A1#) & EOL,
         "uniq -i folds UTF-8 Cherokee and Fullwidth Latin pairs");

      Context.Initialize ("uniq", One_Arg ("-ci"));
      Test_Contexts.Set_Standard_Input (Context, "Alpha" & EOL & "alpha" & EOL & "Beta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "      2 Alpha" & EOL & "      1 Beta" & EOL,
         "uniq grouped -ci output");

      Context.Initialize ("uniq", One_Arg ("-c"));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input
        (Context,
         Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
         & Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#AB#) & EOL
         & "z" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           "      2 " & Character'Val (16#C3#) & Character'Val (16#A5#) & EOL
           & "      1 z" & EOL,
         "uniq uses Danish locale collation equivalence");

      Context.Initialize ("uniq", One_Arg ("-i"));
      Test_Contexts.Set_Locale (Context, "es");
      Test_Contexts.Set_Standard_Input (Context, "Ch" & EOL & "ch" & EOL & "d" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "Ch" & EOL & "d" & EOL,
         "uniq -i uses locale collation key after case folding");

      Context.Initialize ("uniq", Two_Args ("-i", "-s1"));
      Test_Contexts.Set_Standard_Input (Context, "xAlpha" & EOL & "yalpha" & EOL & "zBeta" & EOL);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "xAlpha" & EOL & "zBeta" & EOL,
         "uniq -i -s output");

      Context.Initialize ("uniq", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "a" & EOL);
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Uniq.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "uniq output failure status");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b" & EOL, "xargs output");

      Context.Initialize ("xargs", Two_Args ("--", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b" & EOL, "xargs honors end-of-options");

      Context.Initialize ("xargs", Three_Args ("echo", "-n1", "fixed"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-n1 fixed a b" & EOL,
         "xargs stops option parsing after utility operand");

      Context.Initialize ("xargs", Two_Args ("-r", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "xargs -r skips empty input");

      Context.Initialize ("xargs", Two_Args ("--no-run-if-empty", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "   " & Character'Val (9));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "xargs long no-run skips blank input");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a   b" & Character'Val (9) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs collapses blanks");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a 'b c' ""d e""");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c d e" & EOL, "xargs quote grouping");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a 'b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects unmatched single quote");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a ""b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects unmatched double quote");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a\ b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs backslash grouping");

      Context.Initialize ("xargs", One_Arg ("echo"));
      Test_Contexts.Set_Standard_Input (Context, "a\");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects trailing backslash");

      Context.Initialize ("xargs", Two_Args ("-n1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "'a b' c\ d");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c d" & EOL,
         "xargs grouped operands batch as single items");

      Context.Initialize ("xargs", Three_Args ("-n", "2", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c" & EOL,
         "xargs -n output");

      Context.Initialize ("xargs", Three_Args ("-s", "11", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb cc");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "aa bb" & EOL & "cc" & EOL,
         "xargs -s splits by composed command size");

      Context.Initialize ("xargs", Two_Args ("-s9", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "aa" & EOL & "bb" & EOL,
         "xargs compact -s splits by composed command size");

      Context.Initialize ("xargs", Two_Args ("-t", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a b" & EOL
         and then Test_Contexts.Error_Output (Context) = "echo a b" & EOL,
         "xargs -t traces composed command");

      Context.Initialize ("xargs", Two_Args ("-t", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "xargs -t reports trace output failure");

      Context.Initialize ("xargs", Four_Args ("-x", "-s", "11", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "aa bb cc");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "xargs -x fails instead of splitting oversized batch");

      Context.Initialize ("xargs", Two_Args ("-s", "0"));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects zero command size");

      Context.Initialize ("xargs", Four_Args ("-I", "{}", "echo", "file-{}"));
      Test_Contexts.Set_Standard_Input (Context, "one two" & EOL & "three" & EOL);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "file-one two" & EOL & "file-three" & EOL,
         "xargs -I replacement output");

      Context.Initialize ("xargs", Three_Args ("-I{}", "echo", "{}/suffix"));
      Test_Contexts.Set_Standard_Input (Context, "root" & EOL);
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "root/suffix" & EOL,
         "xargs compact -I replacement output");

      Context.Initialize ("xargs", One_Arg ("-I"));
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "xargs rejects missing -I replacement string");

      Context.Initialize ("xargs", Three_Args ("-E", "STOP", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b STOP c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL,
         "xargs -E output");

      Context.Initialize ("xargs", Five_Args ("-E", "STOP", "-n", "1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a STOP c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL,
         "xargs -E -n output");

      Context.Initialize ("xargs", Two_Args ("-0", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b" & Character'Val (0) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a b c" & EOL, "xargs -0 output");

      Context.Initialize ("xargs", Four_Args ("-0", "-n", "1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b" & Character'Val (0) & "c");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a b" & EOL & "c" & EOL,
         "xargs -0 -n output");

      Context.Initialize ("xargs", Two_Args ("-n1", "echo"));
      Test_Contexts.Set_Standard_Input (Context, "a b");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL,
         "xargs compact -n output");

      Context.Initialize ("xargs", One_Arg ("false"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Code (123),
         "xargs classifies non-zero utility status");

      Context.Initialize ("xargs", One_Arg ("xargs-status-255"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Code (124),
         "xargs classifies utility status 255");

      Context.Initialize ("xargs", One_Arg ("xargs-cannot-invoke"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Cannot_Invoke,
         "xargs classifies utility status 126");

      Context.Initialize ("xargs", One_Arg ("missing-utility"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "xargs classifies missing utility");

      Context.Initialize ("date", No_Args);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length > 1, "date output");

      Context.Initialize ("date", One_Arg ("+%%"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "%" & EOL, "date escaped percent output");

      Context.Initialize ("date", One_Arg ("+blocked"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "date reports standard-output failure");

      Context.Initialize ("date", One_Arg ("+literal"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "literal" & EOL, "date literal format output");

      Context.Initialize ("date", Two_Args ("--", "+%Y"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 5
            and then (for all I in Output'First .. Output'First + 3 => Output (I) in '0' .. '9')
            and then Output (Output'Last) = EOL,
            "date honors end-of-options before format");
      end;

      Context.Initialize ("date", One_Arg ("+%F %T %R %y"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 29
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then Output (Output'First + 10) = ' '
            and then Output (Output'First + 13) = ':'
            and then Output (Output'First + 16) = ':'
            and then Output (Output'First + 19) = ' '
            and then Output (Output'First + 22) = ':'
            and then Output (Output'First + 25) = ' '
            and then Output (Output'First + 28) = EOL,
            "date composite format output");
      end;

      Context.Initialize ("date", One_Arg ("+%x %X"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 18
            and then Output (Output'First + 2) = '/'
            and then Output (Output'First + 5) = '/'
            and then Output (Output'First + 8) = ' '
            and then Output (Output'First + 11) = ':'
            and then Output (Output'First + 14) = ':'
            and then Output (Output'First + 17) = EOL,
            "date localized composite shape output");
      end;

      Context.Initialize ("date", One_Arg ("+%c"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length >= 25
            and then Contains (Output, ":")
            and then not Contains (Output, "%c")
            and then Output (Output'Last) = EOL,
            "date full composite output");
      end;

      Context.Initialize ("date", One_Arg ("+%C %D %e %I %k %l %p %r %u %w %j"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 47
            and then Output (Output'First + 2) = ' '
            and then Output (Output'First + 5) = '/'
            and then Output (Output'First + 8) = '/'
            and then Output (Output'First + 11) = ' '
            and then Output (Output'First + 14) = ' '
            and then Output (Output'First + 17) = ' '
            and then Output (Output'First + 20) = ' '
            and then Output (Output'First + 23) = ' '
            and then Output (Output'First + 26) = ' '
            and then Output (Output'First + 29) = ':'
            and then Output (Output'First + 32) = ':'
            and then Output (Output'First + 35) = ' '
            and then Output (Output'First + 38) = ' '
            and then Output (Output'First + 40) = ' '
            and then Output (Output'First + 42) = ' '
            and then Output (Output'First + 46) = EOL,
            "date extended numeric format output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);

         function Has_Word (Needle : String) return Boolean is
         begin
            return Contains (Output, Needle & " ") or else Contains (Output, " " & Needle & EOL);
         end Has_Word;
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "Mon ") or else Contains (Output, "Tue ") or else Contains (Output, "Wed ")
             or else Contains (Output, "Thu ") or else Contains (Output, "Fri ") or else Contains (Output, "Sat ")
             or else Contains (Output, "Sun "))
            and then (Has_Word ("January") or else Has_Word ("February") or else Has_Word ("March")
              or else Has_Word ("April") or else Has_Word ("May") or else Has_Word ("June")
              or else Has_Word ("July") or else Has_Word ("August") or else Has_Word ("September")
              or else Has_Word ("October") or else Has_Word ("November") or else Has_Word ("December")),
            "date weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "mandag") or else Contains (Output, "tirsdag")
             or else Contains (Output, "onsdag") or else Contains (Output, "torsdag")
             or else Contains (Output, "fredag") or else Contains (Output, "lørdag")
             or else Contains (Output, "søndag"))
            and then (Contains (Output, "januar") or else Contains (Output, "februar")
              or else Contains (Output, "marts") or else Contains (Output, "april")
              or else Contains (Output, "maj") or else Contains (Output, "juni")
              or else Contains (Output, "juli") or else Contains (Output, "august")
              or else Contains (Output, "september") or else Contains (Output, "oktober")
              or else Contains (Output, "november") or else Contains (Output, "december")),
            "date Danish weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "lunes") or else Contains (Output, "martes")
             or else Contains (Output, "miercoles") or else Contains (Output, "jueves")
             or else Contains (Output, "viernes") or else Contains (Output, "sabado")
             or else Contains (Output, "domingo"))
            and then (Contains (Output, "enero") or else Contains (Output, "febrero")
              or else Contains (Output, "marzo") or else Contains (Output, "abril")
              or else Contains (Output, "mayo") or else Contains (Output, "junio")
              or else Contains (Output, "julio") or else Contains (Output, "agosto")
              or else Contains (Output, "septiembre") or else Contains (Output, "octubre")
              or else Contains (Output, "noviembre") or else Contains (Output, "diciembre")),
            "date Spanish weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "zz");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "Mon ") or else Contains (Output, "Tue ") or else Contains (Output, "Wed ")
             or else Contains (Output, "Thu ") or else Contains (Output, "Fri ") or else Contains (Output, "Sat ")
             or else Contains (Output, "Sun "))
            and then not Contains (Output, "posix_tools.date."),
            "date unknown locale falls back without message-key leak");
      end;

      Context.Initialize ("date", One_Arg ("+%b %h"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 8
            and then Output (Output'First .. Output'First + 2) =
              Output (Output'First + 4 .. Output'First + 6)
            and then Output (Output'Last) = EOL,
            "date %h aliases abbreviated month name");
      end;

      Context.Initialize ("date", One_Arg ("+%G-%g-%V"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 11
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then not Contains (Output, "%G")
            and then not Contains (Output, "%g")
            and then not Contains (Output, "%V")
            and then Output (Output'Last) = EOL,
            "date ISO week format output");
      end;

      Context.Initialize ("date", One_Arg ("+%U %W"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '0' .. '9'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) = ' '
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'Last) = EOL
            and then not Contains (Output, "%U")
            and then not Contains (Output, "%W"),
            "date POSIX week number output");
      end;

      Context.Initialize ("date", One_Arg ("+%z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '+' | '-'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) in '0' .. '9'
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'First + 5) = EOL,
            "date timezone offset output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "+%z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000" & EOL, "date -u timezone output");

      Context.Initialize ("date", Two_Args ("-u", "+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "CET-1");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0000 UTC" & EOL,
         "date -u overrides TZ fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "GMT+00:00");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ signed colon UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC-0000");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ signed compact UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0230 UTC" & EOL, "date TZ positive fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "GMT-0330");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "-0330 GMT" & EOL, "date TZ negative fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "CET-1");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "-0100 CET" & EOL, "date TZ named hour offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "EST5EDT");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0500 EST" & EOL,
         "date TZ ignores DST suffix after standard offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "EST5EDT,M3.2.0,M11.1.0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0500 EST" & EOL,
         "date TZ ignores DST transition rules after standard offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "FOO+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0230 FOO" & EOL, "date TZ named colon offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "<UTC+1>+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0230 UTC+1" & EOL,
         "date TZ quoted non-alphabetic name output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "<-0330>-03:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-0330 -0330" & EOL,
         "date TZ quoted signed name output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "BAR0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 BAR" & EOL, "date TZ named zero offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "Etc/UTC");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ i18n UTC zone");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "Asia/Kolkata");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0530 IST" & EOL
         or else Test_Contexts.Output (Context) = "+0530 Asia/Kolkata" & EOL,
         "date TZ i18n regional zone");

      Context.Initialize ("date", Two_Args ("-u", "+%Z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "UTC" & EOL, "date -u timezone name output");

      Context.Initialize ("date", One_Arg ("+%Z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '+' | '-'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) in '0' .. '9'
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'First + 5) = EOL,
            "date local timezone name fallback output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "+%F %T"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 20
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then Output (Output'First + 10) = ' '
            and then Output (Output'First + 13) = ':'
            and then Output (Output'First + 16) = ':'
            and then Output (Output'First + 19) = EOL,
            "date -u timestamp shape");
      end;

      Context.Initialize ("date", One_Arg ("+%s"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length >= 2
            and then Output (Output'Last) = EOL
            and then (for all I in Output'First .. Output'Last - 1 => Output (I) in '0' .. '9'),
            "date epoch seconds output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "010203042026.05"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "date set operand status");
      AUnit.Assertions.Assert (Test_Contexts.Date_Set_Called (Context), "date set operand calls context setter");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "2026")
         and then Contains (Test_Contexts.Output (Context), "03:04:05"),
         "date set operand reports selected timestamp");

      Context.Initialize ("date", Two_Args ("-u", "01020304"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "date set operand current year status");

      Context.Initialize ("date", Two_Args ("-u", "0102030469"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "1969"),
         "date set operand maps two-digit year 69 to 1969");

      Context.Initialize ("date", Two_Args ("-u", "0102030468"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "2068"),
         "date set operand maps two-digit year 68 to 2068");

      Context.Initialize ("date", One_Arg ("13320304"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "date rejects invalid set operand");

      Context.Initialize ("date", One_Arg ("010203042026"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "date reports failed system date set");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "date: cannot set system date" & EOL,
         "date set failure diagnostic");

      Context.Initialize ("env", Two_Args ("-i", "NAME=value"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "env status");
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "NAME=value" & EOL, "env -i assignment output");

      Context.Initialize ("env", Two_Args ("-i", "NAME=value"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "env reports standard-output failure");

      Context.Initialize ("env", One_Arg ("B=3"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Test_Contexts.Set_Environment_Value (Context, "B", "2");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A=1" & EOL & "B=3" & EOL,
         "env inherited and replacement output");

      Context.Initialize ("env", Two_Args ("-u", "A"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Test_Contexts.Set_Environment_Value (Context, "B", "2");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "B=2" & EOL,
         "env -u removes inherited variable");

      Context.Initialize ("env", Three_Args ("-u", "A", "A=3"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A=3" & EOL,
         "env -u allows later replacement");

      Context.Initialize ("env", One_Arg ("-u"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "env -u missing operand status");

      Context.Initialize ("env", One_Arg ("-i"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "env -i empty output");

      Context.Initialize ("env", One_Arg ("=bad"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "env rejects empty name");

      Context.Initialize ("env", Three_Args ("-i", "--", "NAME=value"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "NAME=value" & EOL,
         "env accepts assignment after --");

      Context.Initialize ("env", Four_Args ("-i", "NAME=value", "printenv", "NAME"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "value" & EOL,
         "env executes utility with computed environment");

      Context.Initialize ("env", Two_Args ("-i", "false"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "env returns utility nonzero status");

      Context.Initialize ("env", Two_Args ("--", "-i"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "env treats option after -- as missing utility");

      Context.Initialize ("find", One_Arg (Source));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Source & EOL, "find file output");

      Context.Initialize ("find", One_Arg (Source));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "find reports standard-output failure");

      Context.Initialize ("find", Two_Args (Source, "-print"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = Source & EOL, "find explicit -print output");

      Context.Initialize ("find", One_Arg ("-"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "-" & EOL,
         "find treats - as path operand");

      Context.Initialize ("find", Two_Args ("--", "-name"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "-name" & EOL,
         "find treats option-like operand after -- as path operand");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-name", "expanded-source.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -name output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-name", "expanded-source.t?t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -name question wildcard output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-name", "expanded-source.[tx][xq]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -name bracket list output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-name", "expanded-source.[a-z][a-z]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -name bracket range output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-name", "expanded-source.[!0-9][!0-9]t"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -name negated bracket range output");

      Context.Initialize ("find", Three_Args (Tree, "-path", "*/sub/file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "expanded-tree" & EOL),
         "find -path output");

      Context.Initialize ("find", Three_Args (Tree, "-type", "d"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-tree" & EOL)
         and then Contains (Test_Contexts.Output (Context), "sub" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -type d output");

      Context.Initialize ("find", Three_Args (Tree, "-type", "p"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "find exact FIFO type excludes ordinary tree entries");

      if Hostkit.Fs.Special_File_Info_Of (Cp_FIFO_Source).Kind = Hostkit.Fs.FIFO then
         Context.Initialize ("find", Three_Args (Cp_FIFO_Source, "-type", "p"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = Cp_FIFO_Source & EOL,
            "find -type p matches FIFO exactly");
      end if;

      if Hostkit.Fs.Special_File_Info_Of (Cp_Socket_Source).Kind = Hostkit.Fs.Socket then
         Context.Initialize ("find", Three_Args (Cp_Socket_Source, "-type", "s"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = Cp_Socket_Source & EOL,
            "find -type s matches socket exactly");
      end if;

      if Ada.Directories.Exists ("/dev/null")
        and then Hostkit.Fs.Special_File_Info_Of ("/dev/null").Kind = Hostkit.Fs.Character_Device
      then
         Context.Initialize ("find", Three_Args ("/dev/null", "-type", "c"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "/dev/null" & EOL,
            "find -type c matches character device exactly");

         Context.Initialize ("find", Three_Args ("/dev/null", "-type", "b"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Test_Contexts.Output (Context) = "",
            "find -type b excludes character device");
      end if;

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-size", "9c"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -size exact bytes output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-size", "+8c"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -size greater bytes output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-size", "-2"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -size less default blocks output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-size", "bad"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects invalid -size count");

      Write_File (Source, "copy-data");
      Write_File (Other, "old-data");
      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Other,
         GNAT.OS_Lib.GM_Time_Of (2020, 1, 2, 3, 4, 5));

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-mtime", "-1"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -mtime less than one day output");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-mtime", "+99999"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (not Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -mtime greater than large age excludes current file");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-mtime", "bad"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects invalid -mtime count");

      Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-newer", Other));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
         "find -newer reference output");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "seen", "{}", ";"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "seen " & Source & EOL,
         "find -exec replacement output");

      Context.Initialize ("find", Four_Args (Source, "-exec", "false", ";"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "find -exec false suppresses default output");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "plus", "{}", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "plus " & Source & EOL,
         "find -exec plus replacement output");

      Context.Initialize ("find", Six_Args (Tree, "-exec", "echo", "batch", "{}", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "batch " & Tree & " " & Tree & "/sub "
           & Tree & "/sub/file.txt" & EOL,
         "find -exec plus batches matches");

      Context.Initialize ("find", Six_Args (Source, "-exec", "echo", "{}", "after", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects plus without preceding replacement");

      Context.Initialize ("find", Three_Args (Source, "-exec", "+"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects missing utility before -exec plus");

      Context.Initialize ("find", Four_Args (Source, "-exec", "echo", "{}"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects unterminated -exec");

      Context.Initialize ("find", Six_Args (Source, "-ok", "echo", "ok", "{}", ";"));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ok " & Source & EOL
         and then Contains (Test_Contexts.Error_Output (Context), "< echo ... " & Source & " > ?"),
         "find -ok executes after affirmative response");

      Context.Initialize ("find", Six_Args (Source, "-ok", "echo", "ok", "{}", ";"));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Contains (Test_Contexts.Error_Output (Context), "< echo ... " & Source & " > ?"),
         "find -ok skips after negative response");

      Context.Initialize ("find", Four_Args (Source, "-ok", "echo", "{}"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "find rejects unterminated -ok");

      Context.Initialize ("find", Two_Args (Tree, "-depth"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) =
           Tree & "/sub/file.txt" & EOL
           & Tree & "/sub" & EOL
           & Tree & EOL,
         "find -depth post-order output");

      Context.Initialize ("find", Four_Args (Tree, "-name", "sub", "-prune"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "sub" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -prune skips subtree");

      Context.Initialize ("find", Two_Args (Tree, "-xdev"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), Tree & EOL)
         and then Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -xdev keeps traversal on the starting device");

      if Hostkit.Metadata.Permissions_Supported then
         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Tree & "/sub/file.txt", 8#640#),
            "find -perm file mode setup");
         Context.Initialize ("find", Three_Args (Tree, "-perm", "640"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm exact output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "-600"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm all-bits output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "u=rw,g=r,o="));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm symbolic exact output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "-u=rw"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
            "find -perm symbolic all-bits output");

         Context.Initialize ("find", Three_Args (Tree, "-perm", "bad"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
            "find rejects invalid -perm mode");
      end if;

      if Hostkit.Metadata.Ownership_Supported then
         declare
            User_Id : Natural;
            Group_Id : Natural;
            Available : Boolean;
         begin
            Hostkit.Metadata.File_Ownership (Source, User_Id, Group_Id, Available);
            if Available then
               declare
                  User_Raw : constant String := Natural'Image (User_Id);
                  Group_Raw : constant String := Natural'Image (Group_Id);
                  User_Text : constant String := User_Raw (User_Raw'First + 1 .. User_Raw'Last);
                  Group_Text : constant String := Group_Raw (Group_Raw'First + 1 .. Group_Raw'Last);
                  User_Name : constant String := Hostkit.Metadata.User_Name_For_Id (User_Id);
                  Group_Name : constant String := Hostkit.Metadata.Group_Name_For_Id (Group_Id);
               begin
                  Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-user", User_Text));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
                     "find -user numeric output");

                  Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-group", Group_Text));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
                     "find -group numeric output");

                  if User_Name /= "" then
                     Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-user", User_Name));
                     Posix_Tools.Commands.Find.Run (Context, Result);
                     AUnit.Assertions.Assert
                       (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
                        "find -user named output");
                  end if;

                  if Group_Name /= "" then
                     Context.Initialize ("find", Three_Args (Fixture_Path ("."), "-group", Group_Name));
                     Posix_Tools.Commands.Find.Run (Context, Result);
                     AUnit.Assertions.Assert
                       (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL),
                        "find -group named output");
                  end if;

                  Context.Initialize ("find", Two_Args (Fixture_Path ("."), "-nouser"));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success
                     and then (User_Name = ""
                               or else not Contains
                                 (Test_Contexts.Output (Context), "expanded-source.txt" & EOL)),
                     "find -nouser output");

                  Context.Initialize ("find", Two_Args (Fixture_Path ("."), "-nogroup"));
                  Posix_Tools.Commands.Find.Run (Context, Result);
                  AUnit.Assertions.Assert
                    (Result.Status = Posix_Tools.Exit_Status.Success
                     and then (Group_Name = ""
                               or else not Contains
                                 (Test_Contexts.Output (Context), "expanded-source.txt" & EOL)),
                     "find -nogroup output");
               end;
            end if;
         end;
      end if;

      Context.Initialize ("find", Five_Args (Tree, "-type", "f", "-name", "file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL),
         "find -type f -name output");

      Context.Initialize ("find", Six_Args (Tree, "-type", "f", "-a", "-name", "file.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "sub" & EOL),
         "find explicit and expression output");

      Context.Initialize
        ("find",
         Six_Args (Fixture_Path ("."), "-name", "expanded-source.txt", "-o", "-name", "expanded-other.txt"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "expanded-source.txt" & EOL)
         and then Contains (Test_Contexts.Output (Context), "expanded-other.txt" & EOL),
         "find or expression output");

      Context.Initialize ("find", Four_Args (Tree, "!", "-type", "d"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "expanded-tree" & EOL),
         "find negated expression output");

      Context.Initialize ("find", Six_Args (Tree, "(", "-name", "file.txt", ")", "-print"));
      Posix_Tools.Commands.Find.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "file.txt" & EOL)
         and then not Contains (Test_Contexts.Output (Context), "expanded-tree" & EOL),
         "find parenthesized print expression output");

      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("find", Three_Args (Symlinked, "-type", "l"));
         Posix_Tools.Commands.Find.Run (Context, Result);
         AUnit.Assertions.Assert
           (Test_Contexts.Output (Context) = Symlinked & EOL,
            "find -type l output");
      end if;

      Context.Initialize ("test", One_Arg ("value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test true status");

      Context.Initialize ("test", Two_Args ("-n", "value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -n status");

      Context.Initialize ("test", Two_Args ("-z", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -z status");

      Context.Initialize ("test", Two_Args ("-e", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -e file status");

      Context.Initialize ("test", Two_Args ("-d", Tree));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -d directory status");

      Context.Initialize ("test", Two_Args ("-f", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -f file status");

      Context.Initialize ("test", Two_Args ("-r", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -r readable file status");

      if Hostkit.Metadata.Permissions_Supported then
         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#600#),
            "test writable source mode setup");
         Context.Initialize ("test", Two_Args ("-w", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -w status");

         Context.Initialize ("test", Two_Args ("-x", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -x false status");

         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#700#),
            "test executable source mode setup");
         Context.Initialize ("test", Two_Args ("-x", Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -x status");

         if Hostkit.Metadata.Set_Permissions (Source, 8#4700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Source, Available);
            begin
               if Available and then (Mode / 8#4000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-u", Source));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -u status");
               end if;
            end;
         end if;

         if Hostkit.Metadata.Set_Permissions (Source, 8#2700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Source, Available);
            begin
               if Available and then (Mode / 8#2000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-g", Source));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -g status");
               end if;
            end;
         end if;

         if Hostkit.Metadata.Set_Permissions (Made, 8#1700#) then
            declare
               Available : Boolean;
               Mode      : constant Natural := Hostkit.Metadata.File_Permission_Bits (Made, Available);
            begin
               if Available and then (Mode / 8#1000#) mod 2 = 1 then
                  Context.Initialize ("test", Two_Args ("-k", Made));
                  Posix_Tools.Commands.Test_Command.Run (Context, Result);
                  AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -k status");
               end if;
            end;
         end if;

         AUnit.Assertions.Assert
           (Hostkit.Metadata.Set_Permissions (Source, 8#700#),
            "test source mode restore");
      end if;

      if Hostkit.Fs.Is_Link (Symlinked) then
         Context.Initialize ("test", Two_Args ("-h", Symlinked));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -h symlink status");

         Context.Initialize ("test", Two_Args ("-L", Symlinked));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -L symlink status");
      end if;

      Context.Initialize ("test", Three_Args (Source, "-ef", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -ef same file status");

      Context.Initialize ("test", Three_Args (Source, "-ef", Other));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -ef different file status");

      Context.Initialize ("test", Three_Args ("alpha", "<", "beta"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test string less-than status");

      Context.Initialize ("test", Three_Args ("beta", ">", "alpha"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test string greater-than status");

      Context.Initialize ("test", Three_Args ("alpha", ">", "beta"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test string greater-than false status");

      Context.Initialize ("test", Two_Args ("-r", No_Create));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -r missing file status");

      Context.Initialize ("test", Two_Args ("-s", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -s nonempty file status");

      Context.Initialize ("test", Two_Args ("-s", Empty));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -s empty file status");

      Context.Initialize ("test", Two_Args ("-s", No_Create));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -s missing file status");

      Context.Initialize ("test", Two_Args ("-b", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -b regular file status");

      Context.Initialize ("test", Two_Args ("-c", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -c regular file status");

      Context.Initialize ("test", Two_Args ("-p", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -p regular file status");

      Context.Initialize ("test", Two_Args ("-S", Source));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -S regular file status");

      if Hostkit.Fs.Special_File_Info_Of (Cp_FIFO_Source).Kind = Hostkit.Fs.FIFO then
         Context.Initialize ("test", Two_Args ("-p", Cp_FIFO_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -p FIFO status");

         Context.Initialize ("test", Two_Args ("-S", Cp_FIFO_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -S excludes FIFO status");
      end if;

      if Hostkit.Fs.Special_File_Info_Of (Cp_Socket_Source).Kind = Hostkit.Fs.Socket then
         Context.Initialize ("test", Two_Args ("-S", Cp_Socket_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -S socket status");

         Context.Initialize ("test", Two_Args ("-p", Cp_Socket_Source));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -p excludes socket status");
      end if;

      if Ada.Directories.Exists ("/dev/null")
        and then Hostkit.Fs.Special_File_Info_Of ("/dev/null").Kind = Hostkit.Fs.Character_Device
      then
         Context.Initialize ("test", Two_Args ("-c", "/dev/null"));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success,
            "test -c character device status");

         Context.Initialize ("test", Two_Args ("-b", "/dev/null"));
         Posix_Tools.Commands.Test_Command.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
            "test -b excludes character device status");
      end if;

      Context.Initialize ("test", Two_Args ("-t", "0"));
      Test_Contexts.Set_Standard_Input_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stdin status");

      Context.Initialize ("test", Two_Args ("-t", "1"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stdout status");

      Context.Initialize ("test", Two_Args ("-t", "2"));
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -t stderr status");

      Context.Initialize ("test", Two_Args ("-t", "9"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test -t unsupported fd status");

      Context.Initialize ("test", Three_Args ("42", "-eq", "42"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test -eq status");

      Context.Initialize ("test", Three_Args ("-2", "-lt", "+3"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test signed -lt status");

      Context.Initialize ("test", Three_Args ("!", "-n", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test negated unary status");

      Context.Initialize ("test", Four_Args ("!", "1", "=", "2"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test negated equality status");

      Context.Initialize ("test", Four_Args ("!", "2", "-gt", "1"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test negated numeric status");

      Context.Initialize ("test", Five_Args ("-n", "x", "-a", "-z", ""));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test and status");

      Context.Initialize ("test", Three_Args ("", "-o", "fallback"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test or status");

      Context.Initialize ("test", Five_Args ("", "-o", "", "-a", "x"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test and precedence status");

      Context.Initialize ("test", Six_Args ("!", "x", "-o", "", "-a", "y"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test negated compound status");

      Context.Initialize ("test", Three_Args ("(", "value", ")"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "test parenthesized status");

      Context.Initialize ("test", Three_Args ("abc", "-eq", "0"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "test invalid numeric comparison is false");

      Context.Initialize ("test", Two_Args ("(", "value"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unbalanced opening parenthesis");

      Context.Initialize ("test", Two_Args ("value", ")"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unbalanced closing parenthesis");

      Context.Initialize ("test", Two_Args ("value", "-a"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects dangling and operator");

      Context.Initialize ("test", Three_Args ("a", "-bad", "b"));
      Posix_Tools.Commands.Test_Command.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "test rejects unknown binary operator");

      Write_File (Cksum_File, "abc");
      Context.Initialize ("cksum", One_Arg (Cksum_File));
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), " 3 " & Cksum_File),
         "cksum prints checksum length and operand");

      Context.Initialize ("cksum", No_Args);
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1219131554 3" & EOL,
         "cksum reads implicit standard input");

      Context.Initialize ("cksum", One_Arg ("--"));
      Test_Contexts.Set_Standard_Input (Context, "abc");
      Posix_Tools.Commands.Cksum.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "1219131554 3" & EOL,
         "cksum treats a sole -- as end-of-options before implicit standard input");

      Write_File (Cmp_First, "same" & EOL);
      Write_File (Cmp_Second, "same" & EOL);
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "cmp accepts equal files quietly");

      Write_File (Cmp_Second, "sage" & EOL);
      Context.Initialize ("cmp", Two_Args (Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Contains (Test_Contexts.Output (Context), "differ"),
         "cmp reports the first difference");

      Write_File (Cmp_First, "abc");
      Write_File (Cmp_Second, "axd");
      Context.Initialize ("cmp", Three_Args ("-l", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "2 142 170" & EOL & "3 143 144" & EOL,
         "cmp -l lists all differing byte values in octal");

      Context.Initialize ("cmp", Four_Args ("-l", "-s", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "cmp -s suppresses cmp -l output");

      Context.Initialize ("cmp", Four_Args ("-s", "--", Cmp_First, Cmp_Second));
      Posix_Tools.Commands.Cmp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "cmp accepts -- after -s and stays silent");

      Write_File (Paste_First, "a" & EOL & "b" & EOL);
      Write_File (Paste_Second, "1" & EOL & "2" & EOL);
      Context.Initialize ("paste", Two_Args (Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "1" & EOL
           & "b" & Character'Val (9) & "2" & EOL,
         "paste merges lines with tabs");

      Context.Initialize ("paste", Three_Args ("--", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "1" & EOL
           & "b" & Character'Val (9) & "2" & EOL,
         "paste honors end-of-options before file operands");

      Context.Initialize ("paste", Four_Args ("-d", "|", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a|1" & EOL & "b|2" & EOL,
         "paste accepts a separate delimiter list");

      Context.Initialize ("paste", Three_Args ("-d,", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a,1" & EOL & "b,2" & EOL,
         "paste accepts an attached delimiter list");

      Context.Initialize ("paste", Three_Args ("-s", Paste_First, Paste_Second));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & Character'Val (9) & "b" & EOL
           & "1" & Character'Val (9) & "2" & EOL,
         "paste serial mode combines each file separately");

      Context.Initialize ("paste", One_Arg ("-d"));
      Posix_Tools.Commands.Paste.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-d'"),
         "paste rejects a missing delimiter list");

      Write_File (Cut_File, "abcd" & EOL & "wxyz" & EOL);
      Context.Initialize ("cut", Three_Args ("-b", "2-3", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "bc" & EOL & "xy" & EOL,
         "cut selects byte ranges");

      Context.Initialize ("cut", Three_Args ("-b", "1 4", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ad" & EOL & "wz" & EOL,
         "cut accepts blank-separated list entries");

      Context.Initialize ("cut", Four_Args ("-n", "-b", "1-2", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "ab" & EOL & "wx" & EOL,
         "cut accepts -n with byte mode");

      Context.Initialize ("cut", Three_Args ("-n", "-c", "1"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "cut rejects -n outside byte mode");

      Write_File (Cut_File, "a,b,c" & EOL);
      Context.Initialize ("cut", Five_Args ("-f", "2", "-d", ",", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & EOL,
         "cut selects delimited fields");

      Context.Initialize ("cut", Four_Args ("-f", "2", "-d,", Cut_File));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "b" & EOL,
         "cut accepts an attached delimiter option argument");

      Context.Initialize ("cut", Two_Args ("-f", "2"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "",
         "cut reads standard input when only a list option is supplied");

      Context.Initialize ("cut", Three_Args ("-f", "2", "-d"));
      Posix_Tools.Commands.Cut.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-d'"),
         "cut rejects a missing delimiter argument");

      Write_File (Comm_First, "a" & EOL & "b" & EOL);
      Write_File (Comm_Second, "b" & EOL & "c" & EOL);
      Context.Initialize ("comm", Two_Args (Comm_First, Comm_Second));
      Posix_Tools.Commands.Comm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "a" & EOL
           & Character'Val (9) & Character'Val (9) & "b" & EOL
           & Character'Val (9) & "c" & EOL,
         "comm merges sorted files into three columns");

      Write_File (Od_File, "A");
      Context.Initialize ("od", One_Arg (Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "0000000 000101")
         and then Contains (Test_Contexts.Output (Context), "0000001"),
         "od emits octal byte dump");

      Context.Initialize ("od", Two_Args ("-An", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = " 000101" & EOL,
         "od -An suppresses address output");

      Context.Initialize ("od", Two_Args ("-Ax", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 000101" & EOL & "0000001" & EOL,
         "od -Ax emits hexadecimal address output");

      Context.Initialize ("od", Three_Args ("-A", "d", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0 000101" & EOL & "1" & EOL,
         "od accepts a separate decimal address-base argument");

      Context.Initialize ("od", One_Arg ("-A"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-A'"),
         "od rejects a missing address-base argument");

      Context.Initialize ("od", Two_Args ("-A", "bad"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects an invalid address base");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Five_Args ("-j", "2", "-N", "3", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000002 042103 000105" & EOL & "0000005" & EOL,
         "od skips and limits input bytes");

      Context.Initialize ("od", Three_Args ("-j0x2", "-N03", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000002 042103 000105" & EOL & "0000005" & EOL,
         "od accepts attached hexadecimal skip and octal count");

      Context.Initialize ("od", Three_Args ("-N", "0", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000" & EOL,
         "od accepts a zero byte limit");

      Write_File (Od_File, String'(1 .. 512 => 'x') & "AB");
      Context.Initialize ("od", Two_Args ("-j1b", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0001000 041101" & EOL & "0001002" & EOL,
         "od supports block suffix skip arguments");

      Context.Initialize ("od", Two_Args ("-j1k", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "od rejects skips beyond input");

      Context.Initialize ("od", One_Arg ("-j"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-j'"),
         "od rejects a missing skip argument");

      Context.Initialize ("od", Two_Args ("-N", "0x"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects malformed count arguments");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Two_Args ("-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 41 42 43 44 45 46" & EOL & "0000006" & EOL,
         "od supports attached hexadecimal byte type strings");

      Write_File (Od_File, String'(1 .. 32 => 'A'));
      Context.Initialize ("od", Two_Args ("-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "0000000 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "*" & EOL
           & "0000040" & EOL,
         "od suppresses duplicate output blocks by default");

      Context.Initialize ("od", Three_Args ("-v", "-tx1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) =
           "0000000 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "0000020 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41 41" & EOL
           & "0000040" & EOL,
         "od -v emits duplicate output blocks");

      Write_File (Od_File, "ABCDEF");
      Context.Initialize ("od", Three_Args ("-t", "u1", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 65 66 67 68 69 70" & EOL & "0000006" & EOL,
         "od supports separate unsigned byte type strings");

      Context.Initialize ("od", Two_Args ("-tx2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 4241 4443 4645" & EOL & "0000006" & EOL,
         "od supports two-byte hexadecimal type strings");

      Context.Initialize ("od", Two_Args ("-td2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 16961 17475 17989" & EOL & "0000006" & EOL,
         "od supports two-byte decimal type strings");

      Write_File (Od_File, Character'Val (255) & Character'Val (255));
      Context.Initialize ("od", Two_Args ("-td2", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 -1" & EOL & "0000002" & EOL,
         "od supports signed multi-byte type strings");

      Context.Initialize ("od", Two_Args ("-s", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 -1" & EOL & "0000002" & EOL,
         "od supports signed decimal shorthand");

      Context.Initialize ("od", Two_Args ("-d", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 65535" & EOL & "0000002" & EOL,
         "od supports unsigned decimal shorthand");

      Write_File (Od_File, Character'Val (0) & Character'Val (0) & Character'Val (128) & Character'Val (63));
      Context.Initialize ("od", Two_Args ("-tf4", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000  1.00000E+00" & EOL & "0000004" & EOL,
         "od supports single-precision floating type strings");

      Write_File
        (Od_File,
         Character'Val (0) & Character'Val (0) & Character'Val (0) & Character'Val (0)
         & Character'Val (0) & Character'Val (0) & Character'Val (240) & Character'Val (63));
      Context.Initialize ("od", Two_Args ("-tfD", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000  1.00000000000000E+00" & EOL & "0000010" & EOL,
         "od supports double-precision floating type strings");

      Write_File (Od_File, "A" & Character'Val (10) & Character'Val (0));
      Context.Initialize ("od", Two_Args ("-tc", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000   A  \\n  \\0" & EOL & "0000003" & EOL,
         "od supports character byte type strings");

      Context.Initialize ("od", Two_Args ("-ta", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000   A  nl nul" & EOL & "0000003" & EOL,
         "od supports named character type strings");

      Write_File (Od_File, "AB");
      Context.Initialize ("od", Five_Args ("-t", "x1", "-t", "c", Od_File));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "0000000 41 42" & EOL & "   A   B" & EOL & "0000002" & EOL,
         "od supports multiple type-string output lines");

      Context.Initialize ("od", Two_Args ("-t", "f1"));
      Posix_Tools.Commands.Od.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "od rejects unsupported type strings");

      Context.Initialize ("ls", One_Arg (Od_File));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Od_File & EOL,
         "ls prints file operands");

      Ada.Directories.Create_Directory (Ls_Dir);
      Write_File (Hostkit.Fs.Join (Ls_Dir, "visible"), "visible" & EOL);
      Write_File (Hostkit.Fs.Join (Ls_Dir, ".hidden"), "hidden" & EOL);
      Context.Initialize ("ls", One_Arg (Ls_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "visible" & EOL,
         "ls hides dot-prefixed entries by default");

      Context.Initialize ("ls", Two_Args ("-A", Ls_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ".hidden" & EOL & "visible" & EOL,
         "ls -A includes hidden entries other than dot and dot-dot");

      Ada.Directories.Create_Directory (Ls_Other_Dir);
      Write_File (Hostkit.Fs.Join (Ls_Other_Dir, "zeta"), "zeta" & EOL);
      Context.Initialize ("ls", Two_Args (Ls_Dir, Ls_Other_Dir));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = Ls_Dir & ":" & EOL
           & "visible" & EOL & EOL
           & Ls_Other_Dir & ":" & EOL
           & "zeta" & EOL,
         "ls labels multiple directory operands");

      Write_File (Split_Input, "a" & EOL & "b" & EOL & "c" & EOL);
      Context.Initialize ("split", Four_Args ("-l", "2", Split_Input, Split_Prefix));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "split status");
      Context.Initialize ("cat", One_Arg (Split_Prefix & "aa"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL & "b" & EOL, "split first file");
      Context.Initialize ("cat", One_Arg (Split_Prefix & "ab"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "c" & EOL, "split second file");

      Context.Initialize ("split", Six_Args ("-a", "3", "-l", "1", Split_Input, Split_Long_Prefix));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "split -a status");
      Context.Initialize ("cat", One_Arg (Split_Long_Prefix & "aaa"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "a" & EOL, "split -a first file");
      Context.Initialize ("cat", One_Arg (Split_Long_Prefix & "aac"));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "c" & EOL, "split -a third file");

      Context.Initialize ("split", One_Arg ("-a"));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Contains (Test_Contexts.Error_Output (Context), "missing option argument '-a'"),
         "split rejects a missing suffix length");

      Context.Initialize ("split", Two_Args ("-a", "0"));
      Posix_Tools.Commands.Split.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "split rejects a zero suffix length");

      Remove_Any (Source);
      Remove_Any (Target);
      Remove_Any (Large_Source);
      Remove_Any (Large_Target);
      Remove_Any (Dash_Target);
      Remove_Any (Linked);
      Remove_Any (Link_Command_Target);
      Remove_Any (Symlinked);
      Remove_Any (Cp_Symlinked);
      Remove_Any (Link_Dir);
      Remove_Any (Moved);
      Remove_Any (Made);
      Remove_Any (Symbolic_Mode_Dir);
      Remove_Any (Relative_Mode_Dir);
      Remove_Any (Remove_Dir);
      Remove_Any (Multi);
      Remove_Any (Other);
      Remove_Any (Tree);
      Remove_Any (Tree_Copy);
      Remove_Any (Sort_Out);
      Remove_Any (Empty);
      Remove_Any (Cp_Directory_Source);
      Remove_Any (Cp_Directory_Target);
      Remove_Any (Cp_FIFO_Source);
      Remove_Any (Cp_FIFO_Target);
      Remove_Any (Cp_Socket_Source);
      Remove_Any (Cp_Socket_Target);
      Remove_Any (Parent_Block);
      Remove_Any (Option_Dir);
      Remove_Any (Touched);
      Remove_Any (No_Create);
      Remove_Any (Tee_Out);
      Remove_Any (Chmod_Target);
      Remove_Any (Cksum_File);
      Remove_Any (Cmp_First);
      Remove_Any (Cmp_Second);
      Remove_Any (Paste_First);
      Remove_Any (Paste_Second);
      Remove_Any (Cut_File);
      Remove_Any (Comm_First);
      Remove_Any (Comm_Second);
      Remove_Any (Od_File);
      Remove_Any (Ls_Dir);
      Remove_Any (Ls_Other_Dir);
      Remove_Any (Split_Input);
      Remove_Any (Split_Prefix & "aa");
      Remove_Any (Split_Prefix & "ab");
      Remove_Any (Split_Long_Prefix & "aaa");
      Remove_Any (Split_Long_Prefix & "aab");
      Remove_Any (Split_Long_Prefix & "aac");
      Ada.Directories.Create_Path (Option_Dir);
      Write_File (Hostkit.Fs.Join (Option_Dir, "-c"), "x" & EOL);
      Write_File (Hostkit.Fs.Join (Option_Dir, "plain"), "x" & EOL);
   end Test_Expanded_Command_Smoke;

   procedure Test_Xargs_Status_Bands (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("xargs", One_Arg ("false"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Code (123),
         "xargs maps utility status 1 through 125 to 123");

      Context.Initialize ("xargs", One_Arg ("xargs-status-255"));
      Test_Contexts.Set_Standard_Input (Context, "a");
      Posix_Tools.Commands.Xargs.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Code (124),
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

      Write_File (Text_Path, "hello" & LF);
      Write_File (Data_Path, "a" & Character'Val (0) & "b");
      Write_File (Empty_Path, "");
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
   end Test_File;

   procedure Test_Du (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Small_Path   : constant String := Fixture_Path ("du-small.bin");
      Large_Path   : constant String := Fixture_Path ("du-large.bin");
      Dir_Path     : constant String := Fixture_Path ("du-dir");
      Child_Path   : constant String := Fixture_Path ("du-dir/child.bin");
      Missing_Path : constant String := Fixture_Path ("du-missing.bin");
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
      Delete_If_Exists (Small_Path);
      Delete_If_Exists (Large_Path);
      Delete_If_Exists (Dir_Path);

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

      Delete_If_Exists (Small_Path);
      Delete_If_Exists (Large_Path);
      Delete_If_Exists (Dir_Path);
   end Test_Du;

   procedure Test_Fold (T : in out Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("fold-input.txt");
      Missing : constant String := Fixture_Path ("fold-missing.txt");
      LF      : constant Character := Character'Val (10);

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

      Delete_If_Exists (Path);
      Write_File (Path, "x" & HT & "y");
      Context.Initialize ("expand", Two_Args ("-t4", Path));
      Posix_Tools.Commands.Expand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "x   y",
         "expand reads file operands");

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

      Delete_If_Exists (Path);
      Write_File (Path, "    x" & LF & "  y");
      Context.Initialize ("unexpand", Two_Args ("-t4", Path));
      Posix_Tools.Commands.Unexpand.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = HT & "x" & LF & "  y",
         "unexpand reads file operands and honors tab width");

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

   procedure Test_Expanded_Verbose_Output_Failures (T : in out Fixture) is
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
   end Test_Expanded_Verbose_Output_Failures;

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

      Context.Initialize ("wc", One_Arg ("-L"));
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "wc -L unsupported output");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "wc: unknown option '-L'" & LF,
         "wc -L unsupported diagnostic");
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "wc -L unsupported status");
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
end Command_Tests;
