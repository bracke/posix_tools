with Ada.Directories;
with GNAT.OS_Lib;
with Posix_Tools.Command_Inventory;
with Project_Tools.Files;
with Project_Tools.Processes;
with Tooling_Checks;

package body Build_Checks is
   GNAT_Toolchain : constant String := "gnat_native=15.2.1";
   GPR_Toolchain  : constant String := "gprbuild=26.0.1";

   --  Every dependency project otherwise writes to the same sibling-checkout
   --  object and library directories.  A dedicated GPRbuild subdirectory
   --  keeps this repository's full build from racing builds in those repos.
   Build_Subdirectory : constant String := "posix_tools_check";

   function Built_Program
     (Directory : String;
      Program   : String) return String
   is
     (Project_Tools.Files.Join
        (Directory, "bin/" & Build_Subdirectory & "/" & Program));

   procedure Promote_Program
     (Directory : String;
      Program   : String)
   is
      Source : constant String := Built_Program (Directory, Program);
      Target : constant String :=
        Project_Tools.Files.Join (Directory, "bin/" & Program);
   begin
      if Program = "" then
         return;
      elsif Project_Tools.Files.File_Exists (Source) then
         Ada.Directories.Copy_File
           (Source, Target, Form => "mode=overwrite,preserve=all_attributes");
      elsif Project_Tools.Files.File_Exists (Source & ".exe") then
         Ada.Directories.Copy_File
           (Source & ".exe",
            Target & ".exe",
            Form => "mode=overwrite,preserve=all_attributes");
      else
         Tooling_Checks.Fail ("isolated build did not produce " & Program);
      end if;
   end Promote_Program;

   procedure Select_Toolchain
     (Alire    : String;
      Directory : String;
      Label     : String)
   is
      Status : constant Integer :=
        Project_Tools.Processes.Run_Status
          (Label   => "select " & Label & " toolchain",
           Dir     => Directory,
           Program => Alire,
           Args    => Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument ("toolchain"),
               Project_Tools.Processes.Argument ("--select"),
               Project_Tools.Processes.Argument ("--local"),
               Project_Tools.Processes.Argument (GNAT_Toolchain),
               Project_Tools.Processes.Argument (GPR_Toolchain)]));
   begin
      if Status /= 0 then
         Tooling_Checks.Fail ("select " & Label & " toolchain failed");
      end if;
   end Select_Toolchain;

   procedure Build_Crate
     (Alire     : String;
      Directory : String;
      Label     : String;
      Program   : String := "")
   is
      Status : Integer;
   begin
      Select_Toolchain (Alire, Directory, Label);
      Status :=
        Project_Tools.Processes.Run_Status
          (Label   => Label,
           Dir     => Directory,
           Program => Alire,
           Args    => Project_Tools.Processes.Arguments
             ([Project_Tools.Processes.Argument ("-n"),
               Project_Tools.Processes.Argument ("build"),
               Project_Tools.Processes.Argument ("--"),
               Project_Tools.Processes.Argument
                 ("--subdirs=" & Build_Subdirectory)]));
      if Status /= 0 then
         Tooling_Checks.Fail (Label & " failed");
      end if;
      Promote_Program (Directory, Program);
   end Build_Crate;

   --  Build a crate's own test program and run it from the crate directory.
   procedure Run_Crate_Tests
     (Alire     : String;
      Directory : String;
      Program   : String;
      Label     : String)
   is
      Status : Integer;
   begin
      Build_Crate (Alire, Directory, "build " & Label, Program);
      Status :=
        Project_Tools.Processes.Run_Status
          (Label   => Label,
           Dir     => Directory,
           --  Run_Status changes into Dir first, so a relative path would
           --  no longer name the program.
           Program => Ada.Directories.Full_Name
             (Project_Tools.Files.Join (Directory, "bin/" & Program)),
           Args    => Project_Tools.Processes.Arguments ([]));

      if Status /= 0 then
         Tooling_Checks.Fail (Label & " failed");
      end if;
   end Run_Crate_Tests;

   procedure Run (Root : String) is
      Alire : constant String := Project_Tools.Processes.Locate_Command ("alr");
   begin
      if Alire = "" then
         Tooling_Checks.Fail ("alr command not found");
      end if;

      Build_Crate (Alire, Project_Tools.Files.Join (Root, "common"), "build common crate");
      Build_Crate (Alire, Root, "build root crate", "posix-tools");
      for I in 1 .. Posix_Tools.Command_Inventory.Command_Count loop
         Build_Crate
           (Alire,
            Project_Tools.Files.Join
              (Root, "tools/" & Posix_Tools.Command_Inventory.Executable (I)),
            "build " & Posix_Tools.Command_Inventory.Executable (I),
            Posix_Tools.Command_Inventory.Executable (I));
      end loop;
      --  explore runs only in bracke-terminal on a POSIX host: it is built
      --  everywhere, as every command is, but tested only where it runs.
      if GNAT.OS_Lib.Directory_Separator = '/' then
         Run_Crate_Tests
           (Alire, Project_Tools.Files.Join (Root, "tools/explore/tests"), "explore_tests", "explore tests");
         --  explore end to end, through a pseudo-terminal into bracke-terminal's
         --  emulator core; it runs the explore built above.
         Run_Crate_Tests
           (Alire,
            Project_Tools.Files.Join (Root, "tools/explore/e2e"),
            "explore_e2e",
            "explore end-to-end tests");
      end if;
      Build_Crate (Alire, Project_Tools.Files.Join (Root, "tests"), "build tests crate");
   end Run;
end Build_Checks;
