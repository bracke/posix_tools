separate (Posix_Tools.Commands.Cut.Run.Cut_File)
procedure Cut_Character_Chunks (Ok : out Boolean) is
   Position    : Positive := 1;
   Range_Index : Positive := Ranges.First_Index;
   Pending     : Unbounded_String;
   Carry       : Unbounded_String;
   Saw_Data    : Boolean := False;
   Ended_In_LF : Boolean := True;

   procedure Flush;
   function Current_Selected return Boolean;
   function Whole_Character_Selected (Last_Byte : Positive) return Boolean;
   procedure Process (Data : String; At_End : Boolean);
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

   function Whole_Character_Selected
     (Last_Byte : Positive) return Boolean
   is
   begin
      while Range_Index <= Ranges.Last_Index
        and then Ranges.Element (Range_Index).Last /= 0
        and then Ranges.Element (Range_Index).Last < Last_Byte
      loop
         Range_Index := Range_Index + 1;
      end loop;
      return Range_Index <= Ranges.Last_Index
        and then Ranges.Element (Range_Index).First <= Last_Byte;
   end Whole_Character_Selected;

   procedure Process (Data : String; At_End : Boolean) is
      Index      : Positive := Data'First;
      Width      : Natural;
      Code_Point : Long_Long_Integer;
      Keep       : Boolean;
   begin
      while Index <= Data'Last loop
         Saw_Data := True;
         if Data (Index) = Character'Val (10) then
            Append (Pending, Character'Val (10));
            Position := 1;
            Range_Index := Ranges.First_Index;
            Ended_In_LF := True;
            Index := Index + 1;
         elsif Character'Pos (Data (Index)) <= 16#7F# then
            declare
               Selected_Run : constant Boolean := Current_Selected;
               Run_First    : constant Positive := Index;
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

               while Index <= Data'Last
                 and then Data (Index) /= Character'Val (10)
                 and then Character'Pos (Data (Index)) <= 16#7F#
                 and then (not Bounded or else Position <= Last_Position)
               loop
                  Position := Position + 1;
                  Index := Index + 1;
               end loop;

               if Selected_Run then
                  Append (Pending, Data (Run_First .. Index - 1));
               end if;
               Ended_In_LF := False;
            end;
         else
            Posix_Tools.Commands.Text_Helpers.Tr_Sets.Decode_At
              (Data, Index, At_End, Width, Code_Point);
            if Width = 0 then
               Carry := To_Unbounded_String
                 (Data (Index .. Data'Last));
               return;
            end if;

            Keep :=
              (if Mode = 'c' or else Width = 1
               then Current_Selected
               else Whole_Character_Selected
                 (Position + Width - 1));
            if Keep then
               Append (Pending, Data (Index .. Index + Width - 1));
            end if;
            Position := Position + (if Mode = 'c' then 1 else Width);
            Index := Index + Width;
            Ended_In_LF := False;
         end if;

         if Length (Pending) >= 64 * 1024 then
            Flush;
         end if;
         exit when Context.Output_Failed;
      end loop;
   end Process;

   procedure Each_Chunk
     (Ignored : in out Posix_Tools.Commands.Contexts.Context'Class;
      Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset)
   is
      pragma Unreferenced (Ignored);
      Data : constant String :=
        (if Length (Carry) = 0
         then Posix_Tools.Streams.Bytes.To_String (Buffer, Last)
         else To_String (Carry)
           & Posix_Tools.Streams.Bytes.To_String (Buffer, Last));
   begin
      Carry := Null_Unbounded_String;
      Process (Data, At_End => False);
   end Each_Chunk;

   procedure Iterate_Chunks is new
     Posix_Tools.Commands.File_Helpers.Streaming.For_Each_Chunk
       (Action        => Each_Chunk,
        Buffer_Length =>
          Posix_Tools.Commands.File_Helpers.Streaming.Bulk_Buffer_Length);
begin
   Iterate_Chunks (Context, Name, Ok);
   if Ok and then Length (Carry) > 0 then
      declare
         Final_Data : constant String := To_String (Carry);
      begin
         Carry := Null_Unbounded_String;
         Process (Final_Data, At_End => True);
      end;
   end if;
   if Ok and then Saw_Data and then not Ended_In_LF then
      Append (Pending, Character'Val (10));
   end if;
   Flush;
   Ok := Ok and then not Context.Output_Failed;
end Cut_Character_Chunks;
