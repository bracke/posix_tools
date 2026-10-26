with Ada.Directories;
with Hostkit.Descriptors;
with Hostkit.Directory_Listing;
with Hostkit.Fs;
with Hostkit.Metadata;

package body Posix_Tools.Host_Adapters.File_System is
   use type Ada.Streams.Stream_Element_Offset;

   Buffer_Size : constant := 16 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);

   --  Whole seconds since 1970-01-01 UTC.
   function Epoch_Seconds (Time : File_Time) return Long_Long_Integer;

   function Access_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
      Available : Boolean := False;
   begin
      Time := Hostkit.Metadata.File_Access_Time (Path, Available);
      return Available;
   exception
      when others =>
         Time := Ada.Calendar.Time_Of (1901, 1, 1);
         return False;
   end Access_Time;

   function Allocated_Size (Path : String; Available : out Boolean) return Long_Long_Integer is
   begin
      --  Hostkit's public metadata surface does not yet expose per-file allocated
      --  block counts. Keep the capability explicit so command code can distinguish
      --  real allocated usage from the portable byte-size fallback.
      Available := False;
      return Long_Long_Integer (Ada.Directories.Size (Path));
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

   procedure Copy_Regular_File_With_Progress (Source : String; Target : String; Status : out Copy_File_Status) is
      use Hostkit.Descriptors;

      Copied  : Long_Long_Integer := 0;
      Stop    : Boolean := False;

      Input   : Descriptor := Invalid;
      Output  : Descriptor := Invalid;
      Buffer  : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      First   : Ada.Streams.Stream_Element_Offset;
      Written : Ada.Streams.Stream_Element_Offset;
      Outcome : Transfer_Outcome;

      --  Close both, the copy having ended as Ending: a target whose close
      --  fails may not hold what was written to it, and a copy that would
      --  otherwise have ended well ends as a failed write instead.
      procedure Finish (Ending : Copy_File_Status);

      procedure Finish (Ending : Copy_File_Status) is
         Closed : Boolean;
      begin
         Close (Input);
         Closed := Close (Output);
         Status := (if Ending = Copy_Ok and then not Closed then Target_Write_Failed else Ending);
      end Finish;
   begin
      --  The source is only read: its times are what reading leaves them,
      --  and a copy that keeps them takes them before it starts.
      if not Open_File (Source, Open_Read, Input) then
         Status := Source_Open_Failed;
         return;
      end if;

      if not Open_File (Target, Open_Write_Truncate, Output) then
         Close (Input);
         Status := Target_Open_Failed;
         return;
      end if;

      loop
         Outcome := Read (Input, Buffer, Last);
         case Outcome is
            when Transfer_Ok =>
               if Last >= Buffer'First then
                  First := Buffer'First;
                  while First <= Last loop
                     Outcome := Write (Output, Buffer (First .. Last), Written);
                     case Outcome is
                        when Transfer_Ok =>
                           if Written < First then
                              Finish (Target_Write_Failed);
                              return;
                           end if;

                           First := Written + 1;

                        when Transfer_Interrupted =>
                           null;

                        when others =>
                           Finish (Target_Write_Failed);
                           return;
                     end case;
                  end loop;

                  Copied := Copied + Long_Long_Integer (Last - Buffer'First + 1);
                  Progress (Copied, Stop);

                  if Stop then
                     Finish (Copy_Stopped);
                     return;
                  end if;
               end if;

            when Transfer_Interrupted =>
               null;

            when Transfer_End_Of_File =>
               Finish (Copy_Ok);
               return;

            when others =>
               Finish (Source_Read_Failed);
               return;
         end case;
      end loop;
   exception
      when others =>
         Close (Input);
         Close (Output);
         Status := Source_Read_Failed;
   end Copy_Regular_File_With_Progress;

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
         Time := Ada.Calendar.Time_Of (1901, 1, 1);
         return False;
   end Creation_Time;

   function Current_File_Time return File_Time is
   begin
      return File_Time (GNAT.OS_Lib.Current_Time);
   end Current_File_Time;

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

   function Device_Id (Path : String; Available : out Boolean) return Long_Long_Integer is
   begin
      return Hostkit.Metadata.Device_Id (Path, Available);
   end Device_Id;

   function Entry_Status_Of (Path : String) return Entry_Status is
      use type Hostkit.Metadata.Identity_Field;

      Revision : constant Hostkit.Metadata.Entry_Revision := Hostkit.Metadata.Entry_Revision_Of (Path);
      Largest  : constant Hostkit.Metadata.Identity_Field := Hostkit.Metadata.Identity_Field (Long_Long_Integer'Last);
      Id_Limit : constant Hostkit.Metadata.Identity_Field := Hostkit.Metadata.Identity_Field (Natural'Last);

      function Clamped (Value : Hostkit.Metadata.Identity_Field) return Long_Long_Integer is
        (Long_Long_Integer (Hostkit.Metadata.Identity_Field'Min (Value, Largest)));

      function Clamped_Id (Value : Hostkit.Metadata.Identity_Field) return Natural is
        (Natural (Hostkit.Metadata.Identity_Field'Min (Value, Id_Limit)));
   begin
      if not Revision.Available then
         return (others => <>);
      end if;

      return
        (Available        => True,
         Size             => Clamped (Revision.Size),
         Modified_Seconds => Clamped (Revision.Modified_Seconds),
         Mode             => Clamped_Id (Revision.Mode),
         User             => Clamped_Id (Revision.User_Id),
         Group            => Clamped_Id (Revision.Group_Id));
   exception
      when others =>
         return (others => <>);
   end Entry_Status_Of;

   function Epoch_Seconds (Time : File_Time) return Long_Long_Integer is
      Year   : GNAT.OS_Lib.Year_Type;
      Month  : GNAT.OS_Lib.Month_Type;
      Day    : GNAT.OS_Lib.Day_Type;
      Hour   : GNAT.OS_Lib.Hour_Type;
      Minute : GNAT.OS_Lib.Minute_Type;
      Second : GNAT.OS_Lib.Second_Type;

      function Days_Before_Unix_Epoch
        (Year  : Long_Long_Integer;
         Month : Long_Long_Integer;
         Day   : Long_Long_Integer)
         return Long_Long_Integer;

      function Days_Before_Unix_Epoch
        (Year  : Long_Long_Integer;
         Month : Long_Long_Integer;
         Day   : Long_Long_Integer)
         return Long_Long_Integer
      is
         Adjusted_Year  : Long_Long_Integer := Year;
         Adjusted_Month : Long_Long_Integer := Month;
         Era            : Long_Long_Integer;
         Year_Of_Era    : Long_Long_Integer;
         Day_Of_Year    : Long_Long_Integer;
         Day_Of_Era     : Long_Long_Integer;
      begin
         if Adjusted_Month <= 2 then
            Adjusted_Year := Adjusted_Year - 1;
         end if;

         Era := (if Adjusted_Year >= 0 then Adjusted_Year else Adjusted_Year - 399) / 400;
         Year_Of_Era := Adjusted_Year - Era * 400;
         Adjusted_Month := Adjusted_Month + (if Adjusted_Month > 2 then -3 else 9);
         Day_Of_Year := (153 * Adjusted_Month + 2) / 5 + Day - 1;
         Day_Of_Era := Year_Of_Era * 365 + Year_Of_Era / 4 - Year_Of_Era / 100 + Day_Of_Year;
         return Era * 146_097 + Day_Of_Era - 719_468;
      end Days_Before_Unix_Epoch;
   begin
      GNAT.OS_Lib.GM_Split (GNAT.OS_Lib.OS_Time (Time), Year, Month, Day, Hour, Minute, Second);
      return Days_Before_Unix_Epoch
          (Long_Long_Integer (Year), Long_Long_Integer (Month), Long_Long_Integer (Day))
        * 86_400
        + Long_Long_Integer (Hour) * 3_600
        + Long_Long_Integer (Minute) * 60
        + Long_Long_Integer (Second);
   end Epoch_Seconds;

   function Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
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
      User      : out Natural;
      Group     : out Natural;
      Available : out Boolean)
   is
   begin
      Hostkit.Metadata.File_Ownership (Path, User, Group, Available);
   end File_Ownership;

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

   function File_Time_From_File (Path : String; Time : out File_Time) return Boolean is
   begin
      Time := File_Time (GNAT.OS_Lib.File_Time_Stamp (Path));
      return True;
   exception
      when others =>
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
         Time := Current_File_Time;
         return False;
   end File_Time_Of;

   procedure For_Each_Directory_Entry (Path : String; Ok : out Boolean) is
      Search      : Ada.Directories.Search_Type;
      Search_Open : Boolean := False;
      Dir_Entry   : Ada.Directories.Directory_Entry_Type;
      Stop        : Boolean := False;

      procedure Close_Search (Cleanup_Ok : in out Boolean);

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

   procedure For_Each_Listed_Entry (Path : String; Ok : out Boolean) is
      Entries : Hostkit.Directory_Listing.Entry_Vectors.Vector;
      Stop    : Boolean := False;
   begin
      begin
         Ok := Hostkit.Directory_Listing.List (Path, Entries);
      exception
         when others =>
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

   function Group_Id_For_Name (Name : String; Found : out Boolean) return Natural is
   begin
      return Hostkit.Metadata.Group_Id_For_Name (Name, Found);
   end Group_Id_For_Name;

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
      --  Windows answers Exists for the link itself, so a link to nothing
      --  would read as a file; resolving it says what stat(2) would.
      if not Ada.Directories.Exists (Path)
        or else (Hostkit.Fs.Is_Link (Path) and then Hostkit.Fs.Real_Path (Path) = "")
      then
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

   function Modification_Time (Path : String; Time : out Ada.Calendar.Time) return Boolean is
   begin
      Time := Ada.Directories.Modification_Time (Path);
      return True;
   exception
      when others =>
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

   procedure Rename (Old_Path : String; New_Path : String) is
   begin
      Ada.Directories.Rename (Old_Path, New_Path);
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

   function Set_Ownership (Path : String; User : Natural; Group : Natural) return Boolean is
   begin
      return Hostkit.Metadata.Set_Ownership (Path, User, Group);
   end Set_Ownership;

   function Set_Permissions (Path : String; Mode : Natural) return Boolean is
   begin
      return Hostkit.Metadata.Set_Permissions (Path, Mode);
   end Set_Permissions;

   function Simple_Name (Path : String) return String is
   begin
      return Ada.Directories.Simple_Name (Path);
   end Simple_Name;

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

   function User_Id_For_Name (Name : String; Found : out Boolean) return Natural is
   begin
      return Hostkit.Metadata.User_Id_For_Name (Name, Found);
   end User_Id_For_Name;

   function User_Name_For_Id (Id : Natural) return String is
   begin
      return Hostkit.Metadata.User_Name_For_Id (Id);
   end User_Name_For_Id;

   procedure Write_File
     (Path        : String;
      Text        : String;
      Append_Mode : Boolean;
      Ok          : out Boolean)
   is
      use Hostkit.Descriptors;

      Output  : Descriptor := Invalid;
      Buffer  : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset (Text'Length));
      Target  : Ada.Streams.Stream_Element_Offset := Buffer'First;
      First   : Ada.Streams.Stream_Element_Offset;
      Written : Ada.Streams.Stream_Element_Offset;
      Outcome : Transfer_Outcome;
   begin
      Ok :=
        Open_File
          (Path,
           (if Append_Mode and then Exists (Path) then Open_Write_Append else Open_Write_Truncate),
           Output);
      if not Ok then
         return;
      end if;

      if Text'Length > 0 then
         for Ch of Text loop
            Buffer (Target) := Ada.Streams.Stream_Element (Character'Pos (Ch));
            Target := Target + 1;
         end loop;

         First := Buffer'First;
         while First <= Buffer'Last loop
            Outcome := Write (Output, Buffer (First .. Buffer'Last), Written);
            case Outcome is
               when Transfer_Ok =>
                  if Written < First then
                     Close (Output);
                     Ok := False;
                     return;
                  end if;

                  First := Written + 1;

               when Transfer_Interrupted =>
                  null;

               when others =>
                  Close (Output);
                  Ok := False;
                  return;
            end case;
         end loop;
      end if;

      Ok := Close (Output);
   exception
      when others =>
         Close (Output);
         Ok := False;
   end Write_File;
end Posix_Tools.Host_Adapters.File_System;
