with Ada.Streams;
with Posix_Tools.Counts;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Spill_Diagnostics;
with Posix_Tools.Host_Adapters.Temporary_Storage;

package body Posix_Tools.Commands.Tail_Bytes is
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Tail_Counts.Count_Origin;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Append_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Create_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Outcome;

   procedure Emit_Ring
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Ring    : Ada.Streams.Stream_Element_Array;
      Filled  : Natural;
      Next    : Ada.Streams.Stream_Element_Offset)
   is
      Start : Ada.Streams.Stream_Element_Offset;
   begin
      if Filled = 0 then
         return;
      elsif Filled < Ring'Length then
         declare
            Last : constant Ada.Streams.Stream_Element_Offset :=
              Ring'First + Ada.Streams.Stream_Element_Offset (Filled) - Ada.Streams.Stream_Element_Offset (1);
         begin
            Context.Put_Bytes (Ring, Last);
         end;
      else
         Start := Next;
         if Start <= Ring'Last then
            Context.Put_Bytes (Ring (Start .. Ring'Last), Ring'Last);
         end if;
         if Start > Ring'First then
            declare
               Last : constant Ada.Streams.Stream_Element_Offset :=
                 Start - Ada.Streams.Stream_Element_Offset (1);
            begin
               Context.Put_Bytes (Ring, Last);
            end;
         end if;
      end if;
   end Emit_Ring;

   procedure Copy_With_Spill
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Requested : Posix_Tools.Numbers.Count;
      Ok        : out Boolean;
      File      : access Posix_Tools.Host_Adapters.File_System.Follow_File)
   is
      Store : Posix_Tools.Host_Adapters.Temporary_Storage.Store;
      Create_Status : Posix_Tools.Host_Adapters.Temporary_Storage.Create_Outcome;
      Append_Status : Posix_Tools.Host_Adapters.Temporary_Storage.Append_Outcome :=
        Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete;
      Prepare_Status : Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Outcome;
      Buffer : Ada.Streams.Stream_Element_Array
        (1 .. Ada.Streams.Stream_Element_Offset
          (Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length));
      Last   : Ada.Streams.Stream_Element_Offset;
      Start  : Posix_Tools.Numbers.Count;

      procedure Release_Store is
      begin
         if not Posix_Tools.Host_Adapters.Temporary_Storage.Try_Cleanup (Store) then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.file.remove_failed", "cannot remove");
            Ok := False;
         end if;
      end Release_Store;

      procedure Store_Chunk
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         pragma Unreferenced (Context);
      begin
         if Append_Status = Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete then
            Append_Status :=
              Posix_Tools.Host_Adapters.Temporary_Storage.Append
                (Store, Buffer, Last);
         end if;
      end Store_Chunk;

      function Spill_Failed return Boolean is
        (Append_Status /=
           Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete);

      procedure Iterate_Path is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
        (Action        => Store_Chunk,
         Buffer_Length =>
           Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
      procedure Iterate_Follow is new
        Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Follow_Chunk
          (Action => Store_Chunk);
   begin
      Ok := False;
      Create_Status :=
        Posix_Tools.Host_Adapters.Temporary_Storage.Create
          (Store, Context.Tail_Max_Spill_Bytes);
      if Create_Status /=
        Posix_Tools.Host_Adapters.Temporary_Storage.Create_Complete
      then
         Posix_Tools.Commands.Spill_Diagnostics.Report
           (Context, Create_Status);
         return;
      end if;

      if File = null then
         Iterate_Path
           (Context, File_Name, Ok,
            Stop_Requested => Spill_Failed'Access);
      else
         Iterate_Follow
           (Context, File_Name, File.all, Ok,
            Stop_Requested => Spill_Failed'Access);
      end if;
      if not Ok
        or else Append_Status /= Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete
      then
         if Append_Status /= Posix_Tools.Host_Adapters.Temporary_Storage.Append_Complete
           and then not Context.Output_Failed
         then
            Posix_Tools.Commands.Spill_Diagnostics.Report
              (Context, Append_Status);
         end if;
         Release_Store;
         Ok := False;
         return;
      end if;

      Prepare_Status :=
        Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_For_Read (Store);
      if Prepare_Status /= Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Complete then
         Posix_Tools.Commands.Spill_Diagnostics.Report
           (Context, Prepare_Status);
         Release_Store;
         Ok := False;
         return;
      end if;

      Start := Posix_Tools.Counts.Suffix_Start
        (Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store), Requested);

      while Start <= Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store) loop
         if not Posix_Tools.Host_Adapters.Temporary_Storage.Read (Store, Start, Buffer, Last) then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.file.read_failed", "cannot read file");
            Release_Store;
            Ok := False;
            return;
         end if;

         exit when Last < Buffer'First;
         Context.Put_Bytes (Buffer, Last);
         if Context.Output_Failed then
            Release_Store;
            Ok := False;
            return;
         end if;

         Start :=
           Start
           + Posix_Tools.Numbers.Count
             (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
      end loop;

      Ok := True;
      Release_Store;
   end Copy_With_Spill;

   procedure Copy
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Requested : Posix_Tools.Numbers.Count;
      Origin    : Posix_Tools.Tail_Counts.Count_Origin;
      Ok        : out Boolean;
      File      : access Posix_Tools.Host_Adapters.File_System.Follow_File := null)
   is
      Limit : Natural;
   begin
      Ok := True;
      if Origin = Posix_Tools.Tail_Counts.From_Start then
         declare
            Position : Posix_Tools.Numbers.Count := 0;

            procedure Emit_From_Start
              (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
               Buffer  : Ada.Streams.Stream_Element_Array;
               Last    : Ada.Streams.Stream_Element_Offset)
            is
               Available : Posix_Tools.Numbers.Count;
               First_To_Emit : Ada.Streams.Stream_Element_Offset;
            begin
               if Last < Buffer'First then
                  return;
               end if;

               Available := Posix_Tools.Numbers.Count
                 (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
               if Requested = 0 or else Position + Available >= Requested then
                  First_To_Emit :=
                    (if Requested = 0 or else Position >= Requested - 1
                     then Buffer'First
                     else Buffer'First
                       + Ada.Streams.Stream_Element_Offset (Requested - Position - 1));
                  Context.Put_Bytes (Buffer (First_To_Emit .. Last), Last);
               end if;
               Position := Position + Available;
            end Emit_From_Start;

            procedure Iterate_Path is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
              (Action        => Emit_From_Start,
               Buffer_Length =>
                 Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
            procedure Iterate_Follow is new
              Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Follow_Chunk
                (Action => Emit_From_Start);
         begin
            if File = null then
               Iterate_Path (Context, File_Name, Ok);
            else
               Iterate_Follow (Context, File_Name, File.all, Ok);
            end if;
         end;
         return;
      end if;

      if Requested = 0 then
         declare
            procedure Ignore_Chunk
              (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
               Buffer  : Ada.Streams.Stream_Element_Array;
               Last    : Ada.Streams.Stream_Element_Offset)
            is
               pragma Unreferenced (Context, Buffer, Last);
            begin
               null;
            end Ignore_Chunk;

            procedure Iterate_Path is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
              (Action        => Ignore_Chunk,
               Buffer_Length =>
                 Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
            procedure Iterate_Follow is new
              Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Follow_Chunk
                (Action => Ignore_Chunk);
         begin
            if File = null then
               Iterate_Path (Context, File_Name, Ok);
            else
               Iterate_Follow (Context, File_Name, File.all, Ok);
            end if;
         end;
         return;
      elsif Requested > Context.Tail_Memory_Threshold
        or else Requested > Posix_Tools.Numbers.Count (Natural'Last)
      then
         Copy_With_Spill (Context, File_Name, Requested, Ok, File);
         return;
      end if;

      Limit := Natural (Requested);

      declare
         Filled : Natural := 0;
         Ring   : Ada.Streams.Stream_Element_Array (1 .. Ada.Streams.Stream_Element_Offset (Limit));
         Next   : Ada.Streams.Stream_Element_Offset := Ring'First;

         procedure Retain_Chunk
           (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
            Buffer  : Ada.Streams.Stream_Element_Array;
            Last    : Ada.Streams.Stream_Element_Offset)
         is
            pragma Unreferenced (Context);
            Available : Natural;
            Source    : Ada.Streams.Stream_Element_Offset;
            Remaining : Natural;
         begin
            if Last < Buffer'First then
               return;
            end if;

            Available := Natural (Last - Buffer'First + 1);
            if Available >= Limit then
               Source := Last - Ada.Streams.Stream_Element_Offset (Limit) + 1;
               Ring := Buffer (Source .. Last);
               Filled := Limit;
               Next := Ring'First;
               return;
            end if;

            Source := Buffer'First;
            Remaining := Available;
            while Remaining > 0 loop
               declare
                  Space  : constant Natural :=
                    Natural (Ring'Last - Next + 1);
                  Amount : constant Natural :=
                    Natural'Min (Remaining, Space);
                  Ring_Last : constant Ada.Streams.Stream_Element_Offset :=
                    Next + Ada.Streams.Stream_Element_Offset (Amount) - 1;
                  Source_Last : constant Ada.Streams.Stream_Element_Offset :=
                    Source + Ada.Streams.Stream_Element_Offset (Amount) - 1;
               begin
                  Ring (Next .. Ring_Last) := Buffer (Source .. Source_Last);
                  Filled := Natural'Min (Limit, Filled + Amount);
                  Source := Source_Last + 1;
                  Remaining := Remaining - Amount;
                  Next := Ring_Last + 1;
                  if Next > Ring'Last then
                     Next := Ring'First;
                  end if;
               end;
            end loop;
         end Retain_Chunk;

         procedure Iterate_Path is new Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
           (Action        => Retain_Chunk,
            Buffer_Length =>
              Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
         procedure Iterate_Follow is new
           Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Follow_Chunk
             (Action => Retain_Chunk);
      begin
         if File = null then
            Iterate_Path (Context, File_Name, Ok);
         else
            Iterate_Follow (Context, File_Name, File.all, Ok);
         end if;
         if not Ok then
            return;
         end if;

         Emit_Ring (Context, Ring, Filled, Next);
         if Context.Output_Failed then
            Ok := False;
         end if;
      end;
   end Copy;
end Posix_Tools.Commands.Tail_Bytes;
