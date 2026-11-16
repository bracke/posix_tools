with Ada.Containers.Indefinite_Vectors;
with Ada.IO_Exceptions;
with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Spill_Diagnostics;
with Posix_Tools.Host_Adapters.Temporary_Storage;
with Posix_Tools.Streams.Bytes;

package body Posix_Tools.Commands.File_Helpers.Tailing is
   use Ada.Strings.Unbounded;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Append_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Create_Outcome;
   use type Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_Outcome;

   Buffer_Size : constant := 16 * 1024;
   Bulk_Buffer_Size : constant := 64 * 1024;
   subtype Byte_Buffer is Ada.Streams.Stream_Element_Array (1 .. Buffer_Size);
   subtype Bulk_Byte_Buffer is
     Ada.Streams.Stream_Element_Array (1 .. Bulk_Buffer_Size);

   package Line_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   procedure Copy_Line_Suffix
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Lines     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean;
      File      : access Posix_Tools.Host_Adapters.File_System.Follow_File := null)
   is separate;

   procedure Copy_Lines_From
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      First     : Posix_Tools.Numbers.Count;
      Ok        : out Boolean;
      File      : access Posix_Tools.Host_Adapters.File_System.Follow_File := null)
   is
      Input   : Byte_Buffer;
      Last    : Ada.Streams.Stream_Element_Offset;
      Current : Unbounded_String;
      Seen    : Posix_Tools.Numbers.Count := 0;
      Output  : Posix_Tools.Commands.Helpers.Output_Buffer;

      procedure Emit_Current is
      begin
         Seen := Seen + Posix_Tools.Numbers.Count (1);
         if First = 0 or else Seen >= First then
            Posix_Tools.Commands.Helpers.Buffered_Put
              (Output, Context, To_String (Current));
         end if;

         Current := Null_Unbounded_String;
      end Emit_Current;

      procedure Scan_Buffer
        (Buffer      : Ada.Streams.Stream_Element_Array;
         Buffer_Last : Ada.Streams.Stream_Element_Offset)
      is
         First : Ada.Streams.Stream_Element_Offset := Buffer'First;
      begin
         if Buffer_Last < Buffer'First then
            return;
         end if;

         for I in Buffer'First .. Buffer_Last loop
            if Buffer (I) = Ada.Streams.Stream_Element (10) then
               Append
                 (Current,
                  Posix_Tools.Streams.Bytes.To_String
                    (Buffer (First .. I), I));
               First := I + 1;
               Emit_Current;
               exit when Context.Output_Failed;
            end if;
         end loop;

         if not Context.Output_Failed and then First <= Buffer_Last then
            Append
              (Current,
               Posix_Tools.Streams.Bytes.To_String
                 (Buffer (First .. Buffer_Last), Buffer_Last));
         end if;
      end Scan_Buffer;

      procedure Scan_Chunk
        (Buffer : Ada.Streams.Stream_Element_Array;
         Chunk_Last : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
      begin
         Scan_Buffer (Buffer, Chunk_Last);
         Stop := Context.Output_Failed;
      end Scan_Chunk;
   begin
      Ok := True;
      if File_Name = "-" then
         loop
            if not Context.Try_Read_Standard_Input (Input, Last) then
               Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Posix_Tools.Commands.Helpers.Standard_Input_Name (Context),
                  "posix_tools.diagnostic.file.read_failed", "cannot read file");
               Ok := False;
               return;
            end if;
            exit when Last < Input'First;
            Scan_Buffer (Input, Last);
            exit when Context.Output_Failed;
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
            Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Posix_Tools.Commands.Helpers.File_Subject (Context, File_Name),
               "posix_tools.diagnostic.file.read_failed", "cannot read file");
            return;
         end if;
      end if;

      if not Context.Output_Failed and then Length (Current) > 0 then
         Emit_Current;
      end if;

      Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
      Ok := not Context.Output_Failed;
   end Copy_Lines_From;
end Posix_Tools.Commands.File_Helpers.Tailing;
