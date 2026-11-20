with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Test_Contexts;
with Test_Support;

package body Rg_Follow_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Exit_Status.Code;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Path (Parent, Name : String) return String is
     (FS.Child_Path (Parent, Name));

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Follow_Links (T : in out Fixture) is
      pragma Unreferenced (T);
      LF         : constant Character := ASCII.LF;
      Root       : constant String := Test_Support.Work_Path ("rg-follow");
      Clean      : constant String := Path (Root, "clean");
      Real       : constant String := Path (Clean, "real");
      Plain      : constant String := Path (Clean, "plain.txt");
      Child      : constant String := Path (Real, "child.txt");
      Link_File  : constant String := Path (Clean, "to-file");
      Link_Dir   : constant String := Path (Clean, "to-dir");
      Cycle      : constant String := Path (Root, "cycle");
      Cycle_Real : constant String := Path (Cycle, "real");
      Cycle_Sub  : constant String := Path (Cycle_Real, "sub");
      Cycle_Hit  : constant String := Path (Cycle_Real, "hit.txt");
      Back       : constant String := Path (Cycle_Sub, "back");
      Broken_Dir : constant String := Path (Root, "broken-dir");
      Broken     : constant String := Path (Broken_Dir, "broken");

      procedure Remove_Links;

      procedure Remove_Links is
         procedure Unlink (Name : String);

         procedure Unlink (Name : String) is
         begin
            if FS.Is_Link (Name) then
               AUnit.Assertions.Assert (FS.Delete_Link (Name), "rg follow fixture link removed");
            end if;
         end Unlink;
      begin
         Unlink (Link_File);
         Unlink (Link_Dir);
         Unlink (Back);
         Unlink (Broken);
      end Remove_Links;
   begin
      Test_Support.Delete_If_Exists (Root);
      AUnit.Assertions.Assert
        (FS.Create_Path (Real)
         and then FS.Create_Path (Cycle_Sub)
         and then FS.Create_Path (Broken_Dir),
         "rg follow fixture directories created");
      Test_Support.Write_File (Plain, "needle plain" & LF);
      Test_Support.Write_File (Child, "needle child" & LF);
      Test_Support.Write_File (Cycle_Hit, "needle cycle" & LF);

      if not FS.Create_Link ("plain.txt", Link_File)
        or else not FS.Create_Link ("real", Link_Dir)
        or else not FS.Create_Link ("..", Back)
        or else not FS.Create_Link ("missing", Broken)
      then
         Remove_Links;
         Test_Support.Delete_If_Exists (Root);
         Test_Support.Skip_Without_Links ("rg --follow");
         return;
      end if;

      declare
         Default : constant Run_Outcome := Run_Rg (["-l", "needle", Clean]);
         Followed : constant Run_Outcome := Run_Rg (["--follow", "-l", "needle", Clean]);
         Restored : constant Run_Outcome :=
           Run_Rg (["--follow", "--no-follow", "-l", "needle", Clean]);
         Short : constant Run_Outcome := Run_Rg (["-L", "-l", "needle", Clean]);
         Files : constant Run_Outcome := Run_Rg (["--files", "-L", Clean]);
         Looped : constant Run_Outcome := Run_Rg (["-L", "-l", "needle", Cycle]);
         Dangling : constant Run_Outcome := Run_Rg (["--follow", "-l", "needle", Broken_Dir]);
      begin
         AUnit.Assertions.Assert
           (Default.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Default.Output), Plain)
            and then Test_Support.Contains (To_String (Default.Output), Child)
            and then not Test_Support.Contains (To_String (Default.Output), Link_File)
            and then not Test_Support.Contains (To_String (Default.Output), Link_Dir),
            "recursive traversal skips discovered symbolic links by default");
         AUnit.Assertions.Assert
           (Followed.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Followed.Output), Link_File)
            and then Test_Support.Contains (To_String (Followed.Output), Path (Link_Dir, "child.txt")),
            "--follow searches linked files and directories");
         AUnit.Assertions.Assert
           (To_String (Short.Output) = To_String (Followed.Output),
            "-L is the short form of --follow");
         AUnit.Assertions.Assert
           (To_String (Restored.Output) = To_String (Default.Output),
            "--no-follow restores the default and the last toggle wins");
         AUnit.Assertions.Assert
           (Files.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Files.Output), Link_File)
            and then Test_Support.Contains (To_String (Files.Output), Path (Link_Dir, "child.txt")),
            "--files shares followed-link discovery");
         AUnit.Assertions.Assert
           (Looped.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Occurrences (To_String (Looped.Output), Cycle_Hit) = 1
            and then Test_Support.Contains (To_String (Looped.Errors), "File system loop found"),
            "ancestor loops are diagnosed and do not recurse indefinitely");
         AUnit.Assertions.Assert
           (Dangling.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains (To_String (Dangling.Errors), "cannot follow")
            and then Length (Dangling.Output) = 0,
            "broken discovered links produce a trouble result");
      end;

      Remove_Links;
      Test_Support.Delete_If_Exists (Root);
   end Test_Follow_Links;

   procedure Test_One_File_System (T : in out Fixture) is
      pragma Unreferenced (T);
      LF       : constant Character := ASCII.LF;
      Root     : constant String := Test_Support.Work_Path ("rg-one-file-system");
      Local    : constant String := Path (Root, "local.txt");
      Link_Dir : constant String := Path (Root, "other-device");
      Root_Device : Long_Long_Integer;
      Proc_Device : Long_Long_Integer;
      Root_Device_Available : Boolean;
      Proc_Device_Available : Boolean;
      Has_Cross_Device_Fixture : Boolean := False;
   begin
      Test_Support.Delete_If_Exists (Root);
      AUnit.Assertions.Assert (FS.Create_Path (Root), "rg one-file-system fixture created");
      Test_Support.Write_File (Local, "local" & LF);

      Root_Device := FS.Device_Id (Root, Root_Device_Available);
      Proc_Device := FS.Device_Id ("/proc", Proc_Device_Available);
      if Root_Device_Available
        and then Proc_Device_Available
        and then Root_Device /= Proc_Device
        and then FS.Kind ("/proc") = FS.Directory
        and then FS.Kind ("/proc/version") = FS.Ordinary_File
      then
         Has_Cross_Device_Fixture := FS.Create_Link ("/proc", Link_Dir);
         if not Has_Cross_Device_Fixture then
            Test_Support.Skip_Without_Links ("rg --one-file-system boundary fixture");
         end if;
      end if;

      declare
         Bounded : constant Run_Outcome :=
           Run_Rg (["--files", "-L", "--one-file-system", "--max-depth", "2", Root]);
         Restored : constant Run_Outcome :=
           Run_Rg
             (["--files", "-L", "--one-file-system", "--no-one-file-system",
               "--max-depth", "2", Root]);
      begin
         AUnit.Assertions.Assert
           (Bounded.Status = Posix_Tools.Exit_Status.Success
            and then Test_Support.Contains (To_String (Bounded.Output), Local),
            "--one-file-system retains files on the search root's device");

         if Has_Cross_Device_Fixture then
            declare
               Boundary_File : constant String := Path (Link_Dir, "version");
               Explicit : constant Run_Outcome :=
                 Run_Rg
                   (["--files", "-L", "--one-file-system", "--max-depth", "1", Link_Dir]);
            begin
               AUnit.Assertions.Assert
                 (not Test_Support.Contains (To_String (Bounded.Output), Boundary_File),
                  "--one-file-system skips a discovered cross-device directory link");
               AUnit.Assertions.Assert
                 (Test_Support.Contains (To_String (Restored.Output), Boundary_File),
                  "--no-one-file-system restores cross-device descent with last-option precedence");
               AUnit.Assertions.Assert
                 (Explicit.Status = Posix_Tools.Exit_Status.Success
                  and then Test_Support.Contains (To_String (Explicit.Output), Boundary_File),
                  "an explicit linked root establishes its target file system as the boundary");
            end;
         end if;
      end;

      if FS.Is_Link (Link_Dir) then
         AUnit.Assertions.Assert (FS.Delete_Link (Link_Dir), "rg one-file-system link removed");
      end if;
      Test_Support.Delete_If_Exists (Root);
   end Test_One_File_System;
end Rg_Follow_Tests;
