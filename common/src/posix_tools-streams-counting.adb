with Posix_Tools.Text.Classification;

package body Posix_Tools.Streams.Counting is
   use type Posix_Tools.Text.UTF_8.Decode_Status;

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
      Self.Current.Characters := Self.Current.Characters + 1;

      case Code_Point is
         when 10 =>
            Finish_Line;
         when 9 =>
            Self.Current_Line_Length := ((Self.Current_Line_Length / 8) + 1) * 8;
         when 8 =>
            if Self.Current_Line_Length > 0 then
               Self.Current_Line_Length := Self.Current_Line_Length - 1;
            end if;
         when others =>
            Self.Current_Line_Length := Self.Current_Line_Length + 1;
      end case;

      if Posix_Tools.Text.Classification.Is_Whitespace (Code_Point) then
         Self.In_Word := False;
      elsif not Self.In_Word then
         Self.Current.Words := Self.Current.Words + 1;
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
   begin
      for Ch of Input loop
         Self.Current.Bytes := Self.Current.Bytes + 1;

         if Ch = Character'Val (10) then
            Self.Current.Lines := Self.Current.Lines + 1;
         end if;

         Decode_Byte (Self, Character'Pos (Ch));
      end loop;
   end Process;

   procedure Finish_Text (Self : in out Counter) is
      Status : Posix_Tools.Text.UTF_8.Decode_Status;
   begin
      Posix_Tools.Text.UTF_8.Finish (Self.Decoder, Status);
      if Status = Posix_Tools.Text.UTF_8.Invalid then
         Note_Invalid (Self);
      end if;

      if Self.Current_Line_Length > Self.Current.Max_Line_Length then
         Self.Current.Max_Line_Length := Self.Current_Line_Length;
      end if;
   end Finish_Text;

   function Snapshot (Self : Counter) return Counts is
   begin
      return Self.Current;
   end Snapshot;

   function Text_Invalid (Self : Counter) return Boolean is
   begin
      return Self.Invalid_Text;
   end Text_Invalid;

   function Count_Bytes (Input : String) return Counts is
      State : Counter;
   begin
      Process (State, Input);
      return Snapshot (State);
   end Count_Bytes;
end Posix_Tools.Streams.Counting;
