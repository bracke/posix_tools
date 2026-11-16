separate (Posix_Tools.Commands.Cut.Run.Cut_File)
procedure Cut_Chunks (Ok : out Boolean) is
   Position    : Positive := 1;
   Range_Index : Positive := Ranges.First_Index;
   Pending     : Unbounded_String;
   Saw_Data    : Boolean := False;
   Ended_In_LF : Boolean := True;

   procedure Flush;
   function Current_Selected return Boolean;
   procedure Each_Chunk
     (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
      Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset);

   procedure Flush is
   begin
      if Length (Pending) > 0 then
         Context.Put (To_String (Pending));
         Pending := Null_Unbounded_String;
      end if;
   end Flush;

   function Current_Selected return Boolean is
   begin
      while Range_Index <= Ranges.Last_Index
        and then Ranges.Element (Range_Index).Last /= 0
        and then Position > Ranges.Element (Range_Index).Last
      loop
         Range_Index := Range_Index + 1;
      end loop;
      return Range_Index <= Ranges.Last_Index
        and then Position >= Ranges.Element (Range_Index).First;
   end Current_Selected;

   procedure Each_Chunk
     (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
      Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Ignored);
      I : Ada.Streams.Stream_Element_Offset := Buffer'First;
   begin
      if Last < Buffer'First then
         return;
      end if;

      Saw_Data := True;
      while I <= Last loop
         if Buffer (I) = Ada.Streams.Stream_Element (10) then
            Append (Pending, Character'Val (10));
            Position := 1;
            Range_Index := Ranges.First_Index;
            Ended_In_LF := True;
            I := I + 1;
         else
            declare
               Selected_Run : constant Boolean := Current_Selected;
               Run_First    : constant Ada.Streams.Stream_Element_Offset := I;
               Bounded      : Boolean;
               Last_Position : Natural;
            begin
               if Selected_Run then
                  Last_Position := Ranges.Element (Range_Index).Last;
                  Bounded := Last_Position /= 0;
               elsif Range_Index <= Ranges.Last_Index then
                  Last_Position := Ranges.Element (Range_Index).First - 1;
                  Bounded := True;
               else
                  Last_Position := 0;
                  Bounded := False;
               end if;

               while I <= Last
                 and then Buffer (I) /= Ada.Streams.Stream_Element (10)
                 and then (not Bounded or else Position <= Last_Position)
               loop
                  Position := Position + 1;
                  I := I + 1;
               end loop;

               if Selected_Run then
                  Append
                    (Pending,
                     Posix_Tools.Streams.Bytes.To_String
                       (Buffer (Run_First .. I - 1), I - 1));
               end if;
               Ended_In_LF := False;
            end;
         end if;
         if Length (Pending) >= 64 * 1024 then
            Flush;
         end if;
         exit when Context.Output_Failed;
      end loop;
   end Each_Chunk;

   procedure Iterate_Chunks is new
     Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
       (Action        => Each_Chunk,
        Buffer_Length =>
          Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
begin
   Iterate_Chunks (Context, Name, Ok);
   if Ok and then Saw_Data and then not Ended_In_LF then
      Append (Pending, Character'Val (10));
   end if;
   Flush;
   Ok := Ok and then not Context.Output_Failed;
end Cut_Chunks;
