with Ada.Streams;
with Ada.Strings.Unbounded;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.File_Magic_Fields;
with Posix_Tools.Text.Matching;

package body Posix_Tools.Text.File_Descriptions is
   use Ada.Strings.Unbounded;

   NUL : constant Character := Character'Val (0);
   HT  : constant Character := Character'Val (9);
   LF  : constant Character := Character'Val (10);
   CR  : constant Character := Character'Val (13);

   function Contains_At (Text : String; Offset : Natural; Needle : String) return Boolean;

   function Decoded_Literal (Text : String; Ok : out Boolean) return String;

   function Is_Text_Byte (Byte : Ada.Streams.Stream_Element) return Boolean;

   function Magic_Description
     (Data       : String;
      Mime_Mode  : Boolean;
      Magic_Text : String;
      Found      : out Boolean) return String;

   function Contains_At (Text : String; Offset : Natural; Needle : String) return Boolean is
   begin
      if Text = "" or else Offset >= Text'Length then
         return False;
      end if;

      declare
         Start : constant Positive := Text'First + Offset;
      begin
         return Posix_Tools.Text.Matching.Starts_With_At (Text, Needle, Start);
      end;
   end Contains_At;

   function Content_Description
     (Data       : String;
      Mime_Mode  : Boolean;
      Magic_Text : String;
      Has_Magic  : Boolean) return String
   is
      Saw_Byte : Boolean := False;
      Saw_NUL  : Boolean := False;
      Saw_Text : Boolean := True;
   begin
      if Has_Magic then
         declare
            Found : Boolean;
            Text  : constant String := Magic_Description (Data, Mime_Mode, Magic_Text, Found);
         begin
            if Found then
               return Text;
            end if;
         end;
      end if;

      if Data = "" then
         return (if Mime_Mode then "inode/x-empty" else "empty");
      elsif Posix_Tools.Text.Matching.Starts_With (Data, "%PDF-") then
         return (if Mime_Mode then "application/pdf" else "PDF document");
      elsif Posix_Tools.Text.Matching.Starts_With (Data, Character'Val (16#7F#) & "ELF") then
         return (if Mime_Mode then "application/x-elf" else "ELF executable");
      elsif Posix_Tools.Text.Matching.Starts_With
        (Data, Character'Val (16#89#) & "PNG" & CR & LF & Character'Val (16#1A#) & LF)
      then
         return (if Mime_Mode then "image/png" else "PNG image data");
      elsif Posix_Tools.Text.Matching.Starts_With (Data, "GIF87a")
        or else Posix_Tools.Text.Matching.Starts_With (Data, "GIF89a")
      then
         return (if Mime_Mode then "image/gif" else "GIF image data");
      elsif Posix_Tools.Text.Matching.Starts_With
        (Data, "PK" & Character'Val (3) & Character'Val (4))
      then
         return (if Mime_Mode then "application/zip" else "Zip archive data");
      elsif Posix_Tools.Text.Matching.Starts_With
        (Data, Character'Val (16#1F#) & Character'Val (16#8B#))
      then
         return (if Mime_Mode then "application/gzip" else "gzip compressed data");
      elsif Contains_At (Data, 257, "ustar") then
         return (if Mime_Mode then "application/x-tar" else "tar archive data");
      elsif Posix_Tools.Text.Matching.Starts_With (Data, "#!") then
         return (if Mime_Mode then "text/x-script" else "script text executable");
      end if;

      for Ch of Data loop
         Saw_Byte := True;
         if Ch = NUL then
            Saw_NUL := True;
         elsif not Is_Text_Byte (Ada.Streams.Stream_Element (Character'Pos (Ch))) then
            Saw_Text := False;
         end if;
      end loop;

      if not Saw_Byte then
         return (if Mime_Mode then "inode/x-empty" else "empty");
      elsif Saw_NUL or else not Saw_Text then
         return (if Mime_Mode then "application/octet-stream" else "data");
      else
         return (if Mime_Mode then "text/plain" else "text");
      end if;
   end Content_Description;

   function Decoded_Literal (Text : String; Ok : out Boolean) return String is
      Result : Unbounded_String;
      I      : Positive := Text'First;
      High   : Natural;
      Low    : Natural;
   begin
      Ok := True;
      if Text = "" then
         return "";
      end if;

      while I <= Text'Last loop
         if Text (I) /= '\' then
            Append (Result, Text (I));
            I := I + 1;
         elsif I = Text'Last then
            Ok := False;
            return "";
         else
            case Text (I + 1) is
               when '0' =>
                  Append (Result, NUL);
                  I := I + 2;
               when 'n' =>
                  Append (Result, LF);
                  I := I + 2;
               when 'r' =>
                  Append (Result, CR);
                  I := I + 2;
               when 't' =>
                  Append (Result, HT);
                  I := I + 2;
               when '\' | ':' =>
                  Append (Result, Text (I + 1));
                  I := I + 2;
               when 'x' =>
                  if I + 3 > Text'Last
                    or else not Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit (Text (I + 2))
                    or else not Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit (Text (I + 3))
                  then
                     Ok := False;
                     return "";
                  end if;
                  High := Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Value (Text (I + 2));
                  Low := Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Value (Text (I + 3));
                  Append (Result, Character'Val (High * 16 + Low));
                  I := I + 4;
               when others =>
                  Ok := False;
                  return "";
            end case;
         end if;
      end loop;

      return To_String (Result);
   end Decoded_Literal;

   function Is_Text_Byte (Byte : Ada.Streams.Stream_Element) return Boolean is
      Ch : constant Character := Character'Val (Byte);
   begin
      return Posix_Tools.Text.Byte_Classes.Is_File_Text_Byte (Ch);
   end Is_Text_Byte;

   function Magic_Description
     (Data       : String;
      Mime_Mode  : Boolean;
      Magic_Text : String;
      Found      : out Boolean) return String
   is
      Start : Positive := Magic_Text'First;

      function Match_Line (Line : String; Description : out Unbounded_String) return Boolean;

      function Match_Line (Line : String; Description : out Unbounded_String) return Boolean is
         First_Field  : Posix_Tools.Text.File_Magic_Fields.Magic_Field;
         Second_Field : Posix_Tools.Text.File_Magic_Fields.Magic_Field;
         Third_Field  : Posix_Tools.Text.File_Magic_Fields.Magic_Field;
         Offset       : Posix_Tools.Text.Decimal_Parsing.Parsed_Natural;
         Literal_Ok   : Boolean;
      begin
         Description := Null_Unbounded_String;
         if Line = "" or else Line (Line'First) = '#' then
            return False;
         end if;

         First_Field := Posix_Tools.Text.File_Magic_Fields.Next_Field (Line, Line'First);
         if First_Field.At_End then
            return False;
         end if;
         Second_Field :=
           Posix_Tools.Text.File_Magic_Fields.Next_Field (Line, First_Field.Next);
         if Second_Field.At_End then
            return False;
         end if;
         Third_Field :=
           Posix_Tools.Text.File_Magic_Fields.Next_Field (Line, Second_Field.Next);

         Offset := Posix_Tools.Text.Decimal_Parsing.Natural_Value
           (Line (Line'First .. First_Field.Last));
         if not Offset.Valid then
            return False;
         end if;

         declare
            Literal : constant String :=
              Decoded_Literal
                (Line (First_Field.Next .. Second_Field.Last), Literal_Ok);
         begin
            if not Literal_Ok
              or else Literal = ""
              or else not Contains_At (Data, Offset.Value, Literal)
            then
               return False;
            end if;
         end;

         if Mime_Mode and then not Third_Field.At_End then
            Description := To_Unbounded_String (Line (Third_Field.Next .. Line'Last));
         else
            Description :=
              To_Unbounded_String
                (Line (Second_Field.Next .. Third_Field.Last));
         end if;
         return To_String (Description) /= "";
      end Match_Line;
   begin
      Found := False;
      if Magic_Text = "" then
         return "";
      end if;

      while Start <= Magic_Text'Last loop
         declare
            Stop : Natural := Start;
            Text : Unbounded_String;
         begin
            while Stop <= Magic_Text'Last and then Magic_Text (Stop) /= LF loop
               Stop := Stop + 1;
            end loop;

            if Match_Line (Magic_Text (Start .. Stop - 1), Text) then
               Found := True;
               return To_String (Text);
            end if;
            Start := Stop + 1;
         end;
      end loop;

      return "";
   end Magic_Description;
end Posix_Tools.Text.File_Descriptions;
