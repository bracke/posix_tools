--  What each posix_tools_tests subcommand runs, in order. The driver runs
--  exactly these lists and nothing else, so a metadata check of a list is a
--  check of what the subcommand does, not of how its source reads.
package Tooling_Steps is
   type Step is
     (Require_Clean_Source_Tree,
      Generate_Docs,
      Generate_Package_Manifest,
      Run_Build,
      Run_Test_Selector_Smoke,
      Run_Staged_Verification,
      Run_Executable_Integration_Smoke,
      Generate_Release_Archive,
      Generate_Release_Checksums,
      Run_Metadata_Checks,
      Run_Format_Checks,
      Run_Conformance_Checks,
      Run_Proof_Checks,
      Run_Tests);

   type Step_List is array (Positive range <>) of Step;

   type Subcommand is
     (Test_Command,
      Check_Command,
      Release_Check_Command,
      Release_Command,
      Build_Command,
      Conformance_Command,
      Format_Check_Command,
      Docs_Command,
      Prove_Command,
      Package_Command);

   --  The name the subcommand is invoked by.
   function Name (Item : Subcommand) return String is
     (case Item is
         when Test_Command          => "test",
         when Check_Command         => "check",
         when Release_Check_Command => "release-check",
         when Release_Command       => "release",
         when Build_Command         => "build",
         when Conformance_Command   => "conformance",
         when Format_Check_Command  => "format-check",
         when Docs_Command          => "docs",
         when Prove_Command         => "prove",
         when Package_Command       => "package");

   --  Whether Text names a subcommand, and which.
   function Is_Subcommand (Text : String) return Boolean is
     (for some Item in Subcommand => Name (Item) = Text);
   function Lookup (Text : String) return Subcommand
   with Pre => Is_Subcommand (Text);

   --  The release-check gate before its proofs and tests, which release
   --  runs too.
   Release_Gate : constant Step_List :=
     [Generate_Docs,
      Generate_Package_Manifest,
      Run_Build,
      Run_Test_Selector_Smoke,
      Run_Staged_Verification,
      Run_Executable_Integration_Smoke,
      Generate_Release_Archive];

   --  The checks every full gate ends with.
   Final_Checks : constant Step_List :=
     [Run_Metadata_Checks,
      Run_Format_Checks,
      Run_Conformance_Checks,
      Run_Proof_Checks,
      Run_Tests];

   function Steps (Item : Subcommand) return Step_List is
     (case Item is
         when Test_Command          => [Run_Tests],
         when Check_Command         =>
           [Run_Metadata_Checks, Run_Format_Checks, Run_Conformance_Checks, Run_Tests],
         when Release_Check_Command => Release_Gate & Final_Checks,
         when Release_Command       =>
           Require_Clean_Source_Tree & Release_Gate & Generate_Release_Checksums & Final_Checks,
         when Build_Command         => [Run_Build, Run_Metadata_Checks],
         when Conformance_Command   => [Run_Metadata_Checks, Run_Conformance_Checks],
         when Format_Check_Command  => [Run_Metadata_Checks, Run_Format_Checks],
         when Docs_Command          => [Generate_Docs, Run_Metadata_Checks],
         when Prove_Command         => [Run_Metadata_Checks, Run_Proof_Checks],
         when Package_Command       =>
           [Generate_Package_Manifest, Generate_Release_Archive, Run_Metadata_Checks]);

   function Contains (List : Step_List; Item : Step) return Boolean is
     (for some Each of List => Each = Item);

   --  Where Item first comes in List; 0 when it does not.
   function Position (List : Step_List; Item : Step) return Natural;
end Tooling_Steps;
