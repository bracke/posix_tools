with Ada.Streams;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Hostkit.Fs;
with Hostkit.Metadata;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Chmod;
with Posix_Tools.Commands.Cp;
with Posix_Tools.Commands.Ln;
with Posix_Tools.Commands.Ls;
with Posix_Tools.Commands.Mkdir;
with Posix_Tools.Commands.Mv;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rm;
with Posix_Tools.Commands.Wc;
with Posix_Tools.Exit_Status;
with Posix_Tools.File_Operations.Moving;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Streams.Counting;
with Posix_Tools.Text.Escaping;
with Posix_Tools.Text.Glob;
with Posix_Tools.Text.UTF_8;
with Project_Tools.Files;
with Test_Contexts;

package body File_Command_Tests is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Ops renames Posix_Tools.File_Operations;

   use type FS.File_Kind;
   use type Hostkit.Metadata.Identity_Field;
   use type Ops.Operation_Error;
   use type Ops.Operation_Outcome;
   use type Posix_Tools.Exit_Status.Code;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   EOL : constant Character := Character'Val (10);

   Success : constant Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   Failure : constant Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Operational_Failure;

   --  Counts what an operation reports, and remembers the last error.
   type Recorder is new Ops.Observer with record
      Errors     : Natural := 0;
      Last_Error : Ops.Operation_Error := Ops.Cannot_Open;
   end record;

   overriding procedure Report_Error (Self : in out Recorder; Path : String; Error : Ops.Operation_Error);

   function Args (A : String; B, C, D : String := "") return Posix_Tools.Arguments.Vector;

   --  Root made empty, for one test's files.
   procedure Fresh (Root : String);

   function Mode (Name : String) return Natural;

   function Path (Root, Name : String) return String is (Project_Tools.Files.Join (Root, Name));

   function Read (Name : String) return String;

   procedure Remove (Root : String);

   function Root_For (Name : String) return String is
     (Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-files-" & Name));

   --  Where a host runs only programs with a suffix (Windows), execute bits
   --  follow the name, not chmod.
   function Execute_Bits_Kept return Boolean is (Hostkit.Fs.Executable_Suffix = "");

   procedure Write (Name, Text : String);

   function Args (A : String; B, C, D : String := "") return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);
      for Item of Posix_Tools.Arguments.Vector'([B, C, D]) loop
         if Item /= "" then
            Result.Append (Item);
         end if;
      end loop;

      return Result;
   end Args;

   procedure Fresh (Root : String) is
   begin
      Remove (Root);
      FS.Create_Path (Root);
   end Fresh;

   function Mode (Name : String) return Natural is
      Known : Boolean;
      Bits  : constant Natural := FS.File_Permission_Bits (Name, Known);
   begin
      return (if Known then Bits mod 8#10000# else Natural'Last);
   end Mode;

   function Read (Name : String) return String is
      Text : Ada.Strings.Unbounded.Unbounded_String;

      procedure Take
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      procedure Take
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
         pragma Unreferenced (Stop);
      begin
         for I in Buffer'First .. Last loop
            Ada.Strings.Unbounded.Append (Text, Character'Val (Buffer (I)));
         end loop;
      end Take;

      procedure Each is new FS.For_Each_File_Chunk (Take);
      Ok : Boolean;
   begin
      Each (Name, Ok);
      return (if Ok then Ada.Strings.Unbounded.To_String (Text) else "<unreadable>");
   end Read;

   procedure Remove (Root : String) is
      Watcher : Recorder;
      Outcome : Ops.Operation_Outcome;
   begin
      if FS.Exists (Root) or else FS.Is_Link (Root) then
         Ops.Removing.Remove_Path (Root, (Recursive => True, others => <>), Watcher, Outcome);
      end if;
   end Remove;

   overriding procedure Report_Error (Self : in out Recorder; Path : String; Error : Ops.Operation_Error) is
      pragma Unreferenced (Path);
   begin
      Self.Errors := Self.Errors + 1;
      Self.Last_Error := Error;
   end Report_Error;

   procedure Test_Chmod_Symbolic_Grammar (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("chmod");
      File    : constant String := Path (Root, "f");
      Dir     : constant String := Path (Root, "d");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      procedure Check (Start : Natural; Mode_Text, Name : String; Expected : Natural; Message : String);

      procedure Check (Start : Natural; Mode_Text, Name : String; Expected : Natural; Message : String) is
      begin
         AUnit.Assertions.Assert (FS.Set_Permissions (Name, Start), "fixture mode for " & Message);
         Context.Initialize ("chmod", Args (Mode_Text, Name));
         Posix_Tools.Commands.Chmod.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Success and then Mode (Name) mod 8#10000# = Expected, Message);
      end Check;
   begin
      if not FS.Permissions_Supported then
         return;
      end if;

      Fresh (Root);
      Write (File, "mode");
      FS.Create_Directory (Dir);

      Check (8#644#, "a=r,u+w", File, 8#644#, "chmod applies comma-separated clauses in turn");
      if Execute_Bits_Kept then
         Check (8#644#, "u+x-w", File, 8#544#, "chmod applies each action of a clause in turn");
         Check (8#600#, "g=u-w", File, 8#640#, "chmod copies a class and then takes from it");
         Check (8#644#, "a+X", File, 8#644#, "chmod X gives no execute to a file that has none");
         Check (8#744#, "go+X", File, 8#755#, "chmod X gives execute to a file that has some");
         Check (8#700#, "go+X", Dir, 8#711#, "chmod X gives search to a directory");
      end if;

      Context.Initialize ("chmod", Args ("u+q", File));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "chmod rejects an unknown perm in a later action");

      Context.Initialize ("chmod", Args ("u+r,", File));
      Posix_Tools.Commands.Chmod.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage, "chmod rejects a clause list ending in a comma");
      Remove (Root);
   end Test_Chmod_Symbolic_Grammar;

   procedure Test_Cp_Force_Replaces_Unwritable (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cp-force");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      if not FS.Permissions_Supported then
         return;
      end if;

      Fresh (Root);
      Write (Path (Root, "s"), "new");
      Write (Path (Root, "t"), "old");
      AUnit.Assertions.Assert (FS.Set_Permissions (Path (Root, "t"), 8#444#), "fixture read-only target");

      Context.Initialize ("cp", Args ("-f", Path (Root, "s"), Path (Root, "t")));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then Test_Contexts.Error_Output (Context) = ""
         and then Read (Path (Root, "t")) = "new",
         "cp -f removes a target it cannot write and copies afresh");
      Remove (Root);
   end Test_Cp_Force_Replaces_Unwritable;

   procedure Test_Cp_Interactive_Inside_Tree (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cp-interactive");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      FS.Create_Path (Path (Root, "src"));
      FS.Create_Path (Path (Root, "dst/src"));
      Write (Path (Root, "src/a"), "new-a");
      Write (Path (Root, "src/b"), "new-b");
      Write (Path (Root, "dst/src/a"), "old-a");

      Context.Initialize ("cp", Args ("-Ri", Path (Root, "src"), Path (Root, "dst")));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success
         and then Test_Contexts.Error_Output (Context) = "cp: overwrite '" & Path (Root, "dst/src/a") & "'?" & EOL,
         "cp -Ri asks about each existing file in the tree, and not about a directory it merges into");
      AUnit.Assertions.Assert
        (Read (Path (Root, "dst/src/a")) = "old-a" and then Read (Path (Root, "dst/src/b")) = "new-b",
         "cp -Ri keeps a declined file and copies the rest");
      Remove (Root);
   end Test_Cp_Interactive_Inside_Tree;

   procedure Test_Cp_Into_Itself_Through_Link (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cp-self");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      FS.Create_Path (Path (Root, "a"));
      Write (Path (Root, "a/f"), "f");
      if not FS.Create_Link ("a", Path (Root, "la")) then
         Remove (Root);
         return;
      end if;

      Context.Initialize ("cp", Args ("-R", Path (Root, "a"), Path (Root, "la") & "/sub"));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) =
           "cp: '" & Path (Root, "la") & "/sub': source and destination are the same file" & EOL
         and then not FS.Exists (Path (Root, "a/sub")),
         "cp -R refuses to copy a directory into itself through a link to it");
      Remove (Root);
   end Test_Cp_Into_Itself_Through_Link;

   procedure Test_Cp_Leaves_Source_Alone (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cp-source");
      Source  : constant String := Path (Root, "s");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      Write (Source, "source");

      declare
         Before : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Source);
      begin
         Context.Initialize ("cp", Args (Source, Path (Root, "t")));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Success, "cp copies");
         Context.Initialize ("cp", Args ("-p", Source, Path (Root, "u")));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Success, "cp -p copies");

         declare
            After : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Source);
         begin
            if Before.Available and then After.Available then
               --  Setting a file's times changes its status-change time.
               AUnit.Assertions.Assert
                 (Before.Changed_Seconds = After.Changed_Seconds
                  and then Before.Changed_Nanoseconds = After.Changed_Nanoseconds,
                  "cp sets no times on its source");
            end if;
         end;
      end;
      Remove (Root);
   end Test_Cp_Leaves_Source_Alone;

   procedure Test_Cp_Link_Loop (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cp-loop");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      FS.Create_Path (Path (Root, "src/sub"));
      Write (Path (Root, "src/sub/file"), "x");
      if not FS.Create_Link ("..", Path (Root, "src/sub/loop")) then
         Remove (Root);
         return;
      end if;

      Context.Initialize ("cp", Args ("-RL", Path (Root, "src"), Path (Root, "dst")));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) =
           "cp: '" & Path (Root, "src/sub/loop") & "': file system loop detected" & EOL,
         "cp -RL reports a link back to a directory being copied, once");
      AUnit.Assertions.Assert
        (Read (Path (Root, "dst/sub/file")) = "x" and then not FS.Exists (Path (Root, "dst/sub/loop")),
         "cp -RL copies the rest of the tree and leaves the loop out");

      Context.Initialize ("cp", Args ("-R", Path (Root, "src"), Path (Root, "kept")));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then FS.Is_Link (Path (Root, "kept/sub/loop")),
         "cp -R copies the link as a link");
      Remove (Root);
   end Test_Cp_Link_Loop;

   procedure Test_Cp_Link_Options (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cp-links");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;

      procedure Copy (Options, Name : String);

      procedure Copy (Options, Name : String) is
      begin
         Context.Initialize ("cp", Args (Options, Path (Root, "operand"), Path (Root, Name)));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert (Result.Status = Success, "cp " & Options & " status");
      end Copy;
   begin
      Fresh (Root);
      FS.Create_Path (Path (Root, "real"));
      Write (Path (Root, "real/x"), "x");
      if not FS.Create_Link ("x", Path (Root, "real/y")) or else not FS.Create_Link ("real", Path (Root, "operand"))
      then
         Remove (Root);
         return;
      end if;

      Copy ("-RH", "h");
      AUnit.Assertions.Assert
        (not FS.Is_Link (Path (Root, "h")) and then FS.Kind (Path (Root, "h")) = FS.Directory
         and then FS.Is_Link (Path (Root, "h/y")),
         "cp -RH follows a link operand and copies the links inside as links");

      Copy ("-RL", "l");
      AUnit.Assertions.Assert
        (not FS.Is_Link (Path (Root, "l")) and then not FS.Is_Link (Path (Root, "l/y"))
         and then Read (Path (Root, "l/y")) = "x",
         "cp -RL follows every link");

      Copy ("-RP", "p");
      AUnit.Assertions.Assert (FS.Is_Link (Path (Root, "p")), "cp -RP copies a link operand as a link");

      Copy ("-R", "d");
      AUnit.Assertions.Assert (FS.Is_Link (Path (Root, "d")), "cp -R keeps links as links, as -P does");

      Context.Initialize ("cp", Args (Path (Root, "real/y"), Path (Root, "plain")));
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then not FS.Is_Link (Path (Root, "plain"))
         and then Read (Path (Root, "plain")) = "x",
         "cp without -R copies what a link operand points to");
      Remove (Root);
   end Test_Cp_Link_Options;

   procedure Test_Cp_Preserves_Mode_Bits (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cp-mode");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Own_User, Own_Group : Natural;
      Own_Known           : Boolean;

      --  A file someone else owns, if the host has one where it is usual.
      function Foreign (Candidates : Posix_Tools.Arguments.Vector; Set_Id : Boolean) return String;

      function Foreign (Candidates : Posix_Tools.Arguments.Vector; Set_Id : Boolean) return String is
      begin
         for Name of Candidates loop
            declare
               User, Group : Natural;
               Known       : Boolean;
            begin
               if FS.Exists (Name) and then FS.Kind (Name) = FS.Ordinary_File then
                  FS.File_Ownership (Name, User, Group, Known);
                  if Known and then Own_Known and then User /= Own_User
                    and then (not Set_Id or else (Mode (Name) / 8#4000#) mod 2 = 1)
                  then
                     return Name;
                  end if;
               end if;
            end;
         end loop;

         return "";
      end Foreign;
   begin
      if not FS.Permissions_Supported then
         return;
      end if;

      Fresh (Root);
      Write (Path (Root, "s"), "s");
      FS.File_Ownership (Path (Root, "s"), Own_User, Own_Group, Own_Known);

      if FS.Set_Permissions (Path (Root, "s"), 8#6755#) and then Mode (Path (Root, "s")) = 8#6755# then
         Context.Initialize ("cp", Args ("-p", Path (Root, "s"), Path (Root, "t")));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Success and then Mode (Path (Root, "t")) = 8#6755#,
            "cp -p keeps the set-user-ID and set-group-ID bits of a file it can give its owner");
      end if;

      if FS.Set_Permissions (Path (Root, "s"), 8#1755#) and then Mode (Path (Root, "s")) = 8#1755# then
         Context.Initialize ("cp", Args ("-p", Path (Root, "s"), Path (Root, "k")));
         Posix_Tools.Commands.Cp.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Success and then Mode (Path (Root, "k")) = 8#1755#, "cp -p keeps the sticky bit");
      end if;

      declare
         Other : constant String := Foreign (Args ("/etc/hosts", "/etc/passwd"), Set_Id => False);
      begin
         if Other /= "" then
            Context.Initialize ("cp", Args ("-p", Other, Path (Root, "h")));
            Posix_Tools.Commands.Cp.Run (Context, Result);
            AUnit.Assertions.Assert
              (Result.Status = Success and then Test_Contexts.Error_Output (Context) = ""
               and then Read (Path (Root, "h")) = Read (Other),
               "cp -p copies a file whose owner it cannot keep, and says nothing of it");
         end if;
      end;

      declare
         Other : constant String :=
           Foreign (Args ("/usr/bin/passwd", "/usr/bin/su", "/bin/su", "/usr/bin/sudo"), Set_Id => True);
      begin
         if Other /= "" then
            Context.Initialize ("cp", Args ("-p", Other, Path (Root, "x")));
            Posix_Tools.Commands.Cp.Run (Context, Result);
            AUnit.Assertions.Assert
              (Result.Status = Success
               and then (Mode (Path (Root, "x")) / 8#2000#) mod 4 = 0
               and then Mode (Path (Root, "x")) mod 8#1000# = Mode (Other) mod 8#1000#,
               "cp -p drops the set-ID bits of a copy that cannot keep its owner, and keeps the rest");
         end if;
      end;
      Remove (Root);
   end Test_Cp_Preserves_Mode_Bits;

   procedure Test_Glob_Brackets (T : in out Fixture) is
      pragma Unreferenced (T);

      procedure Check (Pattern, Text : String; Expected : Boolean);

      procedure Check (Pattern, Text : String; Expected : Boolean) is
      begin
         AUnit.Assertions.Assert
           (Posix_Tools.Text.Glob.Matches (Pattern, Text) = Expected,
            "glob '" & Pattern & "' against '" & Text & "' should be " & Boolean'Image (Expected));
      end Check;
   begin
      Check ("[[:alpha:]]", "a", True);
      Check ("[[:alpha:]]", "1", False);
      Check ("[[:digit:]x]", "x", True);
      Check ("[[:digit:]x]", "7", True);
      Check ("[![:space:]]", " ", False);
      Check ("[![:space:]]", "b", True);
      Check ("[[:upper:][:lower:]]", "Q", True);
      Check ("[[:xdigit:]]", "f", True);
      Check ("[[:xdigit:]]", "g", False);
      Check ("[[:punct:]]", "!", True);
      Check ("[[:nonesuch:]]", "a", False);
      Check ("[[.a.]-c]", "b", True);
      Check ("[[.a.]-c]", "d", False);
      Check ("[[=b=]]", "b", True);
      Check ("[[.].]]", "]", True);
      Check ("file[!]", "file[!]", True);
      Check ("file[!]", "filex", False);
      Check ("[]", "[]", True);
      Check ("[]", "a", False);
      Check ("[]a]", "]", True);
      Check ("[!]a]", "b", True);
      Check ("[!]a]", "]", False);
      Check ("[a-c]x", "bx", True);
      Check ("[a-]", "-", True);
      Check ("*.[ch]", "main.c", True);
   end Test_Glob_Brackets;

   procedure Test_Ln_Same_File (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("ln");
      A       : constant String := Path (Root, "a");
      B       : constant String := Path (Root, "b");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      Write (A, "data");

      Context.Initialize ("ln", Args ("-f", A, A));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) =
           "ln: '" & A & "': source and destination are the same file" & EOL
         and then Read (A) = "data",
         "ln -f a a refuses, and keeps a");

      Context.Initialize ("ln", Args ("-sf", "a", A));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure and then not FS.Is_Link (A) and then Read (A) = "data",
         "ln -sf a a refuses, and keeps a");

      Context.Initialize ("ln", Args (A, B));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Success, "ln makes a hard link");

      Context.Initialize ("ln", Args (A, B));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure and then Test_Contexts.Error_Output (Context) = "ln: '" & B & "': file exists" & EOL,
         "ln says a target exists");

      Context.Initialize ("ln", Args ("-f", A, B));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then Read (B) = "data",
         "ln -f replaces another hard link to its source");

      Context.Initialize ("ln", Args (Path (Root, "missing"), Path (Root, "c")));
      Posix_Tools.Commands.Ln.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) =
           "ln: '" & Path (Root, "missing") & "': no such file or directory" & EOL,
         "ln says a source is missing");
      Remove (Root);
   end Test_Ln_Same_File;

   procedure Test_Ls_Operands (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("ls");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      Write (Path (Root, "zfile"), "z");
      FS.Create_Path (Path (Root, "adir"));
      Write (Path (Root, "adir/x"), "x");
      if not FS.Create_Link ("nowhere", Path (Root, "dangling")) then
         Remove (Root);
         return;
      end if;

      Context.Initialize ("ls", Args (Path (Root, "dangling")));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then Test_Contexts.Output (Context) = Path (Root, "dangling") & EOL,
         "ls lists a link to nothing");

      Context.Initialize ("ls", Args (Path (Root, "adir"), Path (Root, "zfile"), Path (Root, "dangling")));
      Posix_Tools.Commands.Ls.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success
         and then Test_Contexts.Output (Context) =
           Path (Root, "dangling") & EOL & Path (Root, "zfile") & EOL & EOL & Path (Root, "adir") & ":" & EOL
           & "x" & EOL,
         "ls lists the operands that are not directories first, sorted, and then the directories");
      Remove (Root);
   end Test_Ls_Operands;

   procedure Test_Mkdir_Mode_And_Diagnostics (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("mkdir");
      Made    : constant String := Path (Root, "m");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);

      Context.Initialize ("mkdir", Args ("-m", "g-w", Made));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Success and then FS.Exists (Made), "mkdir -m g-w status");
      --  A mode rendered from an ACL, as on Windows, has no group bits apart.
      if FS.Permissions_Supported and then Hostkit.Metadata.Mode_Bits_Are_Native then
         AUnit.Assertions.Assert
           (Mode (Made) mod 8#1000# = 8#757#, "mkdir -m takes + and - from a=rwx, whatever the umask");
      end if;

      Context.Initialize ("mkdir", Args (Made));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) = "mkdir: '" & Made & "': file exists" & EOL,
         "mkdir says a directory exists");

      Context.Initialize ("mkdir", Args (Path (Root, "no/sub")));
      Posix_Tools.Commands.Mkdir.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) =
           "mkdir: '" & Path (Root, "no/sub") & "': no such file or directory" & EOL,
         "mkdir says a parent is missing");
      Remove (Root);
   end Test_Mkdir_Mode_And_Diagnostics;

   procedure Test_Move_By_Copying (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("move-copy");
      Watcher : Recorder;
      Outcome : Ops.Operation_Outcome;

      procedure Move (Source, Target : String);

      procedure Move (Source, Target : String) is
      begin
         Watcher.Errors := 0;
         Watcher.Last_Error := Ops.Cannot_Open;
         Ops.Moving.Move_By_Copying (Path (Root, Source), Path (Root, Target), Watcher, Outcome);
      end Move;
   begin
      Fresh (Root);

      --  A link as the target is replaced, not written through.
      Write (Path (Root, "real"), "real");
      Write (Path (Root, "s1"), "new-1");
      if FS.Create_Link ("real", Path (Root, "link")) then
         Move ("s1", "link");
         AUnit.Assertions.Assert
           (Outcome = Ops.Done and then not FS.Is_Link (Path (Root, "link"))
            and then Read (Path (Root, "link")) = "new-1" and then Read (Path (Root, "real")) = "real"
            and then not FS.Exists (Path (Root, "s1")),
            "a move by copying replaces a link at the target, and leaves what it pointed to");
      end if;

      --  Another name of the target keeps the old file.
      Write (Path (Root, "h1"), "old");
      Write (Path (Root, "s2"), "new-2");
      if FS.Create_Hard_Link (Path (Root, "h1"), Path (Root, "h2")) then
         Move ("s2", "h1");
         AUnit.Assertions.Assert
           (Outcome = Ops.Done and then Read (Path (Root, "h1")) = "new-2" and then Read (Path (Root, "h2")) = "old",
            "a move by copying makes a new file, not one written into another name of the old");
      end if;

      --  A target that cannot be written is replaced all the same.
      Write (Path (Root, "ro"), "old");
      Write (Path (Root, "s3"), "new-3");
      if FS.Set_Permissions (Path (Root, "ro"), 8#444#) then
         Move ("s3", "ro");
         AUnit.Assertions.Assert
           (Outcome = Ops.Done and then Read (Path (Root, "ro")) = "new-3",
            "a move by copying replaces a read-only target, as a rename would");
      end if;

      --  A directory onto one that is not empty fails, merging nothing.
      FS.Create_Path (Path (Root, "dir/inner"));
      Write (Path (Root, "dir/inner/f"), "f");
      FS.Create_Path (Path (Root, "full"));
      Write (Path (Root, "full/keep"), "keep");
      Move ("dir", "full");
      AUnit.Assertions.Assert
        (Outcome = Ops.Failed and then Watcher.Last_Error = Ops.Directory_Not_Empty
         and then not FS.Exists (Path (Root, "full/inner")) and then Read (Path (Root, "dir/inner/f")) = "f",
         "a move by copying does not merge a directory into one that is not empty");

      --  Onto an empty one it goes whole.
      FS.Create_Path (Path (Root, "empty"));
      Move ("dir", "empty");
      AUnit.Assertions.Assert
        (Outcome = Ops.Done and then Read (Path (Root, "empty/inner/f")) = "f"
         and then not FS.Exists (Path (Root, "dir")),
         "a move by copying replaces an empty directory");

      --  A file onto a directory, or a directory onto a file, fails.
      Write (Path (Root, "s4"), "s4");
      Move ("s4", "full");
      AUnit.Assertions.Assert
        (Outcome = Ops.Failed and then Watcher.Last_Error = Ops.Is_A_Directory and then FS.Exists (Path (Root, "s4")),
         "a move by copying does not put a file in place of a directory");
      Move ("empty", "s4");
      AUnit.Assertions.Assert
        (Outcome = Ops.Failed and then Watcher.Last_Error = Ops.Not_A_Directory
         and then Read (Path (Root, "s4")) = "s4",
         "a move by copying does not put a directory in place of a file");
      Remove (Root);
   end Test_Move_By_Copying;

   procedure Test_Mv_Diagnostics (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("mv");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);

      Context.Initialize ("mv", Args (Path (Root, "missing"), Path (Root, "x")));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) =
           "mv: '" & Path (Root, "missing") & "': no such file or directory" & EOL,
         "mv says a source is missing");

      FS.Create_Path (Path (Root, "s"));
      Write (Path (Root, "s/f"), "f");
      FS.Create_Path (Path (Root, "t/s"));
      Write (Path (Root, "t/s/keep"), "keep");
      Context.Initialize ("mv", Args (Path (Root, "s"), Path (Root, "t")));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) =
           "mv: '" & Path (Root, "t/s") & "': directory not empty" & EOL
         and then FS.Exists (Path (Root, "s/f")),
         "mv says a directory in the way is not empty");

      Write (Path (Root, "file"), "file");
      Context.Initialize ("mv", Args (Path (Root, "s"), Path (Root, "t"), Path (Root, "file")));
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) = "mv: '" & Path (Root, "file") & "': not a directory" & EOL,
         "mv says a last operand that is no directory is not one");
      Remove (Root);
   end Test_Mv_Diagnostics;

   procedure Test_Rm_Force_Reports_Failures (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("rm-force");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      FS.Create_Path (Path (Root, "dir"));
      Write (Path (Root, "dir/f"), "f");

      Context.Initialize ("rm", Args ("-f", Path (Root, "missing")));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then Test_Contexts.Error_Output (Context) = "",
         "rm -f says nothing of what is not there");

      Context.Initialize ("rm", Args ("-f", Path (Root, "dir")));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) = "rm: '" & Path (Root, "dir") & "': is a directory" & EOL,
         "rm -f still says why what is there could not be removed");

      Context.Initialize ("rm", Args (Path (Root, "missing")));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) =
           "rm: '" & Path (Root, "missing") & "': no such file or directory" & EOL,
         "rm says what is not there is not there");

      Context.Initialize ("rm", Args ("-d", Path (Root, "dir")));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) = "rm: '" & Path (Root, "dir") & "': directory not empty" & EOL,
         "rm -d says a directory is not empty");
      Remove (Root);
   end Test_Rm_Force_Reports_Failures;

   procedure Test_Rm_Interactive_Per_Entry (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("rm-interactive");
      Dir     : constant String := Path (Root, "d");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      FS.Create_Path (Dir);
      Write (Path (Root, "d/f"), "f");

      Context.Initialize ("rm", Args ("-ri", Dir));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL & "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success
         and then Test_Contexts.Error_Output (Context) =
           "rm: descend into directory '" & Dir & "'?" & EOL & "rm: remove '" & Path (Root, "d/f") & "'?" & EOL
         and then FS.Exists (Path (Root, "d/f")),
         "rm -ri asks about each entry, and keeps a directory whose entry was kept without asking about it");

      Context.Initialize ("rm", Args ("-ri", Dir));
      Test_Contexts.Set_Standard_Input (Context, "y" & EOL & "y" & EOL & "y" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success
         and then Test_Contexts.Error_Output (Context) =
           "rm: descend into directory '" & Dir & "'?" & EOL & "rm: remove '" & Path (Root, "d/f") & "'?" & EOL
           & "rm: remove directory '" & Dir & "'?" & EOL
         and then not FS.Exists (Dir),
         "rm -ri asks about the emptied directory last");

      FS.Create_Path (Dir);
      Context.Initialize ("rm", Args ("-ri", Dir));
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success
         and then Test_Contexts.Error_Output (Context) = "rm: remove directory '" & Dir & "'?" & EOL
         and then FS.Exists (Dir),
         "rm -ri asks only to remove an empty directory");
      Remove (Root);
   end Test_Rm_Interactive_Per_Entry;

   procedure Test_Rm_Mv_Prompts_Localized (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("prompts");
      A       : constant String := Path (Root, "a");
      B       : constant String := Path (Root, "b");
      Odd     : constant String := Path (Root, "new" & EOL & "line");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Odd_Made : Boolean;
   begin
      Fresh (Root);
      Write (A, "a");
      Write (B, "b");

      Context.Initialize ("rm", Args ("-i", A));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then Test_Contexts.Error_Output (Context) = "rm: fjern '" & A & "'?" & EOL,
         "rm -i asks in the locale's words");

      Context.Initialize ("mv", Args ("-i", A, B));
      Test_Contexts.Set_Locale (Context, "da");
      Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
      Posix_Tools.Commands.Mv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then Test_Contexts.Error_Output (Context) = "mv: overskriv '" & B & "'?" & EOL,
         "mv -i asks in the locale's words");

      --  A host that keeps control characters out of names, as Windows
      --  does, has no such name to show.
      FS.Write_File (Odd, "odd", False, Odd_Made);
      if Odd_Made then
         Context.Initialize ("rm", Args ("-i", Odd));
         Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
         Posix_Tools.Commands.Rm.Run (Context, Result);
         AUnit.Assertions.Assert
           (Posix_Tools.Text.Escaping.Escape_Untrusted (Odd) /= Odd
            and then Test_Contexts.Error_Output (Context) =
              "rm: remove '" & Posix_Tools.Text.Escaping.Escape_Untrusted (Odd) & "'?" & EOL,
            "rm -i shows a name with a control character escaped");

         Context.Initialize ("mv", Args ("-i", A, Odd));
         Test_Contexts.Set_Standard_Input (Context, "n" & EOL);
         Posix_Tools.Commands.Mv.Run (Context, Result);
         AUnit.Assertions.Assert
           (Test_Contexts.Error_Output (Context) =
              "mv: overwrite '" & Posix_Tools.Text.Escaping.Escape_Untrusted (Odd) & "'?" & EOL,
            "mv -i shows a name with a control character escaped");
      end if;

      Context.Initialize ("rm", Args ("-v", A));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Success and then Test_Contexts.Output (Context) = "removed '" & A & "'" & EOL,
         "rm -v says what it removed");
      Remove (Root);
   end Test_Rm_Mv_Prompts_Localized;

   procedure Test_Rm_Refuses_Dot_And_Root (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("rm-dot");
      Dir     : constant String := Path (Root, "d");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Fresh (Root);
      FS.Create_Path (Dir);
      Write (Path (Root, "d/f"), "f");

      Context.Initialize ("rm", Args ("-r", Dir & "/."));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) = "rm: '" & Dir & "/.': refusing to remove '.' or '..'" & EOL
         and then FS.Exists (Path (Root, "d/f")),
         "rm -r refuses an operand ending in . and removes nothing of it");

      Context.Initialize ("rm", Args ("-rf", Dir & "/../"));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure and then FS.Exists (Path (Root, "d/f")),
         "rm -rf refuses an operand ending in .. and removes nothing of it");

      --  Not -r: whatever this did, it could not remove a tree.
      Context.Initialize ("rm", Args ("/"));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure
         and then Test_Contexts.Error_Output (Context) = "rm: '/': refusing to remove the root directory" & EOL,
         "rm refuses the root directory");
      Remove (Root);
   end Test_Rm_Refuses_Dot_And_Root;

   procedure Test_UTF_8_Resynchronises (T : in out Fixture) is
      pragma Unreferenced (T);
      Decoder    : Posix_Tools.Text.UTF_8.Decoder;
      Status     : Posix_Tools.Text.UTF_8.Decode_Status;
      Code_Point : Long_Long_Integer;
      Consumed   : Boolean;
      State      : Posix_Tools.Streams.Counting.Counter;
      Context    : Test_Contexts.Capturing_Context;
      Result     : Posix_Tools.Commands.Results.Result;
      Broken     : constant String := Character'Val (16#C3#) & "A";
   begin
      Posix_Tools.Text.UTF_8.Decode (Decoder, 16#C3#, Status, Code_Point, Consumed);
      AUnit.Assertions.Assert
        (Status = Posix_Tools.Text.UTF_8.Need_More and then Consumed, "a lead byte waits for more");
      Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos ('A'), Status, Code_Point, Consumed);
      AUnit.Assertions.Assert
        (Status = Posix_Tools.Text.UTF_8.Invalid and then not Consumed,
         "a byte that cannot continue a sequence ends it without being taken");
      Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos ('A'), Status, Code_Point, Consumed);
      AUnit.Assertions.Assert
        (Status = Posix_Tools.Text.UTF_8.Complete and then Consumed and then Code_Point = Character'Pos ('A'),
         "and is then taken for what it is");

      Posix_Tools.Streams.Counting.Process (State, Broken);
      Posix_Tools.Streams.Counting.Finish_Text (State);
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Text_Invalid (State)
         and then Posix_Tools.Streams.Counting.Character_Count (State) = 1
         and then Posix_Tools.Streams.Counting.Word_Count (State) = 1,
         "counting keeps the character after an invalid sequence");

      Context.Initialize ("wc", Args ("-m"));
      Test_Contexts.Set_Standard_Input (Context, Broken);
      Posix_Tools.Commands.Wc.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Failure and then Test_Contexts.Output (Context) = "",
         "wc -m still refuses invalid UTF-8 without printing a partial count");
   end Test_UTF_8_Resynchronises;

   procedure Write (Name, Text : String) is
      Ok : Boolean;
   begin
      FS.Write_File (Name, Text, False, Ok);
      AUnit.Assertions.Assert (Ok, "fixture file " & Name);
   end Write;
end File_Command_Tests;
