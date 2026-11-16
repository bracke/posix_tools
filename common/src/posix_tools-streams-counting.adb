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

   --  A sequence that is not UTF-8 is one character, not blank.
   procedure Note_Invalid (Self : in out Counter)
     with Post =>
       Self.Current.Bytes = Self.Current.Bytes'Old
       and then Self.Current.Characters >= Self.Current.Characters'Old
       and then Self.Current.Lines = Self.Current.Lines'Old
       and then Self.Current.Max_Line_Length >= Self.Current.Max_Line_Length'Old
       and then Self.Current.Words >= Self.Current.Words'Old
       and then Self.Invalid_Text;

   --  Stands in for a character that is not blank and one column wide.
   Not_Blank : constant Long_Long_Integer := 16#FFFD#;

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

      if (if Code_Point <= 16#7F#
          then Code_Point in 9 .. 13 | 32
          else Posix_Tools.Text.Classification.Is_Whitespace (Code_Point))
      then
         Self.In_Word := False;
      elsif not Self.In_Word then
         Increment (Self.Current.Words);
         Self.In_Word := True;
      end if;
   end Note_Code_Point;

   procedure Note_Invalid (Self : in out Counter) is
   begin
      Note_Code_Point (Self, Not_Blank);
      Self.Invalid_Text := True;
   end Note_Invalid;

   procedure Count_Single_Bytes (Self : in out Counter) is
   begin
      Self.Single_Byte := True;
   end Count_Single_Bytes;

   procedure Decode_Byte
     (Self : in out Counter;
      Byte : Natural)
   is
      Status     : Posix_Tools.Text.UTF_8.Decode_Status;
      Code_Point : Long_Long_Integer;
      Consumed   : Boolean;
   begin
      if Self.Single_Byte then
         Note_Code_Point (Self, (if Byte < 128 then Long_Long_Integer (Byte) else Not_Blank));
         return;
      end if;

      --  ASCII is already a complete UTF-8 character when no multibyte
      --  sequence is pending. This is overwhelmingly the common path and
      --  avoids running the decoder for every byte of ordinary text.
      if Byte <= 16#7F# and then Posix_Tools.Text.UTF_8.Is_Initial (Self.Decoder) then
         Note_Code_Point (Self, Long_Long_Integer (Byte));
         return;
      end if;

      Posix_Tools.Text.UTF_8.Decode (Self.Decoder, Byte, Status, Code_Point, Consumed);
      if Status = Posix_Tools.Text.UTF_8.Complete then
         Note_Code_Point (Self, Code_Point);
      elsif Status = Posix_Tools.Text.UTF_8.Invalid then
         Note_Invalid (Self);
      end if;

      --  A byte that ended a sequence it could not carry on is counted
      --  again for what it is: "\xC3A" is an invalid byte and an A.
      if not Consumed then
         Posix_Tools.Text.UTF_8.Decode (Self.Decoder, Byte, Status, Code_Point);
         if Status = Posix_Tools.Text.UTF_8.Complete then
            Note_Code_Point (Self, Code_Point);
         elsif Status = Posix_Tools.Text.UTF_8.Invalid then
            Note_Invalid (Self);
         end if;
      end if;
   end Decode_Byte;

   procedure Process (Self : in out Counter; Input : String) is
      Initial_Bytes : constant Count_Value := Self.Current.Bytes;
      Initial_Characters : constant Count_Value := Self.Current.Characters;
      Initial_Lines : constant Count_Value := Self.Current.Lines;
      Initial_Max_Line_Length : constant Count_Value := Self.Current.Max_Line_Length;
      Initially_Invalid : constant Boolean := Self.Invalid_Text;
      Initial_Words : constant Count_Value := Self.Current.Words;
      Processed : Natural := 0;

      function Plain_ASCII (Ch : Character) return Boolean is
        (Character'Pos (Ch) <= 16#7F#
         and then Character'Pos (Ch) not in 8 .. 13 | 32);

      procedure Add (Value : in out Count_Value; Amount : Natural) is
      begin
         Value := Saturating_Add (Value, Count_Value (Amount));
      end Add;
   begin
      --  The byte count does not depend on decoding; add the whole chunk
      --  once instead of performing a saturating addition for every byte.
      Self.Current.Bytes :=
        Saturating_Add (Self.Current.Bytes, Count_Value (Input'Length));

      while Processed < Input'Length loop
         declare
            I  : constant Integer := Input'First + Processed;
            Ch : constant Character := Input (I);
         begin
            if Posix_Tools.Text.UTF_8.Is_Initial (Self.Decoder)
              and then Plain_ASCII (Ch)
            then
               declare
                  Run : Natural := 1;
               begin
                  while Processed + Run < Input'Length
                    and then Plain_ASCII (Input (I + Run))
                  loop
                     Run := Run + 1;
                     pragma Loop_Invariant
                       (Processed + Run <= Input'Length);
                     pragma Loop_Variant (Increases => Run);
                  end loop;

                  Add (Self.Current.Characters, Run);
                  Add (Self.Current_Line_Length, Run);
                  if not Self.In_Word then
                     Increment (Self.Current.Words);
                     Self.In_Word := True;
                  end if;
                  Processed := Processed + Run;
               end;
            elsif Posix_Tools.Text.UTF_8.Is_Initial (Self.Decoder)
              and then Ch = ' '
            then
               declare
                  Run : Natural := 1;
               begin
                  while Processed + Run < Input'Length
                    and then Input (I + Run) = ' '
                  loop
                     Run := Run + 1;
                     pragma Loop_Invariant
                       (Processed + Run <= Input'Length);
                     pragma Loop_Variant (Increases => Run);
                  end loop;

                  Add (Self.Current.Characters, Run);
                  Add (Self.Current_Line_Length, Run);
                  Self.In_Word := False;
                  Processed := Processed + Run;
               end;
            else
               if Ch = Character'Val (10) then
                  Increment (Self.Current.Lines);
               end if;

               Decode_Byte (Self, Character'Pos (Ch));
               Processed := Processed + 1;
            end if;
         end;

         pragma Loop_Invariant
           (Self.Current.Bytes =
              Saturating_Add (Initial_Bytes, Count_Value (Input'Length)));
         pragma Loop_Invariant (Self.Current.Characters >= Initial_Characters);
         pragma Loop_Invariant (Self.Current.Lines >= Initial_Lines);
         pragma Loop_Invariant (Self.Current.Max_Line_Length >= Initial_Max_Line_Length);
         pragma Loop_Invariant (Self.Current.Words >= Initial_Words);
         pragma Loop_Invariant (if Initially_Invalid then Self.Invalid_Text);
         pragma Loop_Invariant (Processed <= Input'Length);
         pragma Loop_Variant (Increases => Processed);
      end loop;
   end Process;

   procedure Finish_Text (Self : in out Counter) is
      Initial_Line_Length : constant Count_Value := Self.Current_Line_Length;
      Status : Posix_Tools.Text.UTF_8.Decode_Status;
   begin
      Posix_Tools.Text.UTF_8.Finish (Self.Decoder, Status);
      if Status = Posix_Tools.Text.UTF_8.Invalid then
         Note_Invalid (Self);
      end if;

      if Initial_Line_Length > Self.Current.Max_Line_Length then
         Self.Current.Max_Line_Length := Initial_Line_Length;
      end if;
      if Self.Current_Line_Length > Self.Current.Max_Line_Length then
         Self.Current.Max_Line_Length := Self.Current_Line_Length;
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
