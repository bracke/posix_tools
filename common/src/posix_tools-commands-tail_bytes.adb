with Ada.Streams;
with Posix_Tools.Counts;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Host_Adapters.Temporary_Storage;
with Posix_Tools.Tail_Rings;

package body Posix_Tools.Commands.Tail_Bytes is
   use type Ada.Streams.Stream_Element_Offset;
   use type Posix_Tools.Numbers.Count;
   use type Posix_Tools.Tail_Counts.Count_Origin;

   function To_String
     (Buffer : Ada.Streams.Stream_Element_Array;
      Last   : Ada.Streams.Stream_Element_Offset) return String
   is
      Result : String (1 .. Natural (Integer (Last) - Integer (Buffer'First) + 1));
      Target : Positive := Result'First;
   begin
      for I in Buffer'First .. Last loop
         Result (Target) := Character'Val (Integer (Buffer (I)));
         Target := Target + 1;
      end loop;

      return Result;
   end To_String;

   procedure Keep_Byte
     (Ring     : in out Ada.Streams.Stream_Element_Array;
      Filled   : in out Natural;
      Next     : in out Ada.Streams.Stream_Element_Offset;
      Element  : Ada.Streams.Stream_Element)
   is
      Step : Posix_Tools.Tail_Rings.Advance_Result;
   begin
      Ring (Next) := Element;
      Step :=
        Posix_Tools.Tail_Rings.Advance
          (First   => Posix_Tools.Tail_Rings.Position (Ring'First),
           Last    => Posix_Tools.Tail_Rings.Position (Ring'Last),
           Current => Posix_Tools.Tail_Rings.Position (Next),
           Filled  => Filled);
      Filled := Step.Filled;
      Next := Ada.Streams.Stream_Element_Offset (Step.Next);
   end Keep_Byte;

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
            Context.Put (To_String (Ring (Ring'First .. Last), Last));
         end;
      else
         Start := Next;
         if Start <= Ring'Last then
            Context.Put (To_String (Ring (Start .. Ring'Last), Ring'Last));
         end if;
         if Start > Ring'First then
            declare
               Last : constant Ada.Streams.Stream_Element_Offset :=
                 Start - Ada.Streams.Stream_Element_Offset (1);
            begin
               Context.Put (To_String (Ring (Ring'First .. Last), Last));
            end;
         end if;
      end if;
   end Emit_Ring;

   procedure Copy_With_Spill
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Requested : Posix_Tools.Numbers.Count;
      Ok        : out Boolean)
   is
      Store : Posix_Tools.Host_Adapters.Temporary_Storage.Store;
      Append_Ok : Boolean := True;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 16 * 1024);
      Last   : Ada.Streams.Stream_Element_Offset;
      Start  : Posix_Tools.Numbers.Count;

      procedure Store_Chunk
        (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
         Buffer  : Ada.Streams.Stream_Element_Array;
         Last    : Ada.Streams.Stream_Element_Offset)
      is
         pragma Unreferenced (Context);
      begin
         if Append_Ok then
            Append_Ok := Posix_Tools.Host_Adapters.Temporary_Storage.Append (Store, Buffer, Last);
         end if;
      end Store_Chunk;

      procedure Iterate is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
        (Action => Store_Chunk);
   begin
      Ok := False;
      if Requested > Context.Tail_Max_Spill_Bytes
        or else not Posix_Tools.Host_Adapters.Temporary_Storage.Create
          (Store, Context.Tail_Max_Spill_Bytes)
      then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
         return;
      end if;

      Iterate (Context, File_Name, Ok);
      if not Ok or else not Append_Ok then
         if not Append_Ok and then not Context.Output_Failed then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
         end if;
         Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
         Ok := False;
         return;
      end if;

      if not Posix_Tools.Host_Adapters.Temporary_Storage.Prepare_For_Read (Store) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.resource.count_too_large", "count too large");
         Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
         Ok := False;
         return;
      end if;

      Start := Posix_Tools.Counts.Suffix_Start
        (Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store), Requested);

      while Start <= Posix_Tools.Host_Adapters.Temporary_Storage.Size (Store) loop
         if not Posix_Tools.Host_Adapters.Temporary_Storage.Read (Store, Start, Buffer, Last) then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.file.read_failed", "cannot read file");
            Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
            Ok := False;
            return;
         end if;

         exit when Last < Buffer'First;
         Context.Put (To_String (Buffer, Last));
         if Context.Output_Failed then
            Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
            Ok := False;
            return;
         end if;

         Start :=
           Start
           + Posix_Tools.Numbers.Count
             (Last - Buffer'First + Ada.Streams.Stream_Element_Offset (1));
      end loop;

      Posix_Tools.Host_Adapters.Temporary_Storage.Cleanup (Store);
      Ok := True;
   end Copy_With_Spill;

   procedure Copy
     (Context   : in out Posix_Tools.Commands.Contexts.Context'Class;
      File_Name : String;
      Requested : Posix_Tools.Numbers.Count;
      Origin    : Posix_Tools.Tail_Counts.Count_Origin;
      Ok        : out Boolean)
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
            begin
               if Last < Buffer'First then
                  return;
               end if;

               for I in Buffer'First .. Last loop
                  Position := Position + 1;
                  if Posix_Tools.Counts.Should_Emit_From_Start (Position, Requested) then
                     Context.Put (To_String (Buffer (I .. I), I));
                     exit when Context.Output_Failed;
                  end if;
               end loop;
            end Emit_From_Start;

            procedure Iterate is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
              (Action => Emit_From_Start);
         begin
            Iterate (Context, File_Name, Ok);
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

            procedure Iterate is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
              (Action => Ignore_Chunk);
         begin
            Iterate (Context, File_Name, Ok);
         end;
         return;
      elsif Requested > Context.Tail_Memory_Threshold
        or else Requested > Posix_Tools.Numbers.Count (Natural'Last)
      then
         Copy_With_Spill (Context, File_Name, Requested, Ok);
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
         begin
            if Last < Buffer'First then
               return;
            end if;

            for I in Buffer'First .. Last loop
               Keep_Byte (Ring, Filled, Next, Buffer (I));
            end loop;
         end Retain_Chunk;

         procedure Iterate is new Posix_Tools.Commands.File_Helpers.For_Each_Chunk
           (Action => Retain_Chunk);
      begin
         Iterate (Context, File_Name, Ok);
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
