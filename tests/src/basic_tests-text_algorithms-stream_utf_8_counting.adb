with AUnit.Assertions;
with Interfaces;
with Posix_Tools.Streams.Counting;
with Posix_Tools.Text.Byte_Classes;
with Posix_Tools.Text.Checksum_Lines;
with Posix_Tools.Text.Checksums;
with Posix_Tools.Text.Classification;
with Posix_Tools.Text.UTF_8;

package body Basic_Tests.Text_Algorithms.Stream_UTF_8_Counting is
   use type Interfaces.Unsigned_32;
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   procedure Run (T : in out Fixture) is
      pragma Unreferenced (T);
      State  : Posix_Tools.Streams.Counting.Counter;
      Bad_State : Posix_Tools.Streams.Counting.Counter;
      Surrogate_State : Posix_Tools.Streams.Counting.Counter;
      Out_Of_Range_State : Posix_Tools.Streams.Counting.Counter;
      Counts : Posix_Tools.Streams.Counting.Counts;
   begin
      Posix_Tools.Streams.Counting.Process (State, "A ");
      Posix_Tools.Streams.Counting.Process (State, Character'Val (16#C3#) & Character'Val (16#A6#));
      Posix_Tools.Streams.Counting.Process
        (State, Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#83#) & "B");
      Posix_Tools.Streams.Counting.Finish_Text (State);
      Counts := Posix_Tools.Streams.Counting.Snapshot (State);

      AUnit.Assertions.Assert (not Posix_Tools.Streams.Counting.Text_Invalid (State), "valid UTF-8");
      AUnit.Assertions.Assert (Counts.Bytes = 8, "UTF-8 byte count");
      AUnit.Assertions.Assert (Counts.Characters = 5, "UTF-8 character count");
      AUnit.Assertions.Assert (Counts.Words = 3, "Unicode whitespace separates words");

      Posix_Tools.Streams.Counting.Process (Bad_State, "" & Character'Val (16#C3#));
      Posix_Tools.Streams.Counting.Finish_Text (Bad_State);
      AUnit.Assertions.Assert (Posix_Tools.Streams.Counting.Text_Invalid (Bad_State), "incomplete UTF-8");

      Posix_Tools.Streams.Counting.Process
        (Surrogate_State,
         Character'Val (16#ED#) & Character'Val (16#A0#) & Character'Val (16#80#));
      Posix_Tools.Streams.Counting.Finish_Text (Surrogate_State);
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Text_Invalid (Surrogate_State),
         "surrogate UTF-8 rejected");

      Posix_Tools.Streams.Counting.Process
        (Out_Of_Range_State,
         Character'Val (16#F4#) & Character'Val (16#90#)
         & Character'Val (16#80#) & Character'Val (16#80#));
      Posix_Tools.Streams.Counting.Finish_Text (Out_Of_Range_State);
      AUnit.Assertions.Assert
        (Posix_Tools.Streams.Counting.Text_Invalid (Out_Of_Range_State),
         "out-of-range UTF-8 rejected");

      declare
         Decoder : Posix_Tools.Text.UTF_8.Decoder;
         Status  : Posix_Tools.Text.UTF_8.Decode_Status;
         Code    : Long_Long_Integer;
      begin
         AUnit.Assertions.Assert
           (Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder starts initial");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#E2#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Need_More, "decoder first byte waits");
         AUnit.Assertions.Assert
           (not Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder carries partial sequence");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#82#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Need_More, "decoder second byte waits");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#AC#, Status, Code);
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Text.UTF_8.Complete and then Code = 16#20AC#,
            "decoder completes euro sign");
         AUnit.Assertions.Assert
           (Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder resets after complete sequence");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#C0#, Status, Code);
         AUnit.Assertions.Assert (Status = Posix_Tools.Text.UTF_8.Invalid, "decoder rejects overlong starter");
         AUnit.Assertions.Assert
           (Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder resets after invalid starter");
         Posix_Tools.Text.UTF_8.Decode (Decoder, 16#E2#, Status, Code);
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos ('A'), Status, Code);
         AUnit.Assertions.Assert
           (Status = Posix_Tools.Text.UTF_8.Invalid
            and then Posix_Tools.Text.UTF_8.Is_Initial (Decoder),
            "decoder rejects invalid continuation and resets");
      end;

      AUnit.Assertions.Assert
        (Same_Text (Posix_Tools.Text.Classification.Unicode_Version, "15.1.0"),
         "classification Unicode version recorded");
      AUnit.Assertions.Assert
        (Same_Text
           (Posix_Tools.Text.Classification.Unicode_Source,
            "Unicode Character Database PropList.txt White_Space property"),
         "classification Unicode source recorded");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Classification.Is_Whitespace (16#2003#),
         "classification includes em space");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Whitespace (Character'Pos ('A')),
         "classification excludes letter");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Classification.Is_Unicode_Scalar (16#10FFFF#),
         "classification accepts maximum Unicode scalar");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Unicode_Scalar (16#D800#),
         "classification rejects surrogate scalar");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Unicode_Scalar (16#110000#),
         "classification rejects value above Unicode range");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Whitespace (16#D800#),
         "classification rejects surrogate whitespace");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Classification.Is_Whitespace (-1),
         "classification rejects negative whitespace");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (' '),
         "xargs blank accepts space");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Character'Val (9)),
         "xargs blank accepts horizontal tab");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Character'Val (10)),
         "xargs blank accepts LF");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank (Character'Val (13)),
         "xargs blank rejects CR");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Byte_Classes.Is_Xargs_Blank ('A'),
         "xargs blank rejects ordinary text");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric ('9')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric ('Z')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric ('a'),
         "ASCII alphanumeric accepts digits and letters");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Alpha ('Z')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Alpha ('a')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Alpha ('9'),
         "ASCII alpha accepts only letters");
      AUnit.Assertions.Assert
        (not Posix_Tools.Text.Byte_Classes.Is_ASCII_Alphanumeric ('_'),
         "ASCII alphanumeric rejects punctuation");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Control (Character'Val (0))
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Control (Character'Val (127))
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Control (' '),
         "ASCII control range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit ('5')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Digit ('A'),
         "ASCII digit range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit ('7')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Octal_Digit ('8'),
         "ASCII octal digit range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Graph ('!')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Graph (' '),
         "ASCII graph excludes space");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower ('z')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower ('Z'),
         "ASCII lower range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Printable ('~')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Printable (Character'Val (127)),
         "ASCII printable range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Punctuation ('!')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Punctuation ('A'),
         "ASCII punctuation range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper ('A')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper ('a'),
         "ASCII upper range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.To_ASCII_Upper ('z') = 'Z'
         and then Posix_Tools.Text.Byte_Classes.To_ASCII_Lower ('A') = 'a',
         "ASCII case conversion values");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit ('F')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit ('f')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Hex_Digit ('G'),
         "ASCII hex digit range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper_Hex_Digit ('F')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Upper_Hex_Digit ('f')
         and then Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower_Hex_Digit ('f')
         and then not Posix_Tools.Text.Byte_Classes.Is_ASCII_Lower_Hex_Digit ('F'),
         "ASCII split hex digit ranges");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.ASCII_Digit_Value ('9') = 9
         and then Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character (0) = '0'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Digit_Character (9) = '9'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Lowercase_Character (0) = 'a'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Lowercase_Character (25) = 'z'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Value ('7') = 7
         and then Posix_Tools.Text.Byte_Classes.ASCII_Octal_Digit_Character (7) = '7'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Value ('F') = 15
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Value ('f') = 15,
         "ASCII digit and letter values");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (0) = '0'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (10) = 'a'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (15) = 'f'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (10, Upper => True) = 'A'
         and then Posix_Tools.Text.Byte_Classes.ASCII_Hex_Digit_Character (15, Upper => True) = 'F',
         "ASCII hex digit construction");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Checksums.POSIX_Cksum_CRC_32 ("") = 16#FFFF_FFFF#
         and then Posix_Tools.Text.Checksums.POSIX_Cksum_CRC_32 ("abc") = 1_219_131_554,
         "POSIX cksum CRC32");
      declare
         Digest : constant String :=
           "ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789";
         Text_Mode : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
           Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info (Digest & "  file.txt");
         Binary_Mode : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
           Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info (Digest & " *file.txt");
         Empty_Name : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
           Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info (Digest & "  ");
         Bad_Digest : constant Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line :=
           Posix_Tools.Text.Checksum_Lines.SHA256_Check_Line_Info
             ("Z" & Digest (Digest'First + 1 .. Digest'Last) & "  file.txt");
      begin
         AUnit.Assertions.Assert
           (Text_Mode.Valid
            and then Text_Mode.Name_First = 67
            and then Binary_Mode.Valid
            and then Binary_Mode.Name_First = 67
            and then not Empty_Name.Valid
            and then not Bad_Digest.Valid
            and then Posix_Tools.Text.Checksum_Lines.Lower_Hex (Digest)
              = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
            "SHA256 checksum line fields");
      end;
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Character'Val (9))
         and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Blank (Character'Val (10)),
         "POSIX blank excludes LF");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_POSIX_Space (Character'Val (13))
         and then not Posix_Tools.Text.Byte_Classes.Is_POSIX_Space ('A'),
         "POSIX space range");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Sort_Dictionary_Character ('A')
         and then Posix_Tools.Text.Byte_Classes.Is_Sort_Dictionary_Character (' ')
         and then not Posix_Tools.Text.Byte_Classes.Is_Sort_Dictionary_Character ('_'),
         "sort dictionary character class");
      AUnit.Assertions.Assert
        (Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (',')
         and then Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (' ')
         and then Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (Character'Val (9))
         and then not Posix_Tools.Text.Byte_Classes.Is_Cut_List_Separator (';'),
         "cut list separator class");
   end Run;
end Basic_Tests.Text_Algorithms.Stream_UTF_8_Counting;
