with Posix_Tools.Command_Inventory.Tables;

package body Posix_Tools.Command_Inventory
  with SPARK_Mode => On
is
   function Executable (Index : Positive) return String is
   begin
      return Posix_Tools.Command_Inventory.Tables.Executable (Index);
   end Executable;

   function Crate (Index : Positive) return String is
   begin
      return Posix_Tools.Command_Inventory.Tables.Crate (Index);
   end Crate;

   function Package_Name (Index : Positive) return String is
   begin
      return Posix_Tools.Command_Inventory.Tables.Package_Name (Index);
   end Package_Name;

   function Manifest_Path (Index : Positive) return String is
   begin
      return "tools/" & Executable (Index) & "/alire.toml";
   end Manifest_Path;

   function Project_File_Path (Index : Positive) return String is
   begin
      return "tools/" & Executable (Index) & "/" & Crate (Index) & ".gpr";
   end Project_File_Path;

   function Documentation_Path (Index : Positive) return String is
   begin
      return "docs/commands/" & Executable (Index) & ".md";
   end Documentation_Path;

   function Release_Included (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Release_Included;

   function Posix_Status (Index : Positive) return String is
   begin
      return Posix_Tools.Command_Inventory.Tables.Posix_Status (Index);
   end Posix_Status;

   function Has_Help (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Help;

   function Has_Version (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Version;

   function Has_Identity (Index : Positive) return Boolean is
      pragma Unreferenced (Index);
   begin
      return True;
   end Has_Identity;

   function Contains_Executable (Name : String) return Boolean is
   begin
      for I in 1 .. Command_Count loop
         if Executable (I) = Name then
            return True;
         end if;
      end loop;

      return False;
   end Contains_Executable;
end Posix_Tools.Command_Inventory;
