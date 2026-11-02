with Ada.Command_Line;
with Ada.Exceptions;
with Ada.Text_IO;
with Build_Checks;
with Conformance_Checks;
with Format_Checks;
with Integration_Smoke;
with Metadata_Checks.Command_Inventory;
with Metadata_Checks.Continuous_Integration;
with Metadata_Checks.Dependencies;
with Metadata_Checks.Manifests;
with Metadata_Checks.Packaging;
with Metadata_Checks.Requirements;
with Metadata_Checks.Source_Rules;
with Metadata_Checks.Test_Coverage;
with Metadata_Checks.Tooling_Docs;
with Proof_Checks;
with Release_Artifacts;
with Selector_Smoke;
with Staged_Verification;
with Test_Selection;
with Tooling_Checks;
with Tooling_Steps;
with Tooling_Support;

--  The project tooling driver: runs the steps Tooling_Steps lists for the
--  subcommand it is given, "test" when none.
procedure Posix_Tools_Tests is
   Command : constant String :=
     (if Ada.Command_Line.Argument_Count = 0 then "test" else Ada.Command_Line.Argument (1));

   --  Only a release writes generated/release-checksums.txt, from the
   --  binaries it built; between releases the committed file is that
   --  release's record, and every local build would make it stale. So only
   --  a release checks what the file holds.
   Writes_Release_Checksums : constant Boolean :=
     Tooling_Steps.Is_Subcommand (Command)
     and then Tooling_Steps.Contains
       (Tooling_Steps.Steps (Tooling_Steps.Lookup (Command)),
        Tooling_Steps.Generate_Release_Checksums);

   procedure Run_Metadata_Checks is
   begin
      Metadata_Checks.Manifests.Run;
      Metadata_Checks.Tooling_Docs.Run (Writes_Release_Checksums);
      Metadata_Checks.Test_Coverage.Run;
      Metadata_Checks.Source_Rules.Run;
      Metadata_Checks.Dependencies.Run;
      Metadata_Checks.Command_Inventory.Run;
      Metadata_Checks.Requirements.Run;
      Metadata_Checks.Continuous_Integration.Run;
      Metadata_Checks.Packaging.Run (Writes_Release_Checksums);
      Ada.Text_IO.Put_Line ("metadata checks passed");
   end Run_Metadata_Checks;

   procedure Run_Step (Item : Tooling_Steps.Step) is
      use Tooling_Steps;
      Root : constant String := Tooling_Support.Root;
   begin
      case Item is
         when Require_Clean_Source_Tree        => Release_Artifacts.Require_Clean_Source_Tree;
         when Generate_Docs                    => Release_Artifacts.Generate_Docs;
         when Generate_Package_Manifest        => Release_Artifacts.Generate_Package_Manifest;
         when Run_Build                        => Build_Checks.Run (Root);
         when Run_Test_Selector_Smoke          => Selector_Smoke.Run;
         when Run_Staged_Verification          => Staged_Verification.Run;
         when Run_Executable_Integration_Smoke => Integration_Smoke.Run;
         when Generate_Release_Archive         => Release_Artifacts.Generate_Release_Archive;
         when Generate_Release_Checksums       => Release_Artifacts.Generate_Release_Checksums;
         when Run_Metadata_Checks              => Posix_Tools_Tests.Run_Metadata_Checks;
         when Run_Format_Checks                => Format_Checks.Run (Root);
         when Run_Conformance_Checks           => Conformance_Checks.Run;
         when Run_Proof_Checks                 => Proof_Checks.Run;
         when Run_Tests                        => Test_Selection.Run;
      end case;
   end Run_Step;
begin
   if not Tooling_Steps.Is_Subcommand (Command) then
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "posix_tools_tests: unknown command '" & Command & "'");
      Ada.Command_Line.Set_Exit_Status (2);
      return;
   end if;

   declare
      use Tooling_Steps;
      Item : constant Subcommand := Lookup (Command);
   begin
      for Each of Steps (Item) loop
         Run_Step (Each);
      end loop;

      if Item not in Test_Command | Check_Command | Release_Check_Command then
         Ada.Text_IO.Put_Line (Command & ": completed by Ada project_tools driver");
      end if;
   end;
exception
   when Test_Selection.Invalid_Usage =>
      Ada.Command_Line.Set_Exit_Status (2);
   when Tooling_Checks.Check_Failed =>
      --  The check has said what failed.
      Ada.Command_Line.Set_Exit_Status (1);
   when Occurrence : others =>
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         "posix_tools_tests: internal tooling failure");
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error,
         Ada.Exceptions.Exception_Information (Occurrence));
      Ada.Command_Line.Set_Exit_Status (125);
end Posix_Tools_Tests;
