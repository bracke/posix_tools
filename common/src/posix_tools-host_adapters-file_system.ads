with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Calendar;
with Interfaces;
private with GNAT.OS_Lib;

package Posix_Tools.Host_Adapters.File_System is
   type File_Kind is (Missing_File, Directory, Ordinary_File, Special_File);
   type Special_File_Kind is
     (Not_Special,
      FIFO,
      Character_Device,
      Block_Device,
      Socket,
      Other_Special);
   type Special_File_Info is record
      Available : Boolean := False;
      Kind      : Special_File_Kind := Not_Special;
      Device    : Interfaces.Unsigned_64 := 0;
      Mode      : Natural := 0;
   end record;
   type Volume_Capacity is record
      Available      : Boolean := False;
      Capacity_Bytes : Long_Long_Integer := 0;
      Free_Bytes     : Long_Long_Integer := 0;
   end record;
   type Copy_File_Status is
     (Copy_Ok,
      Source_Open_Failed,
      Target_Open_Failed,
      Source_Read_Failed,
      Target_Write_Failed);
   type File_Time is private;

   function Can_Open_For_Read (Path : String) return Boolean;
   function Containing_Directory (Path : String) return String;
   function Copy_File_Times (Source : String; Target : String) return Boolean;
   function Copy_Modification_Time (Source : String; Target : String) return Boolean;
   procedure Copy_Regular_File (Source : String; Target : String; Status : out Copy_File_Status);
   function Create_Device
     (Path   : String;
      Kind   : Special_File_Kind;
      Device : Interfaces.Unsigned_64;
      Mode   : Natural) return Boolean;
   procedure Create_Directory (Path : String);
   function Create_FIFO (Path : String; Mode : Natural) return Boolean;
   function Create_Socket (Path : String; Mode : Natural) return Boolean;
   function Create_Hard_Link (Source : String; Target : String) return Boolean;
   function Create_Link (Source : String; Target : String) return Boolean;
   procedure Create_Path (Path : String);
   procedure Delete_Directory (Path : String);
   procedure Delete_File (Path : String);
   function Delete_Link (Path : String) return Boolean;
   procedure Delete_Tree (Path : String);
   function Device_Id (Path : String; Available : out Boolean) return Long_Long_Integer;
   function Exists (Path : String) return Boolean;
   procedure File_Ownership
     (Path      : String;
      User      : out Natural;
      Group     : out Natural;
      Available : out Boolean);
   function File_Permission_Bits (Path : String; Available : out Boolean) return Natural;
   function File_Name_Limit (Path : String; Available : out Boolean) return Natural;
   function File_System_Capacity (Path : String) return Volume_Capacity;
   function Path_Name_Limit (Path : String; Available : out Boolean) return Natural;
   function Full_Name (Path : String) return String;
   function Group_Id_For_Name (Name : String; Found : out Boolean) return Natural;
   function Group_Name_For_Id (Id : Natural) return String;
   function Group_Name_For_Current_User return String;
   function Is_Link (Path : String) return Boolean;
   function Join (Left : String; Right : String) return String;
   function Kind (Path : String) return File_Kind;
   function Current_File_Time return File_Time;
   function File_Time_From_File (Path : String; Time : out File_Time) return Boolean;
   function File_Access_Time_From_File (Path : String; Time : out File_Time) return Boolean;
   function Access_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean;
   function Creation_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean;
   function File_Time_Of
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Time   : out File_Time) return Boolean;
   function Modification_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean;
   function Ownership_Supported return Boolean;
   function Permissions_Supported return Boolean;

   function Path_Names_Current_Directory (Path : String) return Boolean;
   function Read_Link_Target (Path : String; Target : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   function Real_Path (Path : String) return String;
   procedure Rename (Old_Path : String; New_Path : String);
   function Same_File (Left : String; Right : String) return Boolean;
   function Set_Modification_Time (Path : String; Time : File_Time) return Boolean;
   function Set_Access_Time (Path : String; Time : File_Time) return Boolean;
   function Set_File_Times (Path : String; Access_Time, Modified_Time : File_Time) return Boolean;
   function Set_Ownership (Path : String; User : Natural; Group : Natural) return Boolean;
   function Set_Permissions (Path : String; Mode : Natural) return Boolean;
   function Simple_Name (Path : String) return String;
   function Allocated_Size (Path : String; Available : out Boolean) return Long_Long_Integer;
   function Size (Path : String) return Long_Long_Integer;
   function Special_File_Info_Of (Path : String) return Special_File_Info;
   function User_Id_For_Name (Name : String; Found : out Boolean) return Natural;
   function User_Name_For_Id (Id : Natural) return String;

   generic
      with procedure Action
        (Name      : String;
         Full_Name : String;
         Stop      : in out Boolean);
   procedure For_Each_Directory_Entry (Path : String; Ok : out Boolean);

   generic
      with procedure Action
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);
   procedure For_Each_File_Chunk
     (Path   : String;
      Ok     : out Boolean);

   generic
      with procedure Action
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);
   procedure For_Each_File_Chunk_From
     (Path   : String;
      Offset : Long_Long_Integer;
      Ok     : out Boolean);

   function Physical_Current_Directory return String;
   function Try_Physical_Current_Directory (Path : out String; Last : out Natural) return Boolean;

private
   type File_Time is new GNAT.OS_Lib.OS_Time;
end Posix_Tools.Host_Adapters.File_System;
