with Ada.Directories;
with Posix_Tools.Command_Inventory;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Release_Checks;

package body Build_Checks is
   procedure Build_Crate (Alire : String; Directory : String; Label : String) is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label   => Label,
           Dir     => Directory,
           Program => Alire,
           Args    => Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument ("-n"),
               Project_Tools.Processes.Argument ("build")]));
   begin
      if Status /= 0 then
         Project_Tools.Release_Checks.Fail (Label & " failed");
      end if;
   end Build_Crate;

   --  Build a crate's own test program and run it from the crate directory.
   procedure Run_Crate_Tests (Alire : String; Directory : String; Program : String; Label : String) is
      Status : Integer;
   begin
      Build_Crate (Alire, Directory, "build " & Label);
      Status :=
        Project_Tools.Processes.Run_Status
          (Label   => Label,
           Dir     => Directory,
           --  Run_Status changes into Dir first, so a relative path would
           --  no longer name the program.
           Program => Ada.Directories.Full_Name (Project_Tools.Files.Join (Directory, Program)),
           Args    => Project_Tools.Processes.Arguments ([]));

      if Status /= 0 then
         Project_Tools.Release_Checks.Fail (Label & " failed");
      end if;
   end Run_Crate_Tests;

   procedure Run (Root : String) is
      Alire : constant String := Project_Tools.Processes.Locate_Command ("alr");
   begin
      if Alire = "" then
         Project_Tools.Release_Checks.Fail ("alr command not found");
      end if;

      Build_Crate (Alire, Project_Tools.Files.Join (Root, "common"), "build common crate");
      Build_Crate (Alire, Root, "build root crate");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Build_Crate
           (Alire,
            Project_Tools.Files.Join
              (Root, "tools/" & Posix_Tools.Command_Inventory.Executable (I)),
            "build " & Posix_Tools.Command_Inventory.Executable (I));
      end loop;
      Run_Crate_Tests
        (Alire, Project_Tools.Files.Join (Root, "tools/explore/tests"), "bin/explore_tests", "explore tests");
      Build_Crate (Alire, Project_Tools.Files.Join (Root, "tests"), "build tests crate");
   end Run;
end Build_Checks;
