with Posix_Tools.Text.Classification;

package body Posix_Tools.Streams.Counting
  with SPARK_Mode => On
is
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   procedure Increment (Value : in out Count_Value)
     with Post => Value = Saturating_Add (Value'Old, 1);

   procedure Note_Code_Point
     (Self       : in out Counter;
      Code_Point : Long_Long_Integer)
     with Post =>
       Self.Current.Bytes = Self.Current.Bytes'Old
       and then Self.Current.Characters >= Self.Current.Characters'Old
       and then Self.Current.Lines = Self.Current.Lines'Old
       and then Self.Current.Max_Line_Length >= Self.Current.Max_Line_Length'Old
       and then Self.Current.Words >= Self.Current.Words'Old
       and then Self.Invalid_Text = Self.Invalid_Text'Old;

   procedure Note_Invalid (Self : in out Counter)
     with Post =>
       Self.Current.Bytes = Self.Current.Bytes'Old
       and then Self.Current.Characters = Self.Current.Characters'Old
       and then Self.Current.Lines = Self.Current.Lines'Old
       and then Self.Current.Max_Line_Length = Self.Current.Max_Line_Length'Old
       and then Self.Current_Line_Length = Self.Current_Line_Length'Old
       and then Self.Current.Words = Self.Current.Words'Old
       and then Self.Invalid_Text;

   procedure Decode_Byte
     (Self : in out Counter;
      Byte : Natural)
     with Post =>
       Self.Current.Bytes = Self.Current.Bytes'Old
       and then Self.Current.Characters >= Self.Current.Characters'Old
       and then Self.Current.Lines = Self.Current.Lines'Old
       and then Self.Current.Max_Line_Length >= Self.Current.Max_Line_Length'Old
       and then Self.Current.Words >= Self.Current.Words'Old
       and then (if Self.Invalid_Text'Old then Self.Invalid_Text);

   procedure Increment (Value : in out Count_Value) is
   begin
      Value := Saturating_Add (Value, 1);
   end Increment;

   procedure Advance_Tab_Stop (Value : in out Count_Value) is
      Next : constant Count_Value := (Value / 8) + 1;
   begin
      if Next > Count_Value'Last / 8 then
         Value := Count_Value'Last;
      else
         Value := Next * 8;
      end if;
   end Advance_Tab_Stop;

   procedure Note_Code_Point
     (Self       : in out Counter;
      Code_Point : Long_Long_Integer)
   is
      procedure Finish_Line is
      begin
         if Self.Current_Line_Length > Self.Current.Max_Line_Length then
            Self.Current.Max_Line_Length := Self.Current_Line_Length;
         end if;
         Self.Current_Line_Length := 0;
      end Finish_Line;
   begin
      Increment (Self.Current.Characters);

      case Code_Point is
         when 10 =>
            Finish_Line;
         when 9 =>
            Advance_Tab_Stop (Self.Current_Line_Length);
         when 8 =>
            if Self.Current_Line_Length > 0 then
               Self.Current_Line_Length := Self.Current_Line_Length - 1;
            end if;
         when others =>
            Increment (Self.Current_Line_Length);
      end case;

      if Posix_Tools.Text.Classification.Is_Whitespace (Code_Point) then
         Self.In_Word := False;
      elsif not Self.In_Word then
         Increment (Self.Current.Words);
         Self.In_Word := True;
      end if;
   end Note_Code_Point;

   procedure Note_Invalid (Self : in out Counter) is
   begin
      Self.Invalid_Text := True;
      Self.In_Word := False;
   end Note_Invalid;

   procedure Decode_Byte
     (Self : in out Counter;
      Byte : Natural)
   is
      Status     : Posix_Tools.Text.UTF_8.Decode_Status;
      Code_Point : Long_Long_Integer;
   begin
      Posix_Tools.Text.UTF_8.Decode (Self.Decoder, Byte, Status, Code_Point);
      if Status = Posix_Tools.Text.UTF_8.Complete then
         Note_Code_Point (Self, Code_Point);
      elsif Status = Posix_Tools.Text.UTF_8.Invalid then
         Note_Invalid (Self);
      end if;
   end Decode_Byte;

   procedure Process (Self : in out Counter; Input : String) is
      Initial_Bytes : constant Count_Value := Self.Current.Bytes;
      Initial_Characters : constant Count_Value := Self.Current.Characters;
      Initial_Lines : constant Count_Value := Self.Current.Lines;
      Initial_Max_Line_Length : constant Count_Value := Self.Current.Max_Line_Length;
      Initially_Invalid : constant Boolean := Self.Invalid_Text;
      Initial_Words : constant Count_Value := Self.Current.Words;
   begin
      for I in Input'Range loop
         declare
            Ch : constant Character := Input (I);
         begin
            Increment (Self.Current.Bytes);

            if Ch = Character'Val (10) then
               Increment (Self.Current.Lines);
            end if;

            Decode_Byte (Self, Character'Pos (Ch));
         end;

         pragma Loop_Invariant
           (Self.Current.Bytes =
              Saturating_Add (Initial_Bytes, Count_Value (I - Input'First + 1)));
         pragma Loop_Invariant (Self.Current.Characters >= Initial_Characters);
         pragma Loop_Invariant (Self.Current.Lines >= Initial_Lines);
         pragma Loop_Invariant (Self.Current.Max_Line_Length >= Initial_Max_Line_Length);
         pragma Loop_Invariant (Self.Current.Words >= Initial_Words);
         pragma Loop_Invariant (if Initially_Invalid then Self.Invalid_Text);
      end loop;
   end Process;

   procedure Finish_Text (Self : in out Counter) is
      Initial_Line_Length : constant Count_Value := Self.Current_Line_Length;
      Initial_Max_Line_Length : constant Count_Value := Self.Current.Max_Line_Length;
      Status : Posix_Tools.Text.UTF_8.Decode_Status;
   begin
      Posix_Tools.Text.UTF_8.Finish (Self.Decoder, Status);
      if Status = Posix_Tools.Text.UTF_8.Invalid then
         Note_Invalid (Self);
      end if;

      if Initial_Line_Length > Initial_Max_Line_Length then
         Self.Current.Max_Line_Length := Initial_Line_Length;
      end if;
   end Finish_Text;

   function Snapshot (Self : Counter) return Counts is
   begin
      return Self.Current;
   end Snapshot;

   function Count_Bytes (Input : String) return Counts is
      State : Counter;
   begin
      Process (State, Input);
      return Snapshot (State);
   end Count_Bytes;
end Posix_Tools.Streams.Counting;
