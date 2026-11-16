with Ada.Directories;
with Ada.IO_Exceptions;
with Ada.Streams.Stream_IO;
with Hostkit.Directory_Listing;
with Hostkit.Fs;
with Posix_Tools.Unix_Time;

package body Posix_Tools.Host_Adapters.File_System is
   use type Ada.Streams.Stream_Element_Offset;

   Buffer_Size : constant := 16 * 1024;
   Bulk_Buffer_Size : constant := 64 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);
   subtype Bulk_Byte_Buffer is
     Ada.Streams.Stream_Element_Array (1 .. Bulk_Buffer_Size);

   generic
      with procedure Callback
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);
   procedure Invoke_Chunk_Callback
     (Buffer          : Ada.Streams.Stream_Element_Array;
      Last            : Ada.Streams.Stream_Element_Offset;
      Stop            : in out Boolean;
      Callback_Active : not null access Boolean);

   procedure Invoke_Chunk_Callback
     (Buffer          : Ada.Streams.Stream_Element_Array;
      Last            : Ada.Streams.Stream_Element_Offset;
      Stop            : in out Boolean;
      Callback_Active : not null access Boolean)
   is
   begin
      Callback_Active.all := True;
      Callback (Buffer, Last, Stop);
      Callback_Active.all := False;
   end Invoke_Chunk_Callback;

   generic
      with procedure Callback
        (Name      : String;
         Full_Name : String;
         Stop      : in out Boolean);
   procedure Invoke_Directory_Callback
     (Name            : String;
      Full_Name       : String;
      Stop            : in out Boolean;
      Callback_Active : not null access Boolean);

   procedure Invoke_Directory_Callback
     (Name            : String;
      Full_Name       : String;
      Stop            : in out Boolean;
      Callback_Active : not null access Boolean)
   is
   begin
      Callback_Active.all := True;
      Callback (Name, Full_Name, Stop);
      Callback_Active.all := False;
   end Invoke_Directory_Callback;

   --  Whole seconds since 1970-01-01 UTC.
   function Epoch_Seconds (Time : File_Time) return Long_Long_Integer;

   --  Whether following Path, a link, reaches a file that exists.
   function Path_Identity
     (Path     : String;
      Identity : out Hostkit.Metadata.Entry_Identity) return Follow_Open_Status;

   function Path_Identity
     (Path     : String;
      Identity : out Hostkit.Metadata.Entry_Identity) return Follow_Open_Status
   is
   begin
      Identity := (others => <>);
      if not Ada.Directories.Exists (Path) then
         return Follow_Missing;
      end if;

      declare
         Resolved : constant String := Hostkit.Fs.Real_Path (Path);
      begin
         if Resolved = "" then
            --  Real_Path cannot distinguish a resolution failure from a
            --  pathname that disappeared while it was being resolved.
            return
              (if Ada.Directories.Exists (Path) then
                  Follow_Error
               else
                  Follow_Missing);
         elsif not Ada.Directories.Exists (Resolved) then
            return Follow_Missing;
         end if;

         Identity := Hostkit.Metadata.Entry_Identity_Of (Resolved);
         return Follow_Ready;
      end;
   exception
      when Ada.IO_Exceptions.Name_Error =>
         Identity := (others => <>);
         return Follow_Missing;
      when others =>
         --  intentional terminal exception barrier
         Identity := (others => <>);
         return Follow_Error;
   end Path_Identity;

   function Access_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
      Available : Boolean := False;
   begin
      Time := Hostkit.Metadata.File_Access_Time (Path, Available);
      return Available;
   exception
      when others =>
         --  intentional terminal exception barrier
         Time := Ada.Calendar.Time_Of (1901, 1, 1);
         return False;
   end Access_Time;

   function Allocated_Size (Path : String; Available : out Boolean) return Long_Long_Integer is
   begin
      --  Hostkit's public metadata surface does not yet expose per-file allocated
      --  block counts. Keep the capability explicit while returning the portable
      --  byte-size fallback from this same query.
      Available := False;
      return Long_Long_Integer (Hostkit.Fs.Size_Of (Path));
   end Allocated_Size;

   function Can_Open_For_Read (Path : String) return Boolean is
      use Hostkit.Descriptors;
      File : Descriptor := Invalid;
   begin
      if not Open_File (Path, Open_Read, File) then
         return False;
      end if;

      Close (File);
      return True;
   exception
      when others =>
         Close (File);
         return False;
   end Can_Open_For_Read;

   function Child_Path (Parent : String; Name : String) return String is
      Joined : constant Boolean :=
        Parent'Length > 0
        and then (Parent (Parent'Last) = '/'
                  or else Parent (Parent'Last) = GNAT.OS_Lib.Directory_Separator);
   begin
      return Parent & (if Joined then "" else "/") & Name;
   end Child_Path;

   function Containing_Directory (Path : String) return String is
   begin
      return Ada.Directories.Containing_Directory (Path);
   exception
      when others =>
         return "";
   end Containing_Directory;

   function Copy_File_Times (Source : String; Target : String) return Boolean is
      Source_Access_Time       : File_Time;
      Source_Modification_Time : File_Time;
   begin
      if not File_Access_Time_From_File (Source, Source_Access_Time)
        or else not File_Time_From_File (Source, Source_Modification_Time)
      then
         return False;
      end if;

      return Set_File_Times (Target, Source_Access_Time, Source_Modification_Time);
   exception
      when others =>
         return False;
   end Copy_File_Times;

   procedure Copy_Regular_File_With_Progress
     (Source : String;
      Target : String;
      Status : out Copy_File_Status) is separate;

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

   function Create_Directory (Path : String) return Boolean is
   begin
      Ada.Directories.Create_Directory (Path);
      return True;
   exception
      when others =>
         return False;
   end Create_Directory;

   procedure Create_Directory (Path : String) is
   begin
      Ada.Directories.Create_Directory (Path);
   end Create_Directory;

   function Create_FIFO (Path : String; Mode : Natural) return Boolean is
   begin
      return Hostkit.Fs.Create_FIFO (Path, Mode);
   end Create_FIFO;

   function Create_Hard_Link (Source : String; Target : String) return Boolean is
   begin
      return Hostkit.Fs.Create_Hard_Link (Source, Target);
   end Create_Hard_Link;

   function Create_Link (Source : String; Target : String) return Boolean is
   begin
      return Hostkit.Fs.Create_Link (Source, Target);
   end Create_Link;

   function Create_Path (Path : String) return Boolean is
   begin
      Ada.Directories.Create_Path (Path);
      return True;
   exception
      when others =>
         return False;
   end Create_Path;

   procedure Create_Path (Path : String) is
   begin
      Ada.Directories.Create_Path (Path);
   end Create_Path;

   function Create_Socket (Path : String; Mode : Natural) return Boolean is
   begin
      return Hostkit.Fs.Create_Socket (Path, Mode);
   end Create_Socket;

   function Creation_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
      Available : Boolean := False;
   begin
      Time := Hostkit.Metadata.File_Creation_Time (Path, Available);
      return Available;
   exception
      when others =>
         --  intentional terminal exception barrier
         Time := Ada.Calendar.Time_Of (1901, 1, 1);
         return False;
   end Creation_Time;

   function Current_File_Time return File_Time is
   begin
      return File_Time (GNAT.OS_Lib.Current_Time);
   end Current_File_Time;

   function Delete_Directory (Path : String) return Boolean is
   begin
      Ada.Directories.Delete_Directory (Path);
      return True;
   exception
      when others =>
         return False;
   end Delete_Directory;

   function Delete_File (Path : String) return Boolean is
      Deleted : Boolean := False;
   begin
      GNAT.OS_Lib.Delete_File (Path, Deleted);
      if not Deleted then
         Ada.Directories.Delete_File (Path);
      end if;
      return True;
   exception
      when others =>
         return False;
   end Delete_File;

   function Delete_Link (Path : String) return Boolean is
   begin
      return Hostkit.Fs.Delete_Link (Path);
   end Delete_Link;

   function Device_Id (Path : String; Available : out Boolean) return Long_Long_Integer is
   begin
      return Hostkit.Metadata.Device_Id (Path, Available);
   end Device_Id;

   function Entry_Identity_Of (Path : String) return Entry_Identity is
      Native : constant Hostkit.Metadata.Entry_Identity :=
        Hostkit.Metadata.Entry_Identity_Of (Path);
   begin
      return
        (Available       => Native.Available,
         Volume          => Native.Volume,
         File_Number     => Native.File_Number,
         Generation_High => Native.Generation_High,
         Generation_Low  => Native.Generation_Low);
   exception
      when others =>
         return (others => <>);
   end Entry_Identity_Of;

   function Entry_Kind_Of (Path : String) return Entry_Kind is
      Status    : constant Entry_Status := Entry_Status_Of (Path);
      Type_Code : constant Natural :=
        (if Status.Available then (Status.Mode / 8#10000#) mod 16 else 0);

      function Portable_Kind return Entry_Kind;

      function Portable_Kind return Entry_Kind is
      begin
         if Hostkit.Fs.Entry_Is_Absent (Path) then
            return Entry_Missing;
         elsif Hostkit.Fs.Is_Link (Path) then
            return Entry_Link;
         end if;

         case Ada.Directories.Kind (Path) is
            when Ada.Directories.Directory =>
               return Entry_Directory;
            when Ada.Directories.Ordinary_File =>
               return Entry_Regular;
            when Ada.Directories.Special_File =>
               return Entry_Special;
         end case;
      exception
         when Ada.Directories.Name_Error =>
            return Entry_Missing;
         when others =>
            return Entry_Error;
      end Portable_Kind;
   begin
      case Type_Code is
         when 10 =>
            return Entry_Link;
         when 4 =>
            return Entry_Directory;
         when 8 =>
            return Entry_Regular;
         when 0 =>
            --  Hosts without mode type bits retain the portable probes.  The
            --  absence query is deliberately separate: Exists-style Boolean
            --  probes cannot distinguish ENOENT from access refusal.
            return Portable_Kind;
         when others =>
            return Entry_Special;
      end case;
   exception
      when Ada.Directories.Name_Error =>
         return Entry_Missing;
      when others =>
         return Entry_Error;
   end Entry_Kind_Of;

   function Entry_Status_Of (Path : String) return Entry_Status is
      use type Hostkit.Metadata.Identity_Field;

      Native  : constant Hostkit.Metadata.Entry_Status :=
        Hostkit.Metadata.Entry_Status_Of (Path);
      Largest  : constant Hostkit.Metadata.Identity_Field := Hostkit.Metadata.Identity_Field (Long_Long_Integer'Last);

      function Clamped (Value : Hostkit.Metadata.Identity_Field) return Long_Long_Integer is
        (Long_Long_Integer (Hostkit.Metadata.Identity_Field'Min (Value, Largest)));
   begin
      if not Native.Available then
         return (others => <>);
      end if;
      return
        (Available        => True,
         Size             => Clamped (Native.Size),
         Modified_Seconds => Native.Modified_Seconds,
         Mode             => Native.Mode,
         User             => Posix_Tools.Accounts.Id (Native.User_Id),
         Group            => Posix_Tools.Accounts.Id (Native.Group_Id));
   exception
      when others =>
         return (others => <>);
   end Entry_Status_Of;

   function File_Status_Of (Path : String) return Entry_Status is
      use type Hostkit.Metadata.Identity_Field;

      Native  : constant Hostkit.Metadata.Entry_Status :=
        Hostkit.Metadata.File_Status_Of (Path);
      Largest : constant Hostkit.Metadata.Identity_Field :=
        Hostkit.Metadata.Identity_Field (Long_Long_Integer'Last);
   begin
      if not Native.Available then
         return (others => <>);
      end if;
      return
        (Available        => True,
         Size             =>
           Long_Long_Integer
             (Hostkit.Metadata.Identity_Field'Min (Native.Size, Largest)),
         Modified_Seconds => Native.Modified_Seconds,
         Mode             => Native.Mode,
         User             => Posix_Tools.Accounts.Id (Native.User_Id),
         Group            => Posix_Tools.Accounts.Id (Native.Group_Id));
   exception
      when others =>
         return (others => <>);
   end File_Status_Of;

   function Epoch_Seconds (Time : File_Time) return Long_Long_Integer is
      Year   : GNAT.OS_Lib.Year_Type;
      Month  : GNAT.OS_Lib.Month_Type;
      Day    : GNAT.OS_Lib.Day_Type;
      Hour   : GNAT.OS_Lib.Hour_Type;
      Minute : GNAT.OS_Lib.Minute_Type;
      Second : GNAT.OS_Lib.Second_Type;
   begin
      GNAT.OS_Lib.GM_Split (GNAT.OS_Lib.OS_Time (Time), Year, Month, Day, Hour, Minute, Second);
      return Posix_Tools.Unix_Time.Seconds_Of (Year, Month, Day, Hour, Minute, Second);
   end Epoch_Seconds;

   function Executable_Directory return String is
   begin
      return Hostkit.Fs.Own_Executable_Directory;
   exception
      when others =>
         return "";
   end Executable_Directory;

   function Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   exception
      when Ada.Directories.Name_Error =>
         --  Not a pathname at all, as the empty one: nothing it names exists.
         return False;
   end Exists;

   function File_Access_Time_From_File (Path : String; Time : out File_Time) return Boolean is
      Available : Boolean;
      Value     : constant Ada.Calendar.Time := Hostkit.Metadata.File_Access_Time (Path, Available);
      Year      : Ada.Calendar.Year_Number;
      Month     : Ada.Calendar.Month_Number;
      Day       : Ada.Calendar.Day_Number;
      Seconds   : Duration;
      Whole     : Natural;
   begin
      Ada.Calendar.Split (Value, Year, Month, Day, Seconds);
      Whole := Natural (Seconds);
      Time :=
        File_Time
          (GNAT.OS_Lib.GM_Time_Of
             (GNAT.OS_Lib.Year_Type (Year),
              GNAT.OS_Lib.Month_Type (Month),
              GNAT.OS_Lib.Day_Type (Day),
              GNAT.OS_Lib.Hour_Type (Whole / 3_600),
              GNAT.OS_Lib.Minute_Type ((Whole mod 3_600) / 60),
              GNAT.OS_Lib.Second_Type (Whole mod 60)));
      return Available;
   exception
      when others =>
         --  intentional terminal exception barrier
         Time := Current_File_Time;
         return False;
   end File_Access_Time_From_File;

   function File_Name_Limit (Path : String; Available : out Boolean) return Natural is
      Capacity : constant Hostkit.Metadata.Volume_Capacity := Hostkit.Metadata.Volume_Capacity_Of (Path);
   begin
      Available := Capacity.Available and then Capacity.Name_Max_Known;
      return (if Available then Capacity.Name_Max else 0);
   end File_Name_Limit;

   procedure File_Ownership
     (Path      : String;
      User      : out Posix_Tools.Accounts.Id;
      Group     : out Posix_Tools.Accounts.Id;
      Available : out Boolean)
   is
      Host_User  : Hostkit.Metadata.Account_Id;
      Host_Group : Hostkit.Metadata.Account_Id;
   begin
      Hostkit.Metadata.File_Ownership
        (Path, Host_User, Host_Group, Available);
      User := Posix_Tools.Accounts.Id (Host_User);
      Group := Posix_Tools.Accounts.Id (Host_Group);
   end File_Ownership;

   function File_Permission_Bits (Path : String; Available : out Boolean) return Natural is
   begin
      return Hostkit.Metadata.File_Permission_Bits (Path, Available);
   end File_Permission_Bits;

   function Creation_Mask return Natural is
      Value : Natural;
   begin
      return (if Hostkit.Fs.Creation_Mask (Value) then Value mod 8#1000# else 0);
   end Creation_Mask;

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

   function File_Time_From_File (Path : String; Time : out File_Time) return Boolean is
   begin
      Time := File_Time (GNAT.OS_Lib.File_Time_Stamp (Path));
      return True;
   exception
      when others =>
         --  intentional terminal exception barrier
         Time := Current_File_Time;
         return False;
   end File_Time_From_File;

   function File_Time_Of
     (Year   : Natural;
      Month  : Natural;
      Day    : Natural;
      Hour   : Natural;
      Minute : Natural;
      Second : Natural;
      Time   : out File_Time) return Boolean
   is
      use type GNAT.OS_Lib.OS_Time;
      Candidate : GNAT.OS_Lib.OS_Time;
   begin
      Candidate :=
        GNAT.OS_Lib.GM_Time_Of
          (GNAT.OS_Lib.Year_Type (Year),
           GNAT.OS_Lib.Month_Type (Month),
           GNAT.OS_Lib.Day_Type (Day),
           GNAT.OS_Lib.Hour_Type (Hour),
           GNAT.OS_Lib.Minute_Type (Minute),
           GNAT.OS_Lib.Second_Type (Second));
      Time := File_Time (Candidate);
      return Candidate /= GNAT.OS_Lib.Invalid_Time;
   exception
      when others =>
         --  intentional terminal exception barrier
         Time := Current_File_Time;
         return False;
   end File_Time_Of;

   procedure For_Each_Directory_Entry (Path : String; Ok : out Boolean) is separate;

   procedure For_Each_File_Chunk
     (Path   : String;
      Ok     : out Boolean)
   is separate;

   procedure For_Each_File_Chunk_From
     (Path   : String;
      Offset : Long_Long_Integer;
      Ok     : out Boolean)
   is separate;

   procedure For_Each_Follow_Chunk
     (File : in out Follow_File;
      Ok   : out Boolean)
   is separate;

   procedure For_Each_Listed_Entry (Path : String; Ok : out Boolean) is
      Entries : Hostkit.Directory_Listing.Entry_Vectors.Vector;
      Stop    : Boolean := False;
   begin
      begin
         Ok := Hostkit.Directory_Listing.List (Path, Entries);
      exception
         when others =>
            --  intentional terminal exception barrier
            Ok := False;
      end;

      if not Ok then
         return;
      end if;

      for Item of Entries loop
         Action
           (Item.Name,
            (case Item.Kind is
               when Hostkit.Directory_Listing.Regular_File  => Listed_Regular,
               when Hostkit.Directory_Listing.Directory     => Listed_Directory,
               when Hostkit.Directory_Listing.Symbolic_Link => Listed_Link,
               when Hostkit.Directory_Listing.Other         => Listed_Other,
               when Hostkit.Directory_Listing.Unknown       => Listed_Unknown),
            Stop);
         exit when Stop;
      end loop;
   end For_Each_Listed_Entry;

   function Full_Name (Path : String) return String is
   begin
      return Ada.Directories.Full_Name (Path);
   end Full_Name;

   function Group_Id_For_Name
     (Name : String; Found : out Boolean) return Posix_Tools.Accounts.Id
   is
      Host_Id : Hostkit.Metadata.Account_Id;
   begin
      Host_Id := Hostkit.Metadata.Group_Id_For_Name (Name, Found);
      return Posix_Tools.Accounts.Id (Host_Id);
   end Group_Id_For_Name;

   function Group_Name_For_Id (Id : Posix_Tools.Accounts.Id) return String is
   begin
      return Hostkit.Metadata.Group_Name_For_Id
        (Hostkit.Metadata.Account_Id (Id));
   end Group_Name_For_Id;

   function Is_Link (Path : String) return Boolean is
   begin
      return Hostkit.Fs.Is_Link (Path);
   end Is_Link;

   function Kind (Path : String) return File_Kind is
   begin
      case Entry_Kind_Of (Path) is
         when Entry_Missing =>
            return Missing_File;
         when Entry_Error =>
            return Uninspectable_File;
         when Entry_Directory =>
            return Directory;
         when Entry_Regular =>
            return Ordinary_File;
         when Entry_Special =>
            return Special_File;
         when Entry_Link =>
            --  Use the resolved spelling where the host can provide it.  In
            --  particular, Windows otherwise describes a broken link as the
            --  link entry.  When resolution itself cannot produce a spelling,
            --  Ada.Directories.Kind retains the important distinction between
            --  a missing target (Name_Error) and an inaccessible one
            --  (Use_Error).
            declare
               Target : constant String := Hostkit.Fs.Real_Path (Path);
            begin
               if Target /= "" then
                  case Entry_Kind_Of (Target) is
                     when Entry_Missing =>
                        return Missing_File;
                     when Entry_Error =>
                        return Uninspectable_File;
                     when Entry_Directory =>
                        return Directory;
                     when Entry_Regular =>
                        return Ordinary_File;
                     when Entry_Special =>
                        return Special_File;
                     when Entry_Link =>
                        --  A native real-path result is not itself a link.
                        return Uninspectable_File;
                  end case;
               end if;

               case Ada.Directories.Kind (Path) is
                  when Ada.Directories.Directory =>
                     return Directory;
                  when Ada.Directories.Ordinary_File =>
                     return Ordinary_File;
                  when Ada.Directories.Special_File =>
                     return Special_File;
               end case;
            end;
      end case;
   exception
      when Ada.Directories.Name_Error =>
         return Missing_File;
      when others =>
         --  Kind is a query used pervasively by command dispatch.  Preserve
         --  inspection failure in its result instead of turning user input
         --  into the command runner's internal-failure status.
         return Uninspectable_File;
   end Kind;

   function Modification_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
   begin
      Time := Hostkit.Fs.Modification_Time_Of (Path);
      return True;
   exception
      when others =>
         --  intentional terminal exception barrier
         Time := Ada.Calendar.Time_Of (Year => 1901, Month => 1, Day => 1);
         return False;
   end Modification_Time;

   function Move_Entry (Old_Path : String; New_Path : String) return Move_Outcome is
   begin
      if Ada.Directories.Exists (New_Path) or else Hostkit.Fs.Is_Link (New_Path) then
         if Hostkit.Fs.Replace_File (Old_Path, New_Path) then
            return Moved;
         end if;

         --  The host says only that the replacing rename failed; whether a
         --  copy could stand in for it is told by the file systems.
         declare
            Old_Known, New_Known : Boolean;
            Old_Device : constant Long_Long_Integer := Hostkit.Metadata.Device_Id (Old_Path, Old_Known);
            New_Device : constant Long_Long_Integer := Hostkit.Metadata.Device_Id (New_Path, New_Known);
         begin
            return
              (if Old_Known and then New_Known and then Old_Device /= New_Device then Move_Needs_Copy
               else Move_Refused);
         end;
      end if;

      case Hostkit.Fs.Move_No_Replace_Outcome (Old_Path, New_Path) is
         when Hostkit.Fs.Moved =>
            return Moved;
         when Hostkit.Fs.Move_Cross_Device | Hostkit.Fs.Move_Unsupported =>
            return Move_Needs_Copy;
         when Hostkit.Fs.Move_Refused =>
            return Move_Refused;
      end case;
   end Move_Entry;

   function Ownership_Supported return Boolean is
   begin
      return Hostkit.Metadata.Ownership_Supported;
   end Ownership_Supported;

   function Path_Name_Limit (Path : String; Available : out Boolean) return Natural is
      pragma Unreferenced (Path);
   begin
      Available := False;
      return 0;
   end Path_Name_Limit;

   function Path_Names_Current_Directory (Path : String) return Boolean is
   begin
      return Hostkit.Metadata.Same_File (Path, Physical_Current_Directory);
   exception
      when others =>
         return False;
   end Path_Names_Current_Directory;

   function Permissions_Supported return Boolean is
   begin
      return Hostkit.Metadata.Permissions_Supported;
   end Permissions_Supported;

   function Physical_Current_Directory return String is
   begin
      return Ada.Directories.Current_Directory;
   end Physical_Current_Directory;

   function Read_Link_Target (Path : String; Target : out Ada.Strings.Unbounded.Unbounded_String) return Boolean is
   begin
      return Hostkit.Fs.Read_Link_Target (Path, Target);
   end Read_Link_Target;

   function Real_Path (Path : String) return String is
   begin
      return Hostkit.Fs.Real_Path (Path);
   end Real_Path;

   function Rename (Old_Path : String; New_Path : String) return Boolean is
   begin
      Ada.Directories.Rename (Old_Path, New_Path);
      return True;
   exception
      when others =>
         return False;
   end Rename;

   function Same_File (Left : String; Right : String) return Boolean is
   begin
      return Hostkit.Metadata.Same_File (Left, Right);
   end Same_File;

   function Set_File_Times (Path : String; Access_Time, Modified_Time : File_Time) return Boolean is
   begin
      return Hostkit.Metadata.Set_File_Times
        (Path,
         Epoch_Seconds (Access_Time),
         Epoch_Seconds (Modified_Time));
   exception
      when others =>
         return False;
   end Set_File_Times;

   function Set_Ownership
     (Path  : String;
      User  : Posix_Tools.Accounts.Update;
      Group : Posix_Tools.Accounts.Update) return Boolean
   is
   begin
      return Hostkit.Metadata.Set_Ownership
        (Path,
         Hostkit.Metadata.Account_Id
           (Posix_Tools.Accounts.Value_Or_Keep (User)),
         Hostkit.Metadata.Account_Id
           (Posix_Tools.Accounts.Value_Or_Keep (Group)));
   end Set_Ownership;

   function Set_Ownership_No_Follow
     (Path  : String;
      User  : Posix_Tools.Accounts.Update;
      Group : Posix_Tools.Accounts.Update;
      Beneath_Root  : String := "";
      Relative_Path : String := "") return Boolean
   is
      use type Posix_Tools.Accounts.Id;
      User_Id : constant Posix_Tools.Accounts.Id :=
        Posix_Tools.Accounts.Value_Or_Keep (User);
      Group_Id : constant Posix_Tools.Accounts.Id :=
        Posix_Tools.Accounts.Value_Or_Keep (Group);
      Updated : constant Hostkit.Metadata.Metadata_Update_Result :=
        Hostkit.Metadata.Update_Entry_Metadata
          (Path           => Path,
           Expected       => (others => <>),
           Check_Expected => False,
           Kind           => Hostkit.Metadata.Update_Ownership,
           Value          => Hostkit.Metadata.Identity_Field (User_Id),
           Group          => Hostkit.Metadata.Identity_Field (Group_Id),
           Max_Previous   => Hostkit.Metadata.Identity_Field'Last,
           Owner_Name     =>
             (if User_Id = Posix_Tools.Accounts.Id'Last
              then ""
              else User_Name_For_Id (User_Id)),
           Group_Name     =>
             (if Group_Id = Posix_Tools.Accounts.Id'Last
              then ""
              else Group_Name_For_Id (Group_Id)),
           Beneath_Root   => Beneath_Root,
           Relative_Path  => Relative_Path);
   begin
      return Updated.Success;
   end Set_Ownership_No_Follow;

   function Set_Permissions (Path : String; Mode : Natural) return Boolean is
   begin
      return Hostkit.Metadata.Set_Permissions (Path, Mode);
   end Set_Permissions;

   function Set_Permissions_No_Follow
     (Path          : String;
      Mode          : Natural;
      Beneath_Root  : String := "";
      Relative_Path : String := "") return Boolean
   is
      Updated : constant Hostkit.Metadata.Metadata_Update_Result :=
        Hostkit.Metadata.Update_Entry_Metadata
          (Path           => Path,
           Expected       => (others => <>),
           Check_Expected => False,
           Kind           => Hostkit.Metadata.Update_Permissions,
           Value          => Hostkit.Metadata.Identity_Field (Mode),
           Group          => 0,
           Max_Previous   => Hostkit.Metadata.Identity_Field'Last,
           Beneath_Root   => Beneath_Root,
           Relative_Path  => Relative_Path);
   begin
      return Updated.Success;
   end Set_Permissions_No_Follow;

   function Size (Path : String) return Long_Long_Integer is
   begin
      return Long_Long_Integer (Hostkit.Fs.Size_Of (Path));
   end Size;

   procedure Close_Follow_File (File : in out Follow_File) is
      procedure Mark_Closed is
      begin
         File.Identity := (others => <>);
         File.Cursor := 0;
         File.Handle_Kind := Follow_Closed;
         File.Sequential_Non_Blocking := False;
         File.History_Length := 0;
         File.History_Next := Follow_History_Index'First;
      end Mark_Closed;
   begin
      Hostkit.Descriptors.Close (File.Handle);
      Mark_Closed;
   exception
      when others =>
         --  intentional terminal exception barrier
         Mark_Closed;
   end Close_Follow_File;

   function Follow_File_Is_Open (File : Follow_File) return Boolean is
     (case File.Handle_Kind is
         when Follow_Closed     => False,
         when Follow_Seekable | Follow_Sequential =>
           Hostkit.Descriptors.Is_Valid (File.Handle));

   procedure Open_Follow_File
     (Path             : String;
      File             : in out Follow_File;
      Status           : out Follow_Open_Status;
      Require_Identity : Boolean := False) is separate;

   procedure Refresh_Follow_File
     (Path     : String;
      File     : in out Follow_File;
      Reopened : out Boolean;
      Status   : out Follow_Open_Status) is separate;

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
         --  intentional terminal exception barrier
         Last := 0;
         return False;
   end Try_Physical_Current_Directory;

   function User_Id_For_Name
     (Name : String; Found : out Boolean) return Posix_Tools.Accounts.Id
   is
      Host_Id : Hostkit.Metadata.Account_Id;
   begin
      Host_Id := Hostkit.Metadata.User_Id_For_Name (Name, Found);
      return Posix_Tools.Accounts.Id (Host_Id);
   end User_Id_For_Name;

   function User_Name_For_Id (Id : Posix_Tools.Accounts.Id) return String is
   begin
      return Hostkit.Metadata.User_Name_For_Id
        (Hostkit.Metadata.Account_Id (Id));
   end User_Name_For_Id;

   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean) is separate;
end Posix_Tools.Host_Adapters.File_System;
