with Ada.Directories;
with Hostkit.Fs;
with Hostkit.Metadata;

package body Posix_Tools.Host_Adapters.File_System.Metadata is
   function Allocated_Size (Path : String; Available : out Boolean) return Long_Long_Integer is
   begin
      --  Hostkit's public metadata surface does not yet expose per-file allocated
      --  block counts. Keep the capability explicit so command code can distinguish
      --  real allocated usage from the portable byte-size fallback.
      Available := False;
      return Long_Long_Integer (Ada.Directories.Size (Path));
   end Allocated_Size;

   function Device_Id (Path : String; Available : out Boolean) return Long_Long_Integer is
   begin
      return Hostkit.Metadata.Device_Id (Path, Available);
   end Device_Id;

   procedure File_Ownership
     (Path      : String;
      User      : out Natural;
      Group     : out Natural;
      Available : out Boolean)
   is
   begin
      Hostkit.Metadata.File_Ownership (Path, User, Group, Available);
   end File_Ownership;

   function File_Name_Limit (Path : String; Available : out Boolean) return Natural is
      Capacity : constant Hostkit.Metadata.Volume_Capacity := Hostkit.Metadata.Volume_Capacity_Of (Path);
   begin
      Available := Capacity.Available and then Capacity.Name_Max_Known;
      return (if Available then Capacity.Name_Max else 0);
   end File_Name_Limit;

   function File_Permission_Bits (Path : String; Available : out Boolean) return Natural is
   begin
      return Hostkit.Metadata.File_Permission_Bits (Path, Available);
   end File_Permission_Bits;

   function File_System_Capacity (Path : String) return Volume_Capacity is
      Capacity : constant Hostkit.Metadata.Volume_Capacity := Hostkit.Metadata.Volume_Capacity_Of (Path);
   begin
      return
        (Available      => Capacity.Available,
         Capacity_Bytes => Capacity.Capacity_Bytes,
         Free_Bytes     => Capacity.Free_Bytes);
   exception
      when others =>
         return (Available => False, Capacity_Bytes => 0, Free_Bytes => 0);
   end File_System_Capacity;

   function Group_Id_For_Name (Name : String; Found : out Boolean) return Natural is
   begin
      return Hostkit.Metadata.Group_Id_For_Name (Name, Found);
   end Group_Id_For_Name;

   function Group_Name_For_Current_User return String is
      User      : Natural;
      Group     : Natural;
      Available : Boolean;
   begin
      Hostkit.Metadata.File_Ownership (Ada.Directories.Current_Directory, User, Group, Available);
      if Available then
         return Hostkit.Metadata.Group_Name_For_Id (Group);
      end if;
      return "";
   exception
      when others =>
         return "";
   end Group_Name_For_Current_User;

   function Group_Name_For_Id (Id : Natural) return String is
   begin
      return Hostkit.Metadata.Group_Name_For_Id (Id);
   end Group_Name_For_Id;

   function Is_Link (Path : String) return Boolean is
   begin
      return Hostkit.Fs.Is_Link (Path);
   end Is_Link;

   function Kind (Path : String) return File_Kind is
   begin
      if not Ada.Directories.Exists (Path) then
         return Missing_File;
      end if;

      case Ada.Directories.Kind (Path) is
         when Ada.Directories.Directory =>
            return Directory;
         when Ada.Directories.Ordinary_File =>
            return Ordinary_File;
         when Ada.Directories.Special_File =>
            return Special_File;
      end case;
   exception
      when others =>
         return Missing_File;
   end Kind;

   function Size (Path : String) return Long_Long_Integer is
   begin
      return Long_Long_Integer (Ada.Directories.Size (Path));
   end Size;

   function Special_File_Info_Of (Path : String) return Special_File_Info is
      Source : constant Hostkit.Fs.Special_File_Info := Hostkit.Fs.Special_File_Info_Of (Path);
   begin
      return
        (Available => Source.Available,
         Kind      =>
           (case Source.Kind is
              when Hostkit.Fs.Not_Special => Not_Special,
              when Hostkit.Fs.FIFO => FIFO,
              when Hostkit.Fs.Character_Device => Character_Device,
              when Hostkit.Fs.Block_Device => Block_Device,
              when Hostkit.Fs.Socket => Socket,
              when Hostkit.Fs.Other_Special => Other_Special),
         Device    => Source.Device,
         Mode      => Source.Mode);
   end Special_File_Info_Of;

   function User_Id_For_Name (Name : String; Found : out Boolean) return Natural is
   begin
      return Hostkit.Metadata.User_Id_For_Name (Name, Found);
   end User_Id_For_Name;

   function User_Name_For_Id (Id : Natural) return String is
   begin
      return Hostkit.Metadata.User_Name_For_Id (Id);
   end User_Name_For_Id;
end Posix_Tools.Host_Adapters.File_System.Metadata;
