with Ada.Strings.Unbounded;
with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Rg.Json is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   function Base64 (Text : String) return String;
   function Duration_Value (Value : Duration; Sorted : Boolean := False) return String;
   function Escape (Text : String) return String;
   function Is_UTF_8 (Text : String) return Boolean;
   function Natural_Image (Value : Natural) return String;

   function Natural_Image (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Image;

   function Base64 (Text : String) return String is
      Alphabet : constant String :=
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      Result : Unbounded_String;
      Position : Positive := Text'First;
   begin
      while Position <= Text'Last loop
         declare
            Remaining : constant Natural := Text'Last - Position + 1;
            First_Byte : constant Natural := Character'Pos (Text (Position));
            Second_Byte : constant Natural :=
              (if Remaining >= 2 then Character'Pos (Text (Position + 1)) else 0);
            Third_Byte : constant Natural :=
              (if Remaining >= 3 then Character'Pos (Text (Position + 2)) else 0);
         begin
            Append (Result, Alphabet (First_Byte / 4 + 1));
            Append (Result, Alphabet ((First_Byte mod 4) * 16 + Second_Byte / 16 + 1));
            Append
              (Result,
               (if Remaining >= 2
                then Alphabet ((Second_Byte mod 16) * 4 + Third_Byte / 64 + 1)
                else '='));
            Append
              (Result,
               (if Remaining >= 3 then Alphabet (Third_Byte mod 64 + 1) else '='));
            Position := Position + Natural'Min (3, Remaining);
         end;
      end loop;
      return To_String (Result);
   end Base64;

   function Is_UTF_8 (Text : String) return Boolean is
      Decoder : Posix_Tools.Text.UTF_8.Decoder;
      Status : Posix_Tools.Text.UTF_8.Decode_Status;
      Code_Point : Long_Long_Integer;
      Consumed : Boolean;
   begin
      for Item of Text loop
         Posix_Tools.Text.UTF_8.Decode
           (Decoder, Character'Pos (Item), Status, Code_Point, Consumed);
         if Status = Posix_Tools.Text.UTF_8.Invalid or else not Consumed then
            return False;
         end if;
      end loop;
      Posix_Tools.Text.UTF_8.Finish (Decoder, Status);
      return Status = Posix_Tools.Text.UTF_8.Complete;
   end Is_UTF_8;

   function Escape (Text : String) return String is
      Result : Unbounded_String;
      Hex : constant String := "0123456789abcdef";
   begin
      for Item of Text loop
         case Item is
            when '"' => Append (Result, "\""");
            when '\' => Append (Result, "\\");
            when ASCII.BS => Append (Result, "\b");
            when ASCII.HT => Append (Result, "\t");
            when ASCII.LF => Append (Result, "\n");
            when ASCII.FF => Append (Result, "\f");
            when ASCII.CR => Append (Result, "\r");
            when Character'Val (0) .. Character'Val (7)
               | Character'Val (11)
               | Character'Val (14) .. Character'Val (31) =>
               Append (Result, "\u00");
               Append (Result, Hex (Character'Pos (Item) / 16 + 1));
               Append (Result, Hex (Character'Pos (Item) mod 16 + 1));
            when others =>
               Append (Result, Item);
         end case;
      end loop;
      return To_String (Result);
   end Escape;

   function Text_Value (Text : String) return String is
   begin
      return
        (if Is_UTF_8 (Text)
         then "{""text"":""" & Escape (Text) & """}"
         else "{""bytes"":""" & Base64 (Text) & """}");
   end Text_Value;

   function Duration_Value (Value : Duration; Sorted : Boolean := False) return String is
      Total_Nanoseconds : constant Long_Long_Integer :=
        Long_Long_Integer (Long_Long_Float (Duration'Max (0.0, Value)) * 1_000_000_000.0);
      Seconds : constant Natural := Natural (Total_Nanoseconds / 1_000_000_000);
      Nanoseconds : constant Natural := Natural (Total_Nanoseconds mod 1_000_000_000);
      Microseconds : constant Natural := Nanoseconds / 1_000;
      Fraction_Image : constant String := Natural_Image (Microseconds);
      Padding : constant Natural := 6 - Fraction_Image'Length;
   begin
      declare
         Human : constant String :=
           Natural_Image (Seconds) & "." & String'(1 .. Padding => '0') & Fraction_Image & "s";
      begin
         return
           (if Sorted
            then "{""human"":""" & Human & """,""nanos"":" & Natural_Image (Nanoseconds)
              & ",""secs"":" & Natural_Image (Seconds) & "}"
            else "{""secs"":" & Natural_Image (Seconds)
              & ",""nanos"":" & Natural_Image (Nanoseconds)
              & ",""human"":""" & Human & """}");
      end;
   end Duration_Value;

   function Begin_Event (Path : String) return String is
   begin
      return "{""type"":""begin"",""data"":{""path"":" & Text_Value (Path) & "}}";
   end Begin_Event;

   function Submatch
     (Matched         : String;
      First           : Natural;
      Last            : Natural;
      Replacement     : String := "";
      Has_Replacement : Boolean := False) return String is
   begin
      return
        "{""match"":" & Text_Value (Matched)
        & (if Has_Replacement then ",""replacement"":" & Text_Value (Replacement) else "")
        & ",""start"":" & Natural_Image (First)
        & ",""end"":" & Natural_Image (Last) & "}";
   end Submatch;

   function Line_Event
     (Kind            : String;
      Path            : String;
      Line            : String;
      Terminated      : Boolean;
      Line_Number     : Positive;
      Absolute_Offset : Natural;
      Submatches      : String;
      Terminator      : Character := ASCII.LF) return String is
   begin
      return
        "{""type"":""" & Escape (Kind) & """,""data"":{""path"":" & Text_Value (Path)
        & ",""lines"":" & Text_Value (Line & (if Terminated then String'(1 => Terminator) else ""))
        & ",""line_number"":" & Natural_Image (Line_Number)
        & ",""absolute_offset"":" & Natural_Image (Absolute_Offset)
        & ",""submatches"":[" & Submatches & "]}}";
   end Line_Event;

   function Stats
     (Elapsed             : Duration;
      Searches            : Natural;
      Searches_With_Match : Natural;
      Bytes_Searched      : Natural;
      Bytes_Printed       : Natural;
      Matched_Lines       : Natural;
      Matches             : Natural) return String is
   begin
      return
        "{""elapsed"":" & Duration_Value (Elapsed)
        & ",""searches"":" & Natural_Image (Searches)
        & ",""searches_with_match"":" & Natural_Image (Searches_With_Match)
        & ",""bytes_searched"":" & Natural_Image (Bytes_Searched)
        & ",""bytes_printed"":" & Natural_Image (Bytes_Printed)
        & ",""matched_lines"":" & Natural_Image (Matched_Lines)
        & ",""matches"":" & Natural_Image (Matches) & "}";
   end Stats;

   function End_Event
     (Path             : String;
      Elapsed          : Duration;
      Bytes_Searched   : Natural;
      Bytes_Printed    : Natural;
      Matched_Lines    : Natural;
      Matches          : Natural;
      Search_Had_Match : Boolean;
      Binary_Offset    : Natural := 0;
      Has_Binary_Offset : Boolean := False) return String is
   begin
      return
        "{""type"":""end"",""data"":{""path"":" & Text_Value (Path)
        & ",""binary_offset"":"
        & (if Has_Binary_Offset then Natural_Image (Binary_Offset) else "null")
        & ",""stats"":"
        & Stats
          (Elapsed,
           Searches => 1,
           Searches_With_Match => (if Search_Had_Match then 1 else 0),
           Bytes_Searched => Bytes_Searched,
           Bytes_Printed => Bytes_Printed,
           Matched_Lines => Matched_Lines,
           Matches => Matches)
        & "}}";
   end End_Event;

   function Summary_Event
     (Elapsed_Total       : Duration;
      Search_Elapsed      : Duration;
      Searches            : Natural;
      Searches_With_Match : Natural;
      Bytes_Searched      : Natural;
      Bytes_Printed       : Natural;
      Matched_Lines       : Natural;
      Matches             : Natural) return String is
   begin
      return
        "{""data"":{""elapsed_total"":" & Duration_Value (Elapsed_Total, Sorted => True)
        & ",""stats"":{""bytes_printed"":" & Natural_Image (Bytes_Printed)
        & ",""bytes_searched"":" & Natural_Image (Bytes_Searched)
        & ",""elapsed"":" & Duration_Value (Search_Elapsed, Sorted => True)
        & ",""matched_lines"":" & Natural_Image (Matched_Lines)
        & ",""matches"":" & Natural_Image (Matches)
        & ",""searches"":" & Natural_Image (Searches)
        & ",""searches_with_match"":" & Natural_Image (Searches_With_Match) & "}"
        & "},""type"":""summary""}";
   end Summary_Event;
end Posix_Tools.Commands.Rg.Json;
