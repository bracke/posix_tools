with Ada.Streams;
with Ada.Strings.Unbounded;
with Ada.Calendar;
with Interfaces;
with Posix_Tools.Accounts;
private with GNAT.OS_Lib;
private with Hostkit.Descriptors;
private with Hostkit.Metadata;

package Posix_Tools.Host_Adapters.File_System is
   --  The kind of the file Path resolves to.  Uninspectable_File keeps an
   --  access or metadata failure distinct from a genuinely absent file
   --  without making every ordinary kind query an exception boundary.
   type File_Kind is
     (Missing_File,
      Uninspectable_File,
      Directory,
      Ordinary_File,
      Special_File);
   --  The kind of a directory entry itself, without following a symbolic
   --  link. Unlike File_Kind, this distinguishes links.
   type Entry_Kind is
     (Entry_Missing,
      Entry_Error,
      Entry_Link,
      Entry_Directory,
      Entry_Regular,
      Entry_Special);
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
      Target_Write_Failed,
      --  The caller asked the copy to stop; the target holds what was copied.
      Copy_Stopped);
   --  How a move in one step went: made, refused, or one the host can only
   --  make by copying and removing, as between two file systems.
   type Move_Outcome is (Moved, Move_Needs_Copy, Move_Refused);
   type File_Time is private;
   type Follow_File is limited private;
   type Follow_Open_Status is (Follow_Ready, Follow_Missing, Follow_Error);

   function Can_Open_For_Read (Path : String) return Boolean;
   --  The directory holding Path, as Ada.Directories names it; empty when
   --  Path has none.
   function Containing_Directory (Path : String) return String;
   function Copy_File_Times (Source : String; Target : String) return Boolean;
   --  Copy the regular file Source to Target, calling Progress with the
   --  bytes copied so far after each block; setting Stop ends the copy with
   --  Copy_Stopped.
   generic
      with procedure Progress (Copied : Long_Long_Integer; Stop : in out Boolean);
   procedure Copy_Regular_File_With_Progress (Source : String; Target : String; Status : out Copy_File_Status);
   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean);
   function Create_Device
     (Path   : String;
      Kind   : Special_File_Kind;
      Device : Interfaces.Unsigned_64;
      Mode   : Natural) return Boolean;
   --  Make the directory Path; False when the host would not.
   function Create_Directory (Path : String) return Boolean;
   --  The raising form of Create_Directory, for test set-up, where a
   --  failure is an error.
   procedure Create_Directory (Path : String);
   function Create_FIFO (Path : String; Mode : Natural) return Boolean;
   function Create_Socket (Path : String; Mode : Natural) return Boolean;
   function Create_Hard_Link (Source : String; Target : String) return Boolean;
   function Create_Link (Source : String; Target : String) return Boolean;
   --  Make the directory Path and any missing directories above it; False
   --  when the host would not.
   function Create_Path (Path : String) return Boolean;
   --  The raising form of Create_Path, for test set-up.
   procedure Create_Path (Path : String);
   --  Remove the empty directory Path; False when the host would not.
   function Delete_Directory (Path : String) return Boolean;
   --  Remove the file Path, not a directory; False when the host would not.
   function Delete_File (Path : String) return Boolean;
   function Delete_Link (Path : String) return Boolean;
   function Device_Id (Path : String; Available : out Boolean) return Long_Long_Integer;
   function Exists (Path : String) return Boolean;
   --  The directory holding the running program's own executable, as the
   --  host reports it rather than as it was invoked, or "" where the host
   --  will not say: for a command that finds its data files beside itself.
   function Executable_Directory return String;
   procedure File_Ownership
     (Path      : String;
      User      : out Posix_Tools.Accounts.Id;
      Group     : out Posix_Tools.Accounts.Id;
      Available : out Boolean);
   function File_Permission_Bits (Path : String; Available : out Boolean) return Natural;

   --  The file mode creation mask, the umask: 0 where the host has none.
   function Creation_Mask return Natural;
   function File_Name_Limit (Path : String; Available : out Boolean) return Natural;
   function File_System_Capacity (Path : String) return Volume_Capacity;
   function Path_Name_Limit (Path : String; Available : out Boolean) return Natural;
   function Full_Name (Path : String) return String;
   function Group_Id_For_Name
     (Name : String; Found : out Boolean) return Posix_Tools.Accounts.Id;
   function Group_Name_For_Id (Id : Posix_Tools.Accounts.Id) return String;
   function Is_Link (Path : String) return Boolean;
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

   --  A child's pathname as POSIX forms it: the parent, a '/', and the name,
   --  with no second separator when the parent already ends in one (either
   --  spelling, on a host whose own is '\').
   function Child_Path (Parent : String; Name : String) return String;
   function Path_Names_Current_Directory (Path : String) return Boolean;
   function Read_Link_Target (Path : String; Target : out Ada.Strings.Unbounded.Unbounded_String) return Boolean;
   function Real_Path (Path : String) return String;
   --  Rename Old_Path to New_Path; False when the host would not.
   function Rename (Old_Path : String; New_Path : String) return Boolean;
   --  Move Old_Path to New_Path in one step, replacing what New_Path names
   --  as rename(2) does: a file, or an empty directory with a directory.
   function Move_Entry (Old_Path : String; New_Path : String) return Move_Outcome;
   function Same_File (Left : String; Right : String) return Boolean;
   function Set_File_Times (Path : String; Access_Time, Modified_Time : File_Time) return Boolean;
   function Set_Ownership
     (Path  : String;
      User  : Posix_Tools.Accounts.Update;
      Group : Posix_Tools.Accounts.Update) return Boolean;
   --  Change the entry Path names only when it is not a symbolic link.  The
   --  host pins the entry before changing it, so replacement of the final
   --  pathname component cannot redirect the operation.
   function Set_Ownership_No_Follow
     (Path  : String;
      User  : Posix_Tools.Accounts.Update;
      Group : Posix_Tools.Accounts.Update;
      Beneath_Root  : String := "";
      Relative_Path : String := "") return Boolean;
   function Set_Permissions (Path : String; Mode : Natural) return Boolean;
   function Set_Permissions_No_Follow
     (Path          : String;
      Mode          : Natural;
      Beneath_Root  : String := "";
      Relative_Path : String := "") return Boolean;
   --  Allocated bytes when the host exposes them, otherwise the logical byte
   --  size. Available distinguishes the two without requiring a second query.
   function Allocated_Size (Path : String; Available : out Boolean) return Long_Long_Integer
     with Post => Allocated_Size'Result >= 0;
   function Size (Path : String) return Long_Long_Integer
     with Post => Size'Result >= 0;
   --  A file held open across tail -f polling. Reads advance the retained
   --  position, so a rename or unlink does not redirect descriptor following.
   --  Seekable regular files retain a small exact boundary window to recognize
   --  common in-place rewrites. A rewrite completed between polls that preserves
   --  that window is indistinguishable from an append and resumes at the old
   --  logical position. Sequential special files are never repositioned.
   procedure Open_Follow_File
     (Path             : String;
      File             : in out Follow_File;
      Status           : out Follow_Open_Status;
      Require_Identity : Boolean := False);
   procedure Refresh_Follow_File
     (Path     : String;
      File     : in out Follow_File;
      Reopened : out Boolean;
      Status   : out Follow_Open_Status);
   function Follow_File_Is_Open (File : Follow_File) return Boolean;
   procedure Close_Follow_File (File : in out Follow_File);
   function Special_File_Info_Of (Path : String) return Special_File_Info;
   function User_Id_For_Name
     (Name : String; Found : out Boolean) return Posix_Tools.Accounts.Id;
   function User_Name_For_Id (Id : Posix_Tools.Accounts.Id) return String;

   generic
      with procedure Action
        (Name      : String;
         Full_Name : String;
         Stop      : in out Boolean);
   procedure For_Each_Directory_Entry (Path : String; Ok : out Boolean);

   --  What a directory records about one of its entries, without following
   --  a link. Listed_Unknown where the filesystem does not record it.
   type Listed_Kind is (Listed_Regular, Listed_Directory, Listed_Link, Listed_Other, Listed_Unknown);

   --  Each entry of a directory but . and .., in the order the directory gives
   --  them, with its kind as the directory records it -- no query per entry.
   generic
      with procedure Action
        (Name : String;
         Kind : Listed_Kind;
         Stop : in out Boolean);
   procedure For_Each_Listed_Entry (Path : String; Ok : out Boolean);

   --  An entry's own status -- a symbolic link's, not its target's -- from a
   --  single query of the host. Fields the host does not have are zero.
   type Entry_Status is record
      Available        : Boolean := False;
      Size             : Long_Long_Integer := 0;
      --  Whole seconds since 1970-01-01 UTC.
      Modified_Seconds : Long_Long_Integer := 0;
      --  The host's mode word, file type bits included where the host has
      --  them; the permission bits are Mode mod 8#10000#.
      Mode             : Natural := 0;
      User             : Posix_Tools.Accounts.Id := 0;
      Group            : Posix_Tools.Accounts.Id := 0;
   end record;

   --  A stable identity for one directory entry. Available is False when the
   --  host cannot distinguish the entry from a later reuse of its file number.
   type Entry_Identity is record
      Available       : Boolean := False;
      Volume          : Interfaces.Unsigned_64 := 0;
      File_Number     : Interfaces.Unsigned_64 := 0;
      Generation_High : Interfaces.Unsigned_64 := 0;
      Generation_Low  : Interfaces.Unsigned_64 := 0;
   end record;

   --  Inspect Path itself, without following a symbolic link.
   function Entry_Identity_Of (Path : String) return Entry_Identity;
   function Entry_Kind_Of (Path : String) return Entry_Kind;
   function Entry_Status_Of (Path : String) return Entry_Status;
   --  Inspect the file Path resolves to, following a symbolic link.
   function File_Status_Of (Path : String) return Entry_Status;

   generic
      with procedure Action
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);
      Buffer_Length : Positive := 16 * 1024;
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
      Ok     : out Boolean)
     with Pre => Offset >= 0;

   generic
      with procedure Action
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);
   procedure For_Each_Follow_Chunk
     (File : in out Follow_File;
      Ok   : out Boolean);

   function Physical_Current_Directory return String;
   function Try_Physical_Current_Directory (Path : out String; Last : out Natural) return Boolean
     with
       Post =>
         (if Try_Physical_Current_Directory'Result then
            Last <= Path'Length
          else
            Last = 0);

private
   type File_Time is new GNAT.OS_Lib.OS_Time;
   Follow_History_Capacity : constant := 64;
   subtype Follow_History_Index is Positive range 1 .. Follow_History_Capacity;
   type Follow_History_Buffer is array (Follow_History_Index) of Ada.Streams.Stream_Element;
   type Follow_Handle_Kind is
     (Follow_Closed, Follow_Seekable, Follow_Sequential);
   type Follow_File is limited record
      Handle         : Hostkit.Descriptors.Descriptor :=
        Hostkit.Descriptors.Invalid;
      Identity       : Hostkit.Metadata.Entry_Identity;
      Cursor         : Long_Long_Integer := 0;
      Handle_Kind    : Follow_Handle_Kind := Follow_Closed;
      Sequential_Non_Blocking : Boolean := False;
      History        : Follow_History_Buffer := [others => 0];
      History_Length : Natural range 0 .. Follow_History_Capacity := 0;
      History_Next   : Follow_History_Index := Follow_History_Index'First;
   end record;
end Posix_Tools.Host_Adapters.File_System;
