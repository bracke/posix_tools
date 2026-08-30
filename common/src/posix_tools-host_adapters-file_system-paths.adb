with Ada.Directories;
with Hostkit.Fs;
with Hostkit.Metadata;

package body Posix_Tools.Host_Adapters.File_System.Paths is
   function Containing_Directory (Path : String) return String is
   begin
      return Ada.Directories.Containing_Directory (Path);
   end Containing_Directory;

   function Path_Name_Limit (Path : String; Available : out Boolean) return Natural is
      pragma Unreferenced (Path);
   begin
      Available := False;
      return 0;
   end Path_Name_Limit;

   function Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   end Exists;

   function Full_Name (Path : String) return String is
   begin
      return Ada.Directories.Full_Name (Path);
   end Full_Name;

   function Join (Left : String; Right : String) return String is
   begin
      return Hostkit.Fs.Join (Left, Right);
   end Join;

   function Physical_Current_Directory return String is
   begin
      return Ada.Directories.Current_Directory;
   end Physical_Current_Directory;

   function Try_Physical_Current_Directory (Path : out String; Last : out Natural) return Boolean is
      Current : constant String := Physical_Current_Directory;
   begin
      if Current'Length > Path'Length then
         Last := 0;
         return False;
      end if;

      Last := Current'Length;
      if Last > 0 then
         Path (Path'First .. Path'First + Last - 1) := Current;
      end if;

      return True;
   exception
      when others =>
         Last := 0;
         return False;
   end Try_Physical_Current_Directory;

   function Path_Names_Current_Directory (Path : String) return Boolean is
   begin
      return Hostkit.Metadata.Same_File (Path, Physical_Current_Directory);
   exception
      when others =>
         return False;
   end Path_Names_Current_Directory;

   function Read_Link_Target (Path : String; Target : out Ada.Strings.Unbounded.Unbounded_String) return Boolean is
   begin
      return Hostkit.Fs.Read_Link_Target (Path, Target);
   end Read_Link_Target;

   function Real_Path (Path : String) return String is
   begin
      return Hostkit.Fs.Real_Path (Path);
   end Real_Path;

   procedure Rename (Old_Path : String; New_Path : String) is
   begin
      Ada.Directories.Rename (Old_Path, New_Path);
   end Rename;

   function Same_File (Left : String; Right : String) return Boolean is
   begin
      return Hostkit.Metadata.Same_File (Left, Right);
   end Same_File;

   function Simple_Name (Path : String) return String is
   begin
      return Ada.Directories.Simple_Name (Path);
   end Simple_Name;
end Posix_Tools.Host_Adapters.File_System.Paths;
