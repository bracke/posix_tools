with Hostkit.Descriptors;
with Hostkit.Metadata;
with Posix_Tools.Host_Adapters.File_System.Directories;
with Posix_Tools.Host_Adapters.File_System.IO;
with Posix_Tools.Host_Adapters.File_System.Metadata;
with Posix_Tools.Host_Adapters.File_System.Paths;
with Posix_Tools.Host_Adapters.File_System.Times;

package body Posix_Tools.Host_Adapters.File_System is
   use type Ada.Streams.Stream_Element_Offset;

   Buffer_Size : constant := 16 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);

   function Can_Open_For_Read (Path : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.IO.Can_Open_For_Read (Path);
   end Can_Open_For_Read;

   function Containing_Directory (Path : String) return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Containing_Directory (Path);
   end Containing_Directory;

   function File_Name_Limit (Path : String; Available : out Boolean) return Natural is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.File_Name_Limit (Path, Available);
   end File_Name_Limit;

   function File_System_Capacity (Path : String) return Volume_Capacity is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.File_System_Capacity (Path);
   end File_System_Capacity;

   function Path_Name_Limit (Path : String; Available : out Boolean) return Natural is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Path_Name_Limit
        (Path, Available);
   end Path_Name_Limit;

   function Copy_Modification_Time (Source : String; Target : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Copy_Modification_Time
        (Source, Target);
   end Copy_Modification_Time;

   function Copy_File_Times (Source : String; Target : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Copy_File_Times
        (Source, Target);
   end Copy_File_Times;

   procedure Copy_Regular_File (Source : String; Target : String; Status : out Copy_File_Status) is
   begin
      Posix_Tools.Host_Adapters.File_System.IO.Copy_Regular_File
        (Source, Target, Status);
   end Copy_Regular_File;

   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean)
   is
   begin
      Posix_Tools.Host_Adapters.File_System.IO.Write_File
        (Path, Text, Append_Mode, Ok);
   end Write_File;

   procedure Create_Directory (Path : String) is
   begin
      Posix_Tools.Host_Adapters.File_System.Directories.Create_Directory (Path);
   end Create_Directory;

   function Create_Device
     (Path   : String;
      Kind   : Special_File_Kind;
      Device : Interfaces.Unsigned_64;
      Mode   : Natural) return Boolean
   is
   begin
      return Posix_Tools.Host_Adapters.File_System.Directories.Create_Device
        (Path, Kind, Device, Mode);
   end Create_Device;

   function Create_FIFO (Path : String; Mode : Natural) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Directories.Create_FIFO (Path, Mode);
   end Create_FIFO;

   function Create_Socket (Path : String; Mode : Natural) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Directories.Create_Socket (Path, Mode);
   end Create_Socket;

   function Create_Hard_Link (Source : String; Target : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Directories.Create_Hard_Link
        (Source, Target);
   end Create_Hard_Link;

   function Create_Link (Source : String; Target : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Directories.Create_Link
        (Source, Target);
   end Create_Link;

   procedure Create_Path (Path : String) is
   begin
      Posix_Tools.Host_Adapters.File_System.Directories.Create_Path (Path);
   end Create_Path;

   procedure Delete_Directory (Path : String) is
   begin
      Posix_Tools.Host_Adapters.File_System.Directories.Delete_Directory (Path);
   end Delete_Directory;

   procedure Delete_File (Path : String) is
   begin
      Posix_Tools.Host_Adapters.File_System.Directories.Delete_File (Path);
   end Delete_File;

   function Delete_Link (Path : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Directories.Delete_Link (Path);
   end Delete_Link;

   procedure Delete_Tree (Path : String) is
   begin
      Posix_Tools.Host_Adapters.File_System.Directories.Delete_Tree (Path);
   end Delete_Tree;

   function Device_Id (Path : String; Available : out Boolean) return Long_Long_Integer is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Device_Id (Path, Available);
   end Device_Id;

   function Exists (Path : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Exists (Path);
   end Exists;

   procedure File_Ownership
     (Path      : String;
      User      : out Natural;
      Group     : out Natural;
      Available : out Boolean)
   is
   begin
      Posix_Tools.Host_Adapters.File_System.Metadata.File_Ownership
        (Path, User, Group, Available);
   end File_Ownership;

   function File_Permission_Bits (Path : String; Available : out Boolean) return Natural is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.File_Permission_Bits
        (Path, Available);
   end File_Permission_Bits;

   function Full_Name (Path : String) return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Full_Name (Path);
   end Full_Name;

   procedure For_Each_File_Chunk
     (Path   : String;
      Ok     : out Boolean)
   is
      use Hostkit.Descriptors;
      File   : Descriptor := Invalid;
      Buffer : Byte_Buffer;
      Last   : Ada.Streams.Stream_Element_Offset;
      Stop   : Boolean := False;
      Outcome : Transfer_Outcome;
   begin
      Ok := Open_File (Path, Open_Read, File);
      if not Ok then
         return;
      end if;

      while not Stop loop
         Outcome := Read (File, Buffer, Last);
         case Outcome is
            when Transfer_Ok =>
               if Last >= Buffer'First then
                  Action (Buffer, Last, Stop);
               end if;

            when Transfer_Interrupted =>
               null;

            when Transfer_End_Of_File =>
               exit;

            when others =>
               Ok := False;
               exit;
         end case;
      end loop;

      Close (File);
   exception
      when others =>
         Close (File);
         Ok := False;
   end For_Each_File_Chunk;

   procedure For_Each_File_Chunk_From
     (Path   : String;
      Offset : Long_Long_Integer;
      Ok     : out Boolean)
   is
      use Hostkit.Descriptors;
      File      : Descriptor := Invalid;
      Buffer    : Byte_Buffer;
      Last      : Ada.Streams.Stream_Element_Offset;
      Stop      : Boolean := False;
      Outcome   : Transfer_Outcome;
      Remaining : Long_Long_Integer := Offset;
      First     : Ada.Streams.Stream_Element_Offset;
   begin
      Ok := Open_File (Path, Open_Read, File);
      if not Ok then
         return;
      end if;

      while not Stop loop
         Outcome := Read (File, Buffer, Last);
         case Outcome is
            when Transfer_Ok =>
               if Last >= Buffer'First then
                  if Remaining >= Long_Long_Integer (Last - Buffer'First + 1) then
                     Remaining := Remaining - Long_Long_Integer (Last - Buffer'First + 1);
                  elsif Remaining > 0 then
                     First := Buffer'First + Ada.Streams.Stream_Element_Offset (Remaining);
                     Action (Buffer (First .. Last), Last, Stop);
                     Remaining := 0;
                  else
                     Action (Buffer, Last, Stop);
                  end if;
               end if;

            when Transfer_Interrupted =>
               null;

            when Transfer_End_Of_File =>
               exit;

            when others =>
               Ok := False;
               exit;
         end case;
      end loop;

      Close (File);
   exception
      when others =>
         Close (File);
         Ok := False;
   end For_Each_File_Chunk_From;

   function Group_Id_For_Name (Name : String; Found : out Boolean) return Natural is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Group_Id_For_Name
        (Name, Found);
   end Group_Id_For_Name;

   function Group_Name_For_Id (Id : Natural) return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Group_Name_For_Id (Id);
   end Group_Name_For_Id;

   function Group_Name_For_Current_User return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Group_Name_For_Current_User;
   end Group_Name_For_Current_User;

   function Is_Link (Path : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Is_Link (Path);
   end Is_Link;

   function Join (Left : String; Right : String) return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Join (Left, Right);
   end Join;

   function Kind (Path : String) return File_Kind is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Kind (Path);
   end Kind;

   function Current_File_Time return File_Time is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Current_File_Time;
   end Current_File_Time;

   function File_Time_From_File (Path : String; Time : out File_Time) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.File_Time_From_File
        (Path, Time);
   end File_Time_From_File;

   function File_Access_Time_From_File (Path : String; Time : out File_Time) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.File_Access_Time_From_File
        (Path, Time);
   end File_Access_Time_From_File;

   function Access_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Access_Time
        (Path, Time);
   end Access_Time;

   function Creation_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Creation_Time
        (Path, Time);
   end Creation_Time;

   function File_Time_Of
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Time   : out File_Time) return Boolean
   is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.File_Time_Of
        (Year, Month, Day, Hour, Minute, Second, Time);
   end File_Time_Of;

   function Modification_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Modification_Time
        (Path, Time);
   end Modification_Time;

   function Ownership_Supported return Boolean is
   begin
      return Hostkit.Metadata.Ownership_Supported;
   end Ownership_Supported;

   function Permissions_Supported return Boolean is
   begin
      return Hostkit.Metadata.Permissions_Supported;
   end Permissions_Supported;

   procedure For_Each_Directory_Entry (Path : String; Ok : out Boolean) is
      procedure Iterate is new Posix_Tools.Host_Adapters.File_System.Directories
        .For_Each_Directory_Entry (Action);
   begin
      Iterate (Path, Ok);
   end For_Each_Directory_Entry;

   function Physical_Current_Directory return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Physical_Current_Directory;
   end Physical_Current_Directory;

   function Try_Physical_Current_Directory (Path : out String; Last : out Natural) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Try_Physical_Current_Directory
        (Path, Last);
   end Try_Physical_Current_Directory;

   function Path_Names_Current_Directory (Path : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Path_Names_Current_Directory
        (Path);
   end Path_Names_Current_Directory;

   function Read_Link_Target (Path : String; Target : out Ada.Strings.Unbounded.Unbounded_String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Read_Link_Target
        (Path, Target);
   end Read_Link_Target;

   function Real_Path (Path : String) return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Real_Path (Path);
   end Real_Path;

   procedure Rename (Old_Path : String; New_Path : String) is
   begin
      Posix_Tools.Host_Adapters.File_System.Paths.Rename (Old_Path, New_Path);
   end Rename;

   function Same_File (Left : String; Right : String) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Same_File (Left, Right);
   end Same_File;

   function Set_Modification_Time (Path : String; Time : File_Time) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Set_Modification_Time
        (Path, Time);
   end Set_Modification_Time;

   function Set_Access_Time (Path : String; Time : File_Time) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Set_Access_Time
        (Path, Time);
   end Set_Access_Time;

   function Set_File_Times (Path : String; Access_Time, Modified_Time : File_Time) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Times.Set_File_Times
        (Path, Access_Time, Modified_Time);
   end Set_File_Times;

   function Set_Ownership (Path : String; User : Natural; Group : Natural) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Directories.Set_Ownership
        (Path, User, Group);
   end Set_Ownership;

   function Set_Permissions (Path : String; Mode : Natural) return Boolean is
   begin
      return Posix_Tools.Host_Adapters.File_System.Directories.Set_Permissions
        (Path, Mode);
   end Set_Permissions;

   function Simple_Name (Path : String) return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Paths.Simple_Name (Path);
   end Simple_Name;

   function Allocated_Size (Path : String; Available : out Boolean) return Long_Long_Integer is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Allocated_Size
        (Path, Available);
   end Allocated_Size;

   function Size (Path : String) return Long_Long_Integer is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Size (Path);
   end Size;

   function Special_File_Info_Of (Path : String) return Special_File_Info is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.Special_File_Info_Of
        (Path);
   end Special_File_Info_Of;

   function User_Id_For_Name (Name : String; Found : out Boolean) return Natural is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.User_Id_For_Name
        (Name, Found);
   end User_Id_For_Name;

   function User_Name_For_Id (Id : Natural) return String is
   begin
      return Posix_Tools.Host_Adapters.File_System.Metadata.User_Name_For_Id (Id);
   end User_Name_For_Id;
end Posix_Tools.Host_Adapters.File_System;
