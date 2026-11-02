with Tooling_Checks;

--  The checks Run_Metadata_Checks makes, by theme, in the child packages;
--  this package holds what more than one theme uses.
package Metadata_Checks is
   function Check return Tooling_Checks.Checker;
   procedure Require_Synchronized_Version (Path : String);
   procedure Forbid_Text (Path : String; Text : String; Message : String);
   function Count_Exact_Lines (Text : String; Expected : String) return Natural;
   procedure Require_Exact_Line (Path : String; Line : String; Description : String);
   --  Every line of Path that is exactly Earlier comes before every line
   --  that is exactly Later, and each occurs at least once.
   procedure Require_Line_Order (Path : String; Earlier : String; Later : String);
   procedure Require_Crate_Metadata
     (Path         : String;
      Name         : String;
      Project_File : String);
end Metadata_Checks;
