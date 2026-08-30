with Ada.Directories;
with GNAT.OS_Lib;
with Hostkit.Fs;
with Hostkit.Metadata;

package body Posix_Tools.Host_Adapters.File_System.Directories is
   procedure Create_Directory (Path : String) is
   begin
      Ada.Directories.Create_Directory (Path);
   end Create_Directory;

   function Create_Device
     (Path   : String;
      Kind   : Special_File_Kind;
      Device : Interfaces.Unsigned_64;
      Mode   : Natural) return Boolean
   is
   begin
      case Kind is
         when Character_Device =>
            return Hostkit.Fs.Create_Device (Path, Hostkit.Fs.Character_Device, Device, Mode);
         when Block_Device =>
            return Hostkit.Fs.Create_Device (Path, Hostkit.Fs.Block_Device, Device, Mode);
         when others =>
            return False;
      end case;
   end Create_Device;

   function Create_FIFO (Path : String; Mode : Natural) return Boolean is
   begin
      return Hostkit.Fs.Create_FIFO (Path, Mode);
   end Create_FIFO;

   function Create_Socket (Path : String; Mode : Natural) return Boolean is
   begin
      return Hostkit.Fs.Create_Socket (Path, Mode);
   end Create_Socket;

   function Create_Hard_Link (Source : String; Target : String) return Boolean is
   begin
      return Hostkit.Fs.Create_Hard_Link (Source, Target);
   end Create_Hard_Link;

   function Create_Link (Source : String; Target : String) return Boolean is
   begin
      return Hostkit.Fs.Create_Link (Source, Target);
   end Create_Link;

   procedure Create_Path (Path : String) is
   begin
      Ada.Directories.Create_Path (Path);
   end Create_Path;

   procedure Delete_Directory (Path : String) is
   begin
      Ada.Directories.Delete_Directory (Path);
   end Delete_Directory;

   procedure Delete_File (Path : String) is
      Deleted : Boolean := False;
   begin
      GNAT.OS_Lib.Delete_File (Path, Deleted);
      if not Deleted then
         Ada.Directories.Delete_File (Path);
      end if;
   end Delete_File;

   function Delete_Link (Path : String) return Boolean is
   begin
      return Hostkit.Fs.Delete_Link (Path);
   end Delete_Link;

   procedure Delete_Tree (Path : String) is
   begin
      Ada.Directories.Delete_Tree (Path);
   end Delete_Tree;

   function Set_Ownership (Path : String; User : Natural; Group : Natural) return Boolean is
   begin
      return Hostkit.Metadata.Set_Ownership (Path, User, Group);
   end Set_Ownership;

   function Set_Permissions (Path : String; Mode : Natural) return Boolean is
   begin
      return Hostkit.Metadata.Set_Permissions (Path, Mode);
   end Set_Permissions;

   procedure For_Each_Directory_Entry (Path : String; Ok : out Boolean) is
      Search      : Ada.Directories.Search_Type;
      Search_Open : Boolean := False;
      Dir_Entry   : Ada.Directories.Directory_Entry_Type;
      Stop        : Boolean := False;

      procedure Close_Search (Cleanup_Ok : in out Boolean) is
      begin
         if Search_Open then
            Ada.Directories.End_Search (Search);
            Search_Open := False;
         end if;
      exception
         when others =>
            Cleanup_Ok := False;
            Search_Open := False;
      end Close_Search;
   begin
      Ok := True;
      Ada.Directories.Start_Search (Search, Path, "*");
      Search_Open := True;
      while not Stop and then Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               Action (Name, Ada.Directories.Full_Name (Dir_Entry), Stop);
            end if;
         exception
            when others =>
               Ok := False;
         end;
      end loop;
      Close_Search (Ok);
   exception
      when others =>
         declare
            Cleanup_Ok : Boolean := False;
         begin
            Close_Search (Cleanup_Ok);
         end;
         Ok := False;
   end For_Each_Directory_Entry;
end Posix_Tools.Host_Adapters.File_System.Directories;
