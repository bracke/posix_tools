separate (Posix_Tools.Commands.Sort.Run)
procedure Sort_And_Write is
   Spill_Threshold : constant Posix_Tools.Numbers.Count :=
     Context.Sort_Memory_Threshold;
   Buffer_Size       : constant := 16 * 1024;
   Spill_Buffer_Size : constant := 64 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);
   subtype Spill_Byte_Buffer is
     Ada.Streams.Stream_Element_Array (1 .. Spill_Buffer_Size);
   package Storage renames Posix_Tools.Host_Adapters.Temporary_Storage;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;
   use type Storage.Append_Outcome;
   use type Storage.Create_Outcome;
   use type Storage.Finish_Outcome;
   use type Storage.Prepare_Outcome;
   use type Storage.Read_Outcome;

   type Store_Access is access Storage.Store;
   procedure Free is new Ada.Unchecked_Deallocation (Storage.Store, Store_Access);
   type Buffer_Access is access Byte_Buffer;
   procedure Free is new Ada.Unchecked_Deallocation (Byte_Buffer, Buffer_Access);

   type Run_State is record
      Store       : Store_Access := null;
      Buffer      : Buffer_Access := null;
      Next        : Ada.Streams.Stream_Element_Offset := Byte_Buffer'First;
      Last        : Ada.Streams.Stream_Element_Offset := Byte_Buffer'First - 1;
      At_End      : Boolean := False;
      Available   : Boolean := False;
      Line        : Unbounded_String;
      Prepared    : Sort_Keys.Prepared_Line;
   end record;
   package Run_Vectors is new Ada.Containers.Vectors (Positive, Run_State);

   Lines          : String_Vectors.Vector;
   Runs           : Run_Vectors.Vector;
   Resident_Bytes : Posix_Tools.Numbers.Count := 0;
   Comparator     : Sort_Keys.Comparator;
   Previous       : Sort_Keys.Prepared_Line;
   Have_Previous  : Boolean := False;
   Disorder       : Boolean := False;
   Disorder_Line  : Unbounded_String;

   procedure Release_Run (Run : in out Run_State);
   procedure Storage_Error (Outcome : Storage.Create_Outcome);
   procedure Cleanup;
   procedure Spill;
   procedure Add_Line
     (Ignored    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line       : String;
      Terminated : Boolean);
   procedure Read_Source (Name : String);

   procedure Release_Run (Run : in out Run_State) is
      Cleaned : Boolean;
   begin
      if Run.Buffer /= null then
         Free (Run.Buffer);
      end if;
      if Run.Store /= null then
         Cleaned := Storage.Cleanup_Or_Defer (Run.Store.all);
         if not Cleaned then
            Storage_Error (Storage.Create_Cleanup_Failed);
         end if;
         Free (Run.Store);
      end if;
   end Release_Run;

   procedure Cleanup is
   begin
      for I in Runs.First_Index .. Runs.Last_Index loop
         declare
            Ref : constant Run_Vectors.Reference_Type := Runs.Reference (I);
         begin
            Release_Run (Ref.Element.all);
         end;
      end loop;
      Runs.Clear;
   end Cleanup;

   procedure Storage_Error (Outcome : Storage.Create_Outcome) is
   begin
      Posix_Tools.Commands.Spill_Diagnostics.Report (Context, Outcome);
      Ok := False;
   end Storage_Error;

   procedure Storage_Error (Outcome : Storage.Append_Outcome) is
   begin
      Posix_Tools.Commands.Spill_Diagnostics.Report (Context, Outcome);
      Ok := False;
   end Storage_Error;

   procedure Storage_Error (Outcome : Storage.Read_Outcome) is
   begin
      Posix_Tools.Commands.Spill_Diagnostics.Report (Context, Outcome);
      Ok := False;
   end Storage_Error;

   procedure Storage_Error (Outcome : Storage.Finish_Outcome) is
   begin
      Posix_Tools.Commands.Spill_Diagnostics.Report (Context, Outcome);
      Ok := False;
   end Storage_Error;

   procedure Storage_Error (Outcome : Storage.Prepare_Outcome) is
   begin
      Posix_Tools.Commands.Spill_Diagnostics.Report (Context, Outcome);
      Ok := False;
   end Storage_Error;

   procedure Spill is separate;

   procedure Add_Line
     (Ignored    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Line       : String;
      Terminated : Boolean)
   is
      pragma Unreferenced (Ignored, Terminated);
      Current : Sort_Keys.Prepared_Line;
      Line_Size : Posix_Tools.Numbers.Count;
   begin
      if not Ok or else Disorder then
         return;
      elsif Options.Check /= Sort_Input then
         Current := Sort_Keys.Prepare_Line (Comparator, Line);
         if Have_Previous
           and then
             (Sort_Keys.Compare (Comparator, Previous, Current) > 0
              or else (Options.Sorting.Unique
                       and then Sort_Keys.Keys_Equal (Comparator, Previous, Current)))
         then
            Disorder := True;
            Disorder_Line := To_Unbounded_String (Line);
         else
            Previous := Current;
            Have_Previous := True;
         end if;
      else
         Lines.Append (Line);
         Line_Size := Sort_Keys.Estimated_Storage_Size (Comparator, Line);
         Resident_Bytes :=
           (if Line_Size > Posix_Tools.Numbers.Count'Last - Resident_Bytes
            then Posix_Tools.Numbers.Count'Last
            else Resident_Bytes + Line_Size);
         if Resident_Bytes >= Spill_Threshold then
            Spill;
         end if;
      end if;
   end Add_Line;

   procedure Iterate is new
     Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Line
       (Action        => Add_Line,
        Buffer_Length =>
          Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);

   procedure Read_Source (Name : String) is
      Read_Ok : Boolean;
   begin
      if Ok and then not Disorder then
         Iterate (Context, Name, Read_Ok);
         Ok := Ok and Read_Ok;
      end if;
   end Read_Source;

   procedure Merge_Runs;

   procedure Merge_Runs is separate;
begin
   Sort_Keys.Initialize (Comparator, Options.Sorting);
   if Options.Files.Is_Empty then
      Read_Source ("-");
   else
      for Name of Options.Files loop
         Read_Source (Name);
         exit when not Ok or else Disorder;
      end loop;
   end if;

   if Options.Check /= Sort_Input then
      if Disorder then
         if Options.Check = Diagnose_Disorder then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.sort.disorder", "line",
               To_String (Disorder_Line), "disorder: '{line}'");
         end if;
         Ok := False;
      end if;
      Cleanup;
      return;
   end if;

   if Ok and then Runs.Is_Empty then
      Sort_Keys.Sort_Lines (Lines, Options.Sorting);
      Write_Output (Context, Options, Lines, Ok);
   elsif Ok then
      Spill;
      if Ok then
         Merge_Runs;
      end if;
   end if;
   Cleanup;
exception
   when others =>
      Cleanup;
      raise;
end Sort_And_Write;
