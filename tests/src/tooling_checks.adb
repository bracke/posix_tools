with Ada.Command_Line;
with Ada.Text_IO;
with Project_Tools.Files;
with Project_Tools.Release_Checks;

package body Tooling_Checks is
   use Ada.Strings.Unbounded;

   procedure Fail (Message : String) is
   begin
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Message);
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      raise Check_Failed with Message;
   end Fail;

   function Create (Root : String) return Checker is
     (Root => To_Unbounded_String (Root));

   function Path (Check : Checker; Relative_Path : String) return String is
     (Project_Tools.Files.Join (To_String (Check.Root), Relative_Path));

   procedure Require_File (Check : Checker; Relative_Path : String) is
   begin
      if not Project_Tools.Files.File_Exists (Path (Check, Relative_Path)) then
         Fail ("required release file missing: " & Relative_Path);
      end if;
   end Require_File;

   procedure Require_Directory (Check : Checker; Relative_Path : String) is
   begin
      if not Project_Tools.Files.Directory_Exists (Path (Check, Relative_Path)) then
         Fail ("required release directory missing: " & Relative_Path);
      end if;
   end Require_Directory;

   procedure Require_Text (Check : Checker; Relative_Path : String; Text : String) is
   begin
      if not Project_Tools.Files.File_Exists (Path (Check, Relative_Path)) then
         Fail (Relative_Path & " is missing; it must contain: " & Text);
      elsif not Project_Tools.Files.File_Contains (Path (Check, Relative_Path), Text) then
         Fail (Relative_Path & " must contain: " & Text);
      end if;
   end Require_Text;

   procedure Require_Manifest_Entry
     (Manifest_Path : String;
      Root          : String;
      Relative_Path : String) is
   begin
      if not Project_Tools.Files.File_Exists (Project_Tools.Files.Join (Root, Relative_Path)) then
         Fail ("package manifest names a missing file: " & Relative_Path);
      elsif not Project_Tools.Files.Has_Line
        (Manifest_Path, Project_Tools.Release_Checks.Manifest_Line (Root, Relative_Path))
      then
         Fail ("package manifest missing entry: " & Relative_Path);
      end if;
   end Require_Manifest_Entry;
end Tooling_Checks;
