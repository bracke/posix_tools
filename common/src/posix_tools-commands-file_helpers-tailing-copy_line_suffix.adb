separate (Posix_Tools.Commands.File_Helpers.Tailing)
procedure Copy_Line_Suffix
  (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
   File_Name : String;
   Lines     : Posix_Tools.Numbers.Count;
   Ok        : out Boolean;
   File      : access Posix_Tools.Host_Adapters.File_System.Follow_File := null)
is
   Input   : Byte_Buffer;
   Last    : Ada.Streams.Stream_Element_Offset;
   Current : Unbounded_String;
   Output  : Posix_Tools.Commands.Helpers.Output_Buffer;
   Retained : Line_Vectors.Vector;
   Retained_Bytes : Posix_Tools.Numbers.Count := 0;
   Retained_Next : Positive := 1;
   Retained_Full : Boolean := False;
   Store : Posix_Tools.Host_Adapters.Temporary_Storage.Store;
   Create_Status : Posix_Tools.Host_Adapters.Temporary_Storage.Create_Outcome :=
     Posix_Tools.Host_Adapters.Temporary_Storage.Create_Complete;
   Store_Available : Boolean := False;
   Spill_Needed : Boolean := False;
   Spill_Status : Posix_Tools.Host_Adapters.Temporary_Storage.Append_Outcome :=
     Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete;
   Spill_Buffer : Byte_Buffer;
   Spill_Last : Ada.Streams.Stream_Element_Offset :=
     Spill_Buffer'First - 1;

   procedure Release_Store is
   begin
      if not Posix_Tools.Host_Adapters.Temporary_Storage.Try_Cleanup (Store) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.file.remove_failed", "cannot remove");
         Ok := False;
      end if;
   end Release_Store;

   procedure Append_To_Store
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset)
   is
   begin
      if Store_Available
        and then Spill_Status = Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete
      then
         Spill_Status :=
           Posix_Tools.Host_Adapters.Temporary_Storage.Append
             (Store, Buffer, Last);
      end if;
   end Append_To_Store;

   procedure Flush_Spill_Buffer is
   begin
      if Spill_Last >= Spill_Buffer'First then
         Append_To_Store (Spill_Buffer, Spill_Last);
         Spill_Last := Spill_Buffer'First - 1;
      end if;
   end Flush_Spill_Buffer;

   procedure Append_Text_To_Store (Text : String) is
   begin
      for Ch of Text loop
         exit when
           Spill_Status /=
             Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete;
         Spill_Last := Spill_Last + 1;
         Spill_Buffer (Spill_Last) :=
           Ada.Streams.Stream_Element (Character'Pos (Ch));
         if Spill_Last = Spill_Buffer'Last then
            Flush_Spill_Buffer;
         end if;
      end loop;
   end Append_Text_To_Store;

   procedure Start_Spill is separate;

   function Spill_Failed return Boolean is
     (Spill_Needed
      and then
        (not Store_Available
         or else Spill_Status /=
           Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete));

   procedure Emit_Store_From (Start : Posix_Tools.Numbers.Count) is
      Buffer : Bulk_Byte_Buffer;
      Last   : Ada.Streams.Stream_Element_Offset;
      Next   : Posix_Tools.Numbers.Count := Start;
   begin
      while Next <= Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store) loop
         if not Posix_Tools.Host_Adapters.Temporary_Storage.Read (Store, Next, Buffer, Last) then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.file.read_failed", "cannot read file");
            Ok := False;
            return;
         end if;

         exit when Last < Buffer'First;
         Context.Put_Bytes (Buffer, Last);
         if Context.Output_Failed then
            Ok := False;
            return;
         end if;

         Next := Next + Posix_Tools.Numbers.Count
           (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
      end loop;
   end Emit_Store_From;

   function Find_Store_Line_Start
     (Start : out Posix_Tools.Numbers.Count) return Boolean is separate;

   procedure Keep_Current is
      Current_Length : constant Posix_Tools.Numbers.Count :=
        Posix_Tools.Numbers.Count (Length (Current));
   begin
      if Spill_Needed then
         Current := Null_Unbounded_String;
         return;
      elsif Current_Length > Context.Tail_Memory_Threshold
        or else Retained_Bytes > Context.Tail_Memory_Threshold - Current_Length
      then
         Start_Spill;
         return;
      end if;

      if Posix_Tools.Numbers.Count (Retained.Length) < Lines then
         Retained.Append (To_String (Current));
         Retained_Bytes := Retained_Bytes + Current_Length;
         if Posix_Tools.Numbers.Count (Retained.Length) = Lines then
            Retained_Full := True;
            Retained_Next := 1;
         end if;
      else
         declare
            Replaced : constant String := Retained (Retained_Next);
         begin
            Retained_Bytes :=
              Retained_Bytes
              - Posix_Tools.Numbers.Count (Replaced'Length)
              + Current_Length;
         end;
         Retained.Replace_Element (Retained_Next, To_String (Current));
         Retained_Next :=
           (if Retained_Next = Natural (Retained.Length)
            then 1 else Retained_Next + 1);
      end if;

      Current := Null_Unbounded_String;
   end Keep_Current;

   procedure Scan_Buffer
     (Buffer      : Ada.Streams.Stream_Element_Array;
      Buffer_Last : Ada.Streams.Stream_Element_Offset) is separate;

   procedure Scan_Chunk
     (Buffer : Ada.Streams.Stream_Element_Array;
      Chunk_Last : Ada.Streams.Stream_Element_Offset;
      Stop   : in out Boolean)
   is
   begin
      Scan_Buffer (Buffer, Chunk_Last);
      Stop := not Ok or else Spill_Failed;
   end Scan_Chunk;

   procedure Try_Copy_Regular_Suffix
     (Handled : out Boolean) is separate;

   procedure Emit_Suffix is separate;
begin
   Ok := True;
   if Lines = 0 then
      if File /= null then
         declare
            procedure Ignore_Chunk
              (Buffer : Ada.Streams.Stream_Element_Array;
               Last   : Ada.Streams.Stream_Element_Offset;
               Stop   : in out Boolean)
            is
               pragma Unreferenced (Buffer, Last, Stop);
            begin
               null;
            end Ignore_Chunk;

            procedure Drain is new
              Posix_Tools.Host_Adapters.File_System.For_Each_Follow_Chunk
                (Action => Ignore_Chunk);
         begin
            --  A retained follow handle must still reach the current EOF:
            --  the follow loop resumes at this exact stream position.
            Drain (File.all, Ok);
         end;
         if not Ok then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context,
               Posix_Tools.Commands.Helpers.File_Subject
                 (Context, File_Name),
               "posix_tools.diagnostic.file.read_failed",
               "cannot read file");
         end if;
         Release_Store;
         return;
      elsif File_Name = "-"
        or else Posix_Tools.Host_Adapters.File_System.Can_Open_For_Read
          (File_Name)
      then
         Release_Store;
         return;
      end if;

      Posix_Tools.Commands.Helpers.Subject_Operational_Error
       (Context, Posix_Tools.Commands.Helpers.File_Subject (Context, File_Name),
        "posix_tools.diagnostic.file.read_failed", "cannot read file");
      Ok := False;
      Release_Store;
      return;
   end if;

   declare
      Handled : Boolean;
   begin
      Try_Copy_Regular_Suffix (Handled);
      if Handled then
         Release_Store;
         return;
      end if;
   end;

   if File_Name = "-" then
      loop
         if not Context.Try_Read_Standard_Input (Input, Last) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Posix_Tools.Commands.Helpers.Standard_Input_Name (Context),
               "posix_tools.diagnostic.file.read_failed", "cannot read file");
            Ok := False;
            Release_Store;
            return;
         end if;
         exit when Last < Input'First;
         Scan_Buffer (Input, Last);
         exit when not Ok or else Spill_Failed;
      end loop;
   else
      declare
         procedure Iterate_Path is new Posix_Tools.Host_Adapters.File_System.For_Each_File_Chunk
           (Action        => Scan_Chunk,
            Buffer_Length => Bulk_Buffer_Size);
         procedure Iterate_Follow is new
           Posix_Tools.Host_Adapters.File_System.For_Each_Follow_Chunk
             (Action => Scan_Chunk);
      begin
         if File = null then
            Iterate_Path (File_Name, Ok);
         else
            Iterate_Follow (File.all, Ok);
         end if;
      end;
      if not Ok then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Posix_Tools.Commands.Helpers.File_Subject (Context, File_Name),
            "posix_tools.diagnostic.file.read_failed", "cannot read file");
         Release_Store;
         return;
      end if;
   end if;

   if Ok and then Length (Current) > 0 then
      Keep_Current;
   end if;

   if not Ok then
      Release_Store;
      return;
   end if;

   Emit_Suffix;

   Release_Store;
end Copy_Line_Suffix;
