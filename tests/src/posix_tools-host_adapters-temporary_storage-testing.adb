with Ada.Directories;
with Ada.Strings.Unbounded;
with Hostkit.Descriptors;

package body Posix_Tools.Host_Adapters.Temporary_Storage.Testing is
   function Backing_Directory (Self : Store) return String is
     (Ada.Strings.Unbounded.To_String (Self.Directory));

   function Backing_Path (Self : Store) return String is
     (Ada.Strings.Unbounded.To_String (Self.Path));

   procedure Close_Backing_File (Self : in out Store) is
   begin
      Hostkit.Descriptors.Close (Self.File);
   end Close_Backing_File;

   procedure Remove_Backing_File (Self : in out Store) is
   begin
      Hostkit.Descriptors.Close (Self.File);
      Ada.Directories.Delete_File
        (Ada.Strings.Unbounded.To_String (Self.Path));
   end Remove_Backing_File;

   procedure Force_Cleanup_Failure (Self : in out Store) is
      Path : constant String := Ada.Strings.Unbounded.To_String (Self.Path);
   begin
      Hostkit.Descriptors.Close (Self.File);
      Ada.Directories.Delete_File (Path);
      Ada.Directories.Create_Directory (Path);
   end Force_Cleanup_Failure;

   procedure Repair_Cleanup_Failure (Self : in out Store) is
      Path : constant String := Ada.Strings.Unbounded.To_String (Self.Path);
   begin
      if Ada.Directories.Exists (Path) then
         Ada.Directories.Delete_Directory (Path);
      end if;
   end Repair_Cleanup_Failure;
end Posix_Tools.Host_Adapters.Temporary_Storage.Testing;
