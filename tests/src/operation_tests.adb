with Ada.Directories;
with Ada.Streams;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Cp;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rm;
with Posix_Tools.Exit_Status;
with Posix_Tools.File_Operations.Copying;
with Posix_Tools.File_Operations.Moving;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.File_System;
with Project_Tools.Files;
with Test_Contexts;

package body Operation_Tests is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Ops renames Posix_Tools.File_Operations;

   use type FS.File_Kind;
   use type Ops.Operation_Error;
   use type Posix_Tools.Exit_Status.Code;

   --  Remembers what an operation told it, and answers as it is set to.
   type Recorder is new Ops.Observer with record
      Errors       : Natural := 0;
      Last_Error   : Ops.Operation_Error := Ops.Cannot_Open;
      Last_Path    : Ada.Strings.Unbounded.Unbounded_String;
      Done         : Natural := 0;
      Progressed   : Natural := 0;
      Asked        : Natural := 0;
      Answer       : Ops.Conflict_Choice := Ops.Overwrite;
      --  Ask to stop once this many entries are done.
      Stop_After   : Natural := Natural'Last;
   end record;

   overriding procedure Report_Error (Self : in out Recorder; Path : String; Error : Ops.Operation_Error);
   overriding function Cancelled (Self : in out Recorder) return Boolean;
   overriding procedure Progress (Self : in out Recorder; Path : String; Copied : Long_Long_Integer);
   overriding procedure Finished (Self : in out Recorder; Path : String);
   overriding function Resolve_Conflict (Self : in out Recorder; Source, Target : String) return Ops.Conflict_Choice;

   function Args (A, B : String := "") return Posix_Tools.Arguments.Vector;

   --  Forget what was recorded, for the next operation.
   procedure Reset (Self : in out Recorder'Class; Stop_After : Natural := Natural'Last);

   --  A tree under Root: src with a file, a subdirectory with a file, a link
   --  to the file, a link to nothing, and a link to the directory outside,
   --  which holds a file of its own.
   procedure Make_Tree (Root : String);

   function Path (Root, Name : String) return String is (Project_Tools.Files.Join (Root, Name));

   function Read (Name : String) return String;

   procedure Remove (Root : String);

   function Root_For (Name : String) return String is
     (Project_Tools.Files.Join (Project_Tools.Files.Temp_Dir, "posix-tools-operation-" & Name));

   procedure Write (Name, Text : String);

   function Args (A, B : String := "") return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      Result.Append (A);

      if B /= "" then
         Result.Append (B);
      end if;

      return Result;
   end Args;

   overriding function Cancelled (Self : in out Recorder) return Boolean is (Self.Done >= Self.Stop_After);

   overriding procedure Finished (Self : in out Recorder; Path : String) is
      pragma Unreferenced (Path);
   begin
      Self.Done := Self.Done + 1;
   end Finished;

   procedure Make_Tree (Root : String) is
   begin
      Remove (Root);
      Ada.Directories.Create_Path (Path (Root, "src/sub"));
      Ada.Directories.Create_Path (Path (Root, "outside"));
      Write (Path (Root, "src/a"), "alpha");
      Write (Path (Root, "src/sub/b"), "beta");
      Write (Path (Root, "outside/keep"), "keep");

      AUnit.Assertions.Assert
        (FS.Create_Link ("a", Path (Root, "src/link"))
         and then FS.Create_Link ("nowhere", Path (Root, "src/broken"))
         and then FS.Create_Link ("../outside", Path (Root, "src/dirlink")),
         "fixture links");
   end Make_Tree;

   overriding procedure Progress (Self : in out Recorder; Path : String; Copied : Long_Long_Integer) is
      pragma Unreferenced (Path, Copied);
   begin
      Self.Progressed := Self.Progressed + 1;
   end Progress;

   function Read (Name : String) return String is
      Text : Ada.Strings.Unbounded.Unbounded_String;

      procedure Take (Buffer : Ada.Streams.Stream_Element_Array; Last : Ada.Streams.Stream_Element_Offset;
                      Stop   : in out Boolean);

      procedure Take (Buffer : Ada.Streams.Stream_Element_Array; Last : Ada.Streams.Stream_Element_Offset;
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
      Ok      : Boolean;
   begin
      if FS.Exists (Root) or else FS.Is_Link (Root) then
         Ops.Removing.Remove_Path (Root, (Recursive => True, others => <>), Watcher, Ok);
         AUnit.Assertions.Assert (Ok, "fixture removed: " & Root);
      end if;
   end Remove;

   procedure Reset (Self : in out Recorder'Class; Stop_After : Natural := Natural'Last) is
   begin
      Self.Errors := 0;
      Self.Done := 0;
      Self.Progressed := 0;
      Self.Asked := 0;
      Self.Answer := Ops.Overwrite;
      Self.Stop_After := Stop_After;
   end Reset;

   overriding procedure Report_Error (Self : in out Recorder; Path : String; Error : Ops.Operation_Error) is
   begin
      Self.Errors := Self.Errors + 1;
      Self.Last_Error := Error;
      Self.Last_Path := Ada.Strings.Unbounded.To_Unbounded_String (Path);
   end Report_Error;

   overriding function Resolve_Conflict
     (Self : in out Recorder; Source, Target : String) return Ops.Conflict_Choice
   is
      pragma Unreferenced (Source, Target);
   begin
      Self.Asked := Self.Asked + 1;
      return Self.Answer;
   end Resolve_Conflict;

   procedure Test_Copy_Cancel (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cancel");
      Watcher : Recorder := (Stop_After => 1, others => <>);
      Ok      : Boolean;
   begin
      Make_Tree (Root);

      --  Followed, the link to nothing is an error, and the host's listing
      --  order decides whether the copy reaches it before it is told to stop.
      AUnit.Assertions.Assert (FS.Delete_Link (Path (Root, "src/broken")), "the link to nothing removed");
      Ops.Copying.Copy_Path (Path (Root, "src"), Path (Root, "copy"), (Recursive => True, others => <>), Watcher, Ok);
      AUnit.Assertions.Assert (not Ok and then Watcher.Errors = 0, "a cancelled copy fails without an error");
      AUnit.Assertions.Assert (Watcher.Done = 1, "and stops after the entry it was told to");
      Remove (Root);
   end Test_Copy_Cancel;

   procedure Test_Copy_Conflicts (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("conflicts");
      Watcher : Recorder;
      Ok      : Boolean;
   begin
      Make_Tree (Root);
      Write (Path (Root, "existing"), "old");

      Watcher.Answer := Ops.Skip;
      Ops.Copying.Copy_Path (Path (Root, "src/a"), Path (Root, "existing"), (others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (Ok and then Watcher.Asked = 1 and then Read (Path (Root, "existing")) = "old",
         "a skipped conflict leaves the target alone");

      Watcher.Answer := Ops.Overwrite;
      Ops.Copying.Copy_Path (Path (Root, "src/a"), Path (Root, "existing"), (others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (Ok and then Watcher.Asked = 2 and then Read (Path (Root, "existing")) = "alpha",
         "an overwritten one is replaced");

      Ops.Copying.Copy_Path (Path (Root, "src/a"), Path (Root, "fresh"), (others => <>), Watcher, Ok);
      AUnit.Assertions.Assert (Ok and then Watcher.Asked = 2, "no question without a conflict");

      Ops.Copying.Copy_Path (Path (Root, "src/a"), Path (Root, "src/a"), (others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (not Ok and then Watcher.Last_Error = Ops.Same_File, "a file is not copied onto itself");
      Remove (Root);
   end Test_Copy_Conflicts;

   procedure Test_Copy_Tree (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("copy");
      Watcher : Recorder;
      Ok      : Boolean;
   begin
      Make_Tree (Root);

      Ops.Copying.Copy_Path
        (Path (Root, "src"), Path (Root, "kept"), (Recursive => True, Preserve_Links => True, others => <>),
         Watcher, Ok);
      AUnit.Assertions.Assert (Ok and then Watcher.Errors = 0, "a tree with links copies");
      AUnit.Assertions.Assert
        (Read (Path (Root, "kept/sub/b")) = "beta" and then FS.Is_Link (Path (Root, "kept/link"))
         and then FS.Is_Link (Path (Root, "kept/broken")) and then FS.Is_Link (Path (Root, "kept/dirlink")),
         "links are copied as links, those to nothing too");
      AUnit.Assertions.Assert (Watcher.Done = 7, "each entry and the tree are reported done");
      AUnit.Assertions.Assert (Watcher.Progressed >= 2, "file copies report progress");

      Reset (Watcher);
      Ops.Copying.Copy_Path (Path (Root, "src"), Path (Root, "followed"), (Recursive => True, others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (not Ok and then Watcher.Errors = 1 and then Watcher.Last_Error = Ops.Cannot_Read,
         "following links, a link to nothing cannot be read");
      AUnit.Assertions.Assert
        (not FS.Is_Link (Path (Root, "followed/link")) and then Read (Path (Root, "followed/link")) = "alpha"
         and then Read (Path (Root, "followed/dirlink/keep")) = "keep",
         "and the others are copied as what they point to");

      Reset (Watcher);
      Ops.Copying.Copy_Path (Path (Root, "src"), Path (Root, "flat"), (others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (not Ok and then Watcher.Last_Error = Ops.Is_A_Directory, "a directory needs a recursive copy");

      Reset (Watcher);
      Ops.Copying.Copy_Path
        (Path (Root, "src"), Path (Root, "src/sub/inside"), (Recursive => True, others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (not Ok and then Watcher.Last_Error = Ops.Same_File, "a tree is not copied into itself");
      Remove (Root);
   end Test_Copy_Tree;

   procedure Test_Cp_Keeps_Broken_Links (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("cp");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Three   : Posix_Tools.Arguments.Vector := Args ("-RP", Path (Root, "src"));
   begin
      Make_Tree (Root);
      Three.Append (Path (Root, "copy"));
      Context.Initialize ("cp", Three);
      Posix_Tools.Commands.Cp.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then FS.Is_Link (Path (Root, "copy/broken")),
         "cp -RP copies a link to nothing");
      Remove (Root);
   end Test_Cp_Keeps_Broken_Links;

   procedure Test_Move (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("move");
      Watcher : Recorder;
      Ok      : Boolean;
   begin
      Make_Tree (Root);
      Write (Path (Root, "existing"), "old");

      Watcher.Answer := Ops.Skip;
      Ops.Moving.Move_Path (Path (Root, "src/a"), Path (Root, "existing"), Watcher, Ok);
      AUnit.Assertions.Assert
        (Ok and then FS.Exists (Path (Root, "src/a")) and then Read (Path (Root, "existing")) = "old",
         "a skipped conflict moves nothing");

      Watcher.Answer := Ops.Overwrite;
      Ops.Moving.Move_Path (Path (Root, "src"), Path (Root, "moved"), Watcher, Ok);
      AUnit.Assertions.Assert
        (Ok and then not FS.Exists (Path (Root, "src")) and then FS.Is_Link (Path (Root, "moved/broken"))
         and then Read (Path (Root, "moved/sub/b")) = "beta",
         "a tree moves whole");
      AUnit.Assertions.Assert (Watcher.Done = 1, "and is reported once");
      Remove (Root);
   end Test_Move;

   procedure Test_Remove_Tree (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("remove");
      Watcher : Recorder;
      Ok      : Boolean;
   begin
      Make_Tree (Root);

      Ops.Removing.Remove_Path (Path (Root, "src"), (others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (not Ok and then Watcher.Last_Error = Ops.Is_A_Directory and then FS.Exists (Path (Root, "src/a")),
         "a directory is not removed without asking for it");

      Reset (Watcher, Stop_After => 1);
      Ops.Removing.Remove_Path (Path (Root, "src"), (Recursive => True, others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (not Ok and then Watcher.Errors = 0 and then FS.Kind (Path (Root, "src")) = FS.Directory,
         "a cancelled removal stops, and leaves what it had not reached");

      Reset (Watcher);
      Ops.Removing.Remove_Path (Path (Root, "src"), (Recursive => True, others => <>), Watcher, Ok);
      AUnit.Assertions.Assert (Ok and then not FS.Exists (Path (Root, "src")), "a tree with links is removed");
      AUnit.Assertions.Assert
        (Read (Path (Root, "outside/keep")) = "keep", "and nothing a link in it points to is touched");

      Ops.Removing.Remove_Path (Path (Root, "missing"), (others => <>), Watcher, Ok);
      AUnit.Assertions.Assert
        (not Ok and then Watcher.Last_Error = Ops.Cannot_Remove, "what does not exist cannot be removed");
      Remove (Root);
   end Test_Remove_Tree;

   procedure Test_Rm_Keeps_Link_Targets (T : in out Fixture) is
      pragma Unreferenced (T);
      Root    : constant String := Root_For ("rm");
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Make_Tree (Root);
      Context.Initialize ("rm", Args ("-r", Path (Root, "src/dirlink")));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not FS.Is_Link (Path (Root, "src/dirlink"))
         and then Read (Path (Root, "outside/keep")) = "keep",
         "rm -r on a link to a directory removes the link, not what is in the directory");

      Context.Initialize ("rm", Args ("-r", Path (Root, "src")));
      Posix_Tools.Commands.Rm.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then not FS.Exists (Path (Root, "src")),
         "rm -r removes a tree with links in it");
      Remove (Root);
   end Test_Rm_Keeps_Link_Targets;

   procedure Write (Name, Text : String) is
      Ok : Boolean;
   begin
      FS.Write_File (Name, Text, Append_Mode => False, Ok => Ok);
      AUnit.Assertions.Assert (Ok, "fixture written: " & Name);
   end Write;
end Operation_Tests;
