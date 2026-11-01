with Ada.Strings.Unbounded;

--  The failures the tooling driver and its checks report. Project_Tools'
--  Release_Checks reports a failed check by raising Program_Error, which
--  the driver cannot tell from a real Program_Error; a check here raises
--  Check_Failed instead, after printing its message, so the driver can
--  exit 1 quietly for a failed check and still report a real fault.
package Tooling_Checks is
   Check_Failed : exception;

   procedure Fail (Message : String)
   with No_Return;
   --  Print Message on standard error and raise Check_Failed.

   type Checker is tagged private;

   function Create (Root : String) return Checker;
   --  A checker whose relative paths are resolved against Root.

   procedure Require_File (Check : Checker; Relative_Path : String);
   procedure Require_Directory (Check : Checker; Relative_Path : String);
   procedure Require_Text (Check : Checker; Relative_Path : String; Text : String);
   --  The file must contain Text: it says the text is there, not what it
   --  means.

   procedure Require_Manifest_Entry
     (Manifest_Path : String;
      Root          : String;
      Relative_Path : String);
   --  The manifest at Manifest_Path must hold Relative_Path's current
   --  size and checksum line.

private
   type Checker is tagged record
      Root : Ada.Strings.Unbounded.Unbounded_String;
   end record;
end Tooling_Checks;
