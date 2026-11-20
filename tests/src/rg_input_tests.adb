with Ada.Directories;
with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Exit_Status;
with Test_Contexts;
with Test_Support;

package body Rg_Input_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Errors : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome;
   function Run_Rg
     (Args  : Posix_Tools.Arguments.Vector;
      Input : String) return Run_Outcome;

   function Run_Rg (Args : Posix_Tools.Arguments.Vector) return Run_Outcome is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   function UTF_16
     (Text       : Wide_Wide_String;
      Big_Endian : Boolean;
      BOM        : Boolean) return String
   is
      Result : Unbounded_String;

      procedure Append_Unit (Value : Natural);

      procedure Append_Unit (Value : Natural) is
         Low  : constant Character := Character'Val (Value mod 256);
         High : constant Character := Character'Val (Value / 256);
      begin
         Append (Result, (if Big_Endian then High & Low else Low & High));
      end Append_Unit;
   begin
      if BOM then
         if Big_Endian then
            Append (Result, Character'Val (16#FE#) & Character'Val (16#FF#));
         else
            Append (Result, Character'Val (16#FF#) & Character'Val (16#FE#));
         end if;
      end if;

      for Item of Text loop
         declare
            Value : constant Natural := Wide_Wide_Character'Pos (Item);
         begin
            if Value <= 16#FFFF# then
               Append_Unit (Value);
            else
               Append_Unit (16#D800# + (Value - 16#10000#) / 16#400#);
               Append_Unit (16#DC00# + (Value - 16#10000#) mod 16#400#);
            end if;
         end;
      end loop;
      return To_String (Result);
   end UTF_16;

   function Run_Rg
     (Args  : Posix_Tools.Arguments.Vector;
      Input : String) return Run_Outcome
   is
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("rg", Args);
      Test_Contexts.Set_Standard_Input (Context, Input);
      Test_Contexts.Set_Standard_Input_Read_Limit (Context, 3);
      Posix_Tools.Commands.Rg.Run (Context, Result);
      return
        (Output => To_Unbounded_String (Test_Contexts.Output (Context)),
         Errors => To_Unbounded_String (Test_Contexts.Error_Output (Context)),
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Binary_Controls (T : in out Fixture) is
      pragma Unreferenced (T);
      LF      : constant Character := ASCII.LF;
      NUL     : constant Character := ASCII.NUL;
      Root    : constant String := Test_Support.Work_Path ("rg-binary");
      Binary  : constant String := Root & "/binary.dat";
      Visible : constant String := Root & "/visible.txt";
      Hidden  : constant String := Root & "/.hidden.txt";
      Summary : constant String :=
        "binary file matches (found ""\0"" byte around offset 20)" & LF;
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Root);
      Test_Support.Write_File (Root & "/.gitignore", "binary.dat" & LF);
      Test_Support.Write_File
        (Binary, "needle before" & LF & "prefix" & NUL & "needle binary" & LF);
      Test_Support.Write_File (Visible, "needle visible" & LF);
      Test_Support.Write_File (Hidden, "needle hidden" & LF);
      declare
         Default_Tree : constant Run_Outcome := Run_Rg (["needle", Root]);
         Detected_Tree : constant Run_Outcome :=
           Run_Rg (["--no-ignore", "needle", Root]);
         Explicit     : constant Run_Outcome := Run_Rg (["needle", Binary]);
         Binary_Tree  : constant Run_Outcome :=
           Run_Rg (["--no-ignore", "--binary", "needle", Root]);
         Text_Tree    : constant Run_Outcome :=
           Run_Rg (["--no-ignore", "--text", "needle", Root]);
         Last_Text    : constant Run_Outcome :=
           Run_Rg (["--binary", "--text", "needle", Binary]);
         Last_Binary  : constant Run_Outcome :=
           Run_Rg (["--text", "--binary", "needle", Binary]);
         Unrestricted : constant Run_Outcome := Run_Rg (["-uuu", "needle", Root]);
         Binary_Count : constant Run_Outcome :=
           Run_Rg (["--binary", "-c", "needle", Binary]);
         Binary_Matches : constant Run_Outcome :=
           Run_Rg (["--binary", "--count-matches", "needle", Binary]);
         Binary_Stdin : constant Run_Outcome :=
           Run_Rg
             (["needle"], "needle before" & LF & "prefix" & NUL & "needle after" & LF);
         Text_Stdin : constant Run_Outcome :=
           Run_Rg
             (["--text", "needle"],
              "needle before" & LF & "prefix" & NUL & "needle after" & LF);
      begin
         AUnit.Assertions.Assert
           (To_String (Default_Tree.Output) = Visible & ":needle visible" & LF,
            "recursive default search skips binary, hidden, and ignored files");
         AUnit.Assertions.Assert
           (To_String (Detected_Tree.Output) = Visible & ":needle visible" & LF,
            "automatic binary detection suppresses matches before a later NUL byte");
         AUnit.Assertions.Assert
           (Explicit.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Explicit.Output) = Summary,
            "an explicit binary file reports a match without printing its contents");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Binary_Tree.Output), Binary & ": " & Summary)
            and then not Test_Support.Contains (To_String (Binary_Tree.Output), NUL & "needle"),
            "--binary searches recursively without emitting binary content");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Text_Tree.Output), NUL & "needle binary")
            and then not Test_Support.Contains (To_String (Text_Tree.Output), "binary file matches"),
            "--text disables NUL-byte filtering");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Last_Text.Output), NUL & "needle binary")
            and then To_String (Last_Binary.Output) = Summary,
            "the last --text or --binary flag controls binary handling");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Unrestricted.Output), Binary & ": " & Summary)
            and then Test_Support.Contains
              (To_String (Unrestricted.Output), Hidden & ":needle hidden" & LF),
            "-uuu disables ignore and hidden filtering and enables binary search");
         AUnit.Assertions.Assert
           (To_String (Binary_Count.Output) = "2" & LF
            and then To_String (Binary_Matches.Output) = "2" & LF,
            "binary count modes scan the complete input after NUL detection");
         AUnit.Assertions.Assert
           (Binary_Stdin.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Binary_Stdin.Output) = Summary,
            "binary standard input is prescanned before output is rendered");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Text_Stdin.Output), "needle before" & LF)
            and then Test_Support.Contains
              (To_String (Text_Stdin.Output), NUL & "needle after" & LF),
            "--text keeps standard input on the direct text path");
      end;
      Test_Support.Delete_If_Exists (Root);
   end Test_Binary_Controls;

   procedure Check_Encoding_Aliases
     (LE_Raw               : String;
      BE_Raw               : String;
      UTF8_Aliases         : String;
      ISO_8859_2           : String;
      ISO_8859_3           : String;
      ISO_8859_4           : String;
      Windows_1250         : String;
      Windows_1251         : String;
      Windows_1252         : String;
      E_Acute              : String;
      Euro                 : String;
      Smile                : String;
      Decoded_ISO_8859_2   : String;
      Decoded_ISO_8859_3   : String;
      Decoded_ISO_8859_4   : String;
      Decoded_Windows_1250 : String;
      Decoded_Windows_1251 : String)
   is
      LF : constant Character := ASCII.LF;

      procedure Assert_Encoding_Alias
        (Label    : String;
         Path     : String;
         Expected : String);
      procedure Assert_Invalid_Encoding_Label (Label : String);

      procedure Assert_Encoding_Alias
        (Label    : String;
         Path     : String;
         Expected : String)
      is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Result.Output) = Expected,
            "encoding alias " & Label & " follows the reference mapping");
      end Assert_Encoding_Alias;

      procedure Assert_Invalid_Encoding_Label (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", UTF8_Aliases]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
            and then Test_Support.Contains
              (To_String (Result.Errors), "unknown encoding: " & Label),
            "non-reference encoding label " & Label & " is rejected");
      end Assert_Invalid_Encoding_Label;
   begin
      Assert_Encoding_Alias ("csunicode", LE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);
      Assert_Encoding_Alias
        ("iso-10646-ucs-2", LE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);
      Assert_Encoding_Alias ("ucs-2", LE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);
      Assert_Encoding_Alias ("unicode", LE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);
      Assert_Encoding_Alias
        ("unicodefeff", LE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);
      Assert_Encoding_Alias ("utf-16", LE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);
      Assert_Encoding_Alias ("utf-16le", LE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);
      Assert_Encoding_Alias
        ("unicodefffe", BE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);
      Assert_Encoding_Alias ("utf-16be", BE_Raw, "caf" & E_Acute & " hit" & LF & "smile " & Smile & " hit" & LF);

      Assert_Encoding_Alias ("csisolatin2", ISO_8859_2, Decoded_ISO_8859_2);
      Assert_Encoding_Alias ("iso-8859-2", ISO_8859_2, Decoded_ISO_8859_2);
      Assert_Encoding_Alias ("iso-ir-101", ISO_8859_2, Decoded_ISO_8859_2);
      Assert_Encoding_Alias ("iso8859-2", ISO_8859_2, Decoded_ISO_8859_2);
      Assert_Encoding_Alias ("iso88592", ISO_8859_2, Decoded_ISO_8859_2);
      Assert_Encoding_Alias ("iso_8859-2", ISO_8859_2, Decoded_ISO_8859_2);
      Assert_Encoding_Alias ("iso_8859-2:1987", ISO_8859_2, Decoded_ISO_8859_2);
      Assert_Encoding_Alias ("l2", ISO_8859_2, Decoded_ISO_8859_2);
      Assert_Encoding_Alias ("latin2", ISO_8859_2, Decoded_ISO_8859_2);

      Assert_Encoding_Alias ("csisolatin3", ISO_8859_3, Decoded_ISO_8859_3);
      Assert_Encoding_Alias ("iso-8859-3", ISO_8859_3, Decoded_ISO_8859_3);
      Assert_Encoding_Alias ("iso-ir-109", ISO_8859_3, Decoded_ISO_8859_3);
      Assert_Encoding_Alias ("iso8859-3", ISO_8859_3, Decoded_ISO_8859_3);
      Assert_Encoding_Alias ("iso88593", ISO_8859_3, Decoded_ISO_8859_3);
      Assert_Encoding_Alias ("iso_8859-3", ISO_8859_3, Decoded_ISO_8859_3);
      Assert_Encoding_Alias ("iso_8859-3:1988", ISO_8859_3, Decoded_ISO_8859_3);
      Assert_Encoding_Alias ("l3", ISO_8859_3, Decoded_ISO_8859_3);
      Assert_Encoding_Alias ("latin3", ISO_8859_3, Decoded_ISO_8859_3);

      Assert_Encoding_Alias ("csisolatin4", ISO_8859_4, Decoded_ISO_8859_4);
      Assert_Encoding_Alias ("iso-8859-4", ISO_8859_4, Decoded_ISO_8859_4);
      Assert_Encoding_Alias ("iso-ir-110", ISO_8859_4, Decoded_ISO_8859_4);
      Assert_Encoding_Alias ("iso8859-4", ISO_8859_4, Decoded_ISO_8859_4);
      Assert_Encoding_Alias ("iso88594", ISO_8859_4, Decoded_ISO_8859_4);
      Assert_Encoding_Alias ("iso_8859-4", ISO_8859_4, Decoded_ISO_8859_4);
      Assert_Encoding_Alias ("iso_8859-4:1988", ISO_8859_4, Decoded_ISO_8859_4);
      Assert_Encoding_Alias ("l4", ISO_8859_4, Decoded_ISO_8859_4);
      Assert_Encoding_Alias ("latin4", ISO_8859_4, Decoded_ISO_8859_4);

      Assert_Encoding_Alias ("cp1250", Windows_1250, Decoded_Windows_1250);
      Assert_Encoding_Alias ("windows-1250", Windows_1250, Decoded_Windows_1250);
      Assert_Encoding_Alias ("x-cp1250", Windows_1250, Decoded_Windows_1250);
      Assert_Encoding_Alias ("cp1251", Windows_1251, Decoded_Windows_1251);
      Assert_Encoding_Alias ("windows-1251", Windows_1251, Decoded_Windows_1251);
      Assert_Encoding_Alias ("x-cp1251", Windows_1251, Decoded_Windows_1251);

      Assert_Encoding_Alias ("ansi_x3.4-1968", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("ascii", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("cp1252", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("cp819", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("csisolatin1", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("ibm819", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("iso-8859-1", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("iso-ir-100", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("iso8859-1", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("iso_8859-1:1987", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("l1", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("latin1", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("us-ascii", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("windows-1252", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);
      Assert_Encoding_Alias ("x-cp1252", Windows_1252, "caf" & E_Acute & " " & Euro & " hit" & LF);

      Assert_Encoding_Alias ("unicode-1-1-utf-8", UTF8_Aliases, "caf" & E_Acute & " hit" & LF);
      Assert_Encoding_Alias ("unicode11utf8", UTF8_Aliases, "caf" & E_Acute & " hit" & LF);
      Assert_Encoding_Alias ("unicode20utf8", UTF8_Aliases, "caf" & E_Acute & " hit" & LF);
      Assert_Encoding_Alias ("utf-8", UTF8_Aliases, "caf" & E_Acute & " hit" & LF);
      Assert_Encoding_Alias ("utf8", UTF8_Aliases, "caf" & E_Acute & " hit" & LF);
      Assert_Encoding_Alias ("x-unicode20utf8", UTF8_Aliases, "caf" & E_Acute & " hit" & LF);

      Assert_Invalid_Encoding_Label ("iso8859_1");
      Assert_Invalid_Encoding_Label ("latin-1");
      Assert_Invalid_Encoding_Label ("utf_8");
      Assert_Invalid_Encoding_Label ("windows1252");
      Assert_Invalid_Encoding_Label ("iso10646-ucs-2");
      Assert_Invalid_Encoding_Label ("ucs2");
      Assert_Invalid_Encoding_Label ("unicode-fffe");
      Assert_Invalid_Encoding_Label ("utf16");
      Assert_Invalid_Encoding_Label ("utf_16le");
      Assert_Invalid_Encoding_Label ("cp-1251");
      Assert_Invalid_Encoding_Label ("windows1251");
      Assert_Invalid_Encoding_Label ("cp-1250");
      Assert_Invalid_Encoding_Label ("windows1250");
      Assert_Invalid_Encoding_Label ("iso8859_2");
      Assert_Invalid_Encoding_Label ("latin-2");
      Assert_Invalid_Encoding_Label ("iso8859_3");
      Assert_Invalid_Encoding_Label ("latin-3");
      Assert_Invalid_Encoding_Label ("iso8859_4");
      Assert_Invalid_Encoding_Label ("latin-4");
   end Check_Encoding_Aliases;

   procedure Check_ISO_8859_5 (Root : String) is
      LF   : constant Character := ASCII.LF;
      Path : constant String := Root & "/iso-8859-5.txt";
      Bytes : constant String :=
        Character'Val (16#A1#) & Character'Val (16#F1#)
        & Character'Val (16#A2#) & Character'Val (16#F2#)
        & Character'Val (16#AC#) & Character'Val (16#FC#)
        & Character'Val (16#AE#) & Character'Val (16#FE#)
        & Character'Val (16#AF#) & Character'Val (16#FF#)
        & Character'Val (16#B0#) & Character'Val (16#CF#)
        & Character'Val (16#D0#) & Character'Val (16#EF#)
        & Character'Val (16#F0#) & Character'Val (16#FD#)
        & " " & Character'Val (16#81#) & " hit" & LF;
      Decoded : constant String :=
        Character'Val (16#D0#) & Character'Val (16#81#)
        & Character'Val (16#D1#) & Character'Val (16#91#)
        & Character'Val (16#D0#) & Character'Val (16#82#)
        & Character'Val (16#D1#) & Character'Val (16#92#)
        & Character'Val (16#D0#) & Character'Val (16#8C#)
        & Character'Val (16#D1#) & Character'Val (16#9C#)
        & Character'Val (16#D0#) & Character'Val (16#8E#)
        & Character'Val (16#D1#) & Character'Val (16#9E#)
        & Character'Val (16#D0#) & Character'Val (16#8F#)
        & Character'Val (16#D1#) & Character'Val (16#9F#)
        & Character'Val (16#D0#) & Character'Val (16#90#)
        & Character'Val (16#D0#) & Character'Val (16#AF#)
        & Character'Val (16#D0#) & Character'Val (16#B0#)
        & Character'Val (16#D1#) & Character'Val (16#8F#)
        & Character'Val (16#E2#) & Character'Val (16#84#) & Character'Val (16#96#)
        & Character'Val (16#C2#) & Character'Val (16#A7#)
        & " " & Character'Val (16#C2#) & Character'Val (16#81#) & " hit" & LF;
      Expected : constant String := "1:38:" & Decoded;

      procedure Assert_Alias (Label : String);
      procedure Assert_Invalid (Label : String);

      procedure Assert_Alias (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Result.Output) = Decoded,
            "ISO-8859-5 alias " & Label & " follows the reference mapping");
      end Assert_Alias;

      procedure Assert_Invalid (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
            and then Test_Support.Contains
              (To_String (Result.Errors), "unknown encoding: " & Label),
            "non-reference ISO-8859-5 label " & Label & " is rejected");
      end Assert_Invalid;
   begin
      Test_Support.Write_File (Path, Bytes);
      declare
         File_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "iso-8859-5", "hit", Path]);
         Stdin_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "cyrillic", "hit", "-"], Bytes);
         Json_Result : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "iso-8859-5", "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (To_String (File_Result.Output) = Expected,
            "ISO-8859-5 decoding preserves Cyrillic text, controls, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (Stdin_Result.Output) = Expected,
            "ISO-8859-5 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Json_Result.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":37,""end"":40}]")
            and then Test_Support.Contains
              (To_String (Json_Result.Output), """bytes_searched"":41"),
            "ISO-8859-5 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
      end;

      Assert_Alias ("csisolatincyrillic");
      Assert_Alias ("cyrillic");
      Assert_Alias ("iso-8859-5");
      Assert_Alias ("iso-ir-144");
      Assert_Alias ("iso8859-5");
      Assert_Alias ("iso88595");
      Assert_Alias ("iso_8859-5");
      Assert_Alias ("iso_8859-5:1988");
      Assert_Invalid ("iso8859_5");
      Assert_Invalid ("iso-8859_5");
      Assert_Invalid ("cyrillic-iso");
   end Check_ISO_8859_5;

   procedure Check_ISO_8859_6 (Root : String) is
      LF   : constant Character := ASCII.LF;
      Path : constant String := Root & "/iso-8859-6.txt";
      Bytes : constant String :=
        Character'Val (16#AC#) & Character'Val (16#BB#)
        & Character'Val (16#BF#) & Character'Val (16#C1#)
        & Character'Val (16#DA#) & Character'Val (16#E0#)
        & Character'Val (16#EA#) & Character'Val (16#EB#)
        & Character'Val (16#F2#) & Character'Val (16#A4#)
        & Character'Val (16#AD#) & Character'Val (16#A1#)
        & " " & Character'Val (16#81#) & " hit" & LF;
      Decoded : constant String :=
        Character'Val (16#D8#) & Character'Val (16#8C#)
        & Character'Val (16#D8#) & Character'Val (16#9B#)
        & Character'Val (16#D8#) & Character'Val (16#9F#)
        & Character'Val (16#D8#) & Character'Val (16#A1#)
        & Character'Val (16#D8#) & Character'Val (16#BA#)
        & Character'Val (16#D9#) & Character'Val (16#80#)
        & Character'Val (16#D9#) & Character'Val (16#8A#)
        & Character'Val (16#D9#) & Character'Val (16#8B#)
        & Character'Val (16#D9#) & Character'Val (16#92#)
        & Character'Val (16#C2#) & Character'Val (16#A4#)
        & Character'Val (16#C2#) & Character'Val (16#AD#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & " " & Character'Val (16#C2#) & Character'Val (16#81#) & " hit" & LF;
      Expected : constant String := "1:30:" & Decoded;

      procedure Assert_Alias (Label : String);
      procedure Assert_Invalid (Label : String);

      procedure Assert_Alias (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Result.Output) = Decoded,
            "ISO-8859-6 alias " & Label & " follows the reference mapping");
      end Assert_Alias;

      procedure Assert_Invalid (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
            and then Test_Support.Contains
              (To_String (Result.Errors), "unknown encoding: " & Label),
            "non-reference ISO-8859-6 label " & Label & " is rejected");
      end Assert_Invalid;
   begin
      Test_Support.Write_File (Path, Bytes);
      declare
         File_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "iso-8859-6", "hit", Path]);
         Stdin_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "arabic", "hit", "-"], Bytes);
         Json_Result : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "iso-8859-6", "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (To_String (File_Result.Output) = Expected,
            "ISO-8859-6 decoding preserves Arabic text, controls, replacements, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (Stdin_Result.Output) = Expected,
            "ISO-8859-6 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Json_Result.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":29,""end"":32}]")
            and then Test_Support.Contains
              (To_String (Json_Result.Output), """bytes_searched"":33"),
            "ISO-8859-6 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
      end;

      Assert_Alias ("arabic");
      Assert_Alias ("asmo-708");
      Assert_Alias ("csiso88596e");
      Assert_Alias ("csiso88596i");
      Assert_Alias ("csisolatinarabic");
      Assert_Alias ("ecma-114");
      Assert_Alias ("iso-8859-6");
      Assert_Alias ("iso-8859-6-e");
      Assert_Alias ("iso-8859-6-i");
      Assert_Alias ("iso-ir-127");
      Assert_Alias ("iso8859-6");
      Assert_Alias ("iso88596");
      Assert_Alias ("iso_8859-6");
      Assert_Alias ("iso_8859-6:1987");
      Assert_Invalid ("iso8859_6");
      Assert_Invalid ("iso-8859_6");
      Assert_Invalid ("arabic-iso");
   end Check_ISO_8859_6;

   procedure Check_ISO_8859_7 (Root : String) is
      LF   : constant Character := ASCII.LF;
      Path : constant String := Root & "/iso-8859-7.txt";
      Bytes : constant String :=
        Character'Val (16#A1#) & Character'Val (16#A2#)
        & Character'Val (16#A4#) & Character'Val (16#A5#)
        & Character'Val (16#AA#) & Character'Val (16#AF#)
        & Character'Val (16#B4#) & Character'Val (16#B5#)
        & Character'Val (16#B6#) & Character'Val (16#BC#)
        & Character'Val (16#BF#) & Character'Val (16#C0#)
        & Character'Val (16#C1#) & Character'Val (16#D1#)
        & Character'Val (16#D2#) & Character'Val (16#D3#)
        & Character'Val (16#DB#) & Character'Val (16#DC#)
        & Character'Val (16#FE#) & Character'Val (16#FF#)
        & " " & Character'Val (16#81#) & " hit" & LF;
      Decoded : constant String :=
        Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#98#)
        & Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#99#)
        & Character'Val (16#E2#) & Character'Val (16#82#) & Character'Val (16#AC#)
        & Character'Val (16#E2#) & Character'Val (16#82#) & Character'Val (16#AF#)
        & Character'Val (16#CD#) & Character'Val (16#BA#)
        & Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#95#)
        & Character'Val (16#CE#) & Character'Val (16#84#)
        & Character'Val (16#CE#) & Character'Val (16#85#)
        & Character'Val (16#CE#) & Character'Val (16#86#)
        & Character'Val (16#CE#) & Character'Val (16#8C#)
        & Character'Val (16#CE#) & Character'Val (16#8F#)
        & Character'Val (16#CE#) & Character'Val (16#90#)
        & Character'Val (16#CE#) & Character'Val (16#91#)
        & Character'Val (16#CE#) & Character'Val (16#A1#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & Character'Val (16#CE#) & Character'Val (16#A3#)
        & Character'Val (16#CE#) & Character'Val (16#AB#)
        & Character'Val (16#CE#) & Character'Val (16#AC#)
        & Character'Val (16#CF#) & Character'Val (16#8E#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & " " & Character'Val (16#C2#) & Character'Val (16#81#) & " hit" & LF;
      Expected : constant String := "1:52:" & Decoded;

      procedure Assert_Alias (Label : String);
      procedure Assert_Invalid (Label : String);

      procedure Assert_Alias (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Result.Output) = Decoded,
            "ISO-8859-7 alias " & Label & " follows the reference mapping");
      end Assert_Alias;

      procedure Assert_Invalid (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
            and then Test_Support.Contains
              (To_String (Result.Errors), "unknown encoding: " & Label),
            "non-reference ISO-8859-7 label " & Label & " is rejected");
      end Assert_Invalid;
   begin
      Test_Support.Write_File (Path, Bytes);
      declare
         File_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "iso-8859-7", "hit", Path]);
         Stdin_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "greek", "hit", "-"], Bytes);
         Json_Result : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "iso-8859-7", "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (To_String (File_Result.Output) = Expected,
            "ISO-8859-7 decoding preserves Greek text, controls, replacements, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (Stdin_Result.Output) = Expected,
            "ISO-8859-7 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Json_Result.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":51,""end"":54}]")
            and then Test_Support.Contains
              (To_String (Json_Result.Output), """bytes_searched"":55"),
            "ISO-8859-7 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
      end;

      Assert_Alias ("csisolatingreek");
      Assert_Alias ("ecma-118");
      Assert_Alias ("elot_928");
      Assert_Alias ("greek");
      Assert_Alias ("greek8");
      Assert_Alias ("iso-8859-7");
      Assert_Alias ("iso-ir-126");
      Assert_Alias ("iso8859-7");
      Assert_Alias ("iso88597");
      Assert_Alias ("iso_8859-7");
      Assert_Alias ("iso_8859-7:1987");
      Assert_Alias ("sun_eu_greek");
      Assert_Invalid ("iso8859_7");
      Assert_Invalid ("iso-8859_7");
      Assert_Invalid ("greek-iso");
   end Check_ISO_8859_7;

   procedure Check_ISO_8859_8 (Root : String) is
      LF   : constant Character := ASCII.LF;
      Path : constant String := Root & "/iso-8859-8.txt";
      Bytes : constant String :=
        Character'Val (16#A1#) & Character'Val (16#AA#)
        & Character'Val (16#BA#) & Character'Val (16#BF#)
        & Character'Val (16#C0#) & Character'Val (16#DE#)
        & Character'Val (16#DF#) & Character'Val (16#E0#)
        & Character'Val (16#E9#) & Character'Val (16#FA#)
        & Character'Val (16#FB#) & Character'Val (16#FC#)
        & Character'Val (16#FD#) & Character'Val (16#FE#)
        & Character'Val (16#FF#) & " " & Character'Val (16#81#) & " hit" & LF;
      Decoded : constant String :=
        Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & Character'Val (16#C3#) & Character'Val (16#97#)
        & Character'Val (16#C3#) & Character'Val (16#B7#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#97#)
        & Character'Val (16#D7#) & Character'Val (16#90#)
        & Character'Val (16#D7#) & Character'Val (16#99#)
        & Character'Val (16#D7#) & Character'Val (16#AA#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#8E#)
        & Character'Val (16#E2#) & Character'Val (16#80#) & Character'Val (16#8F#)
        & Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#)
        & " " & Character'Val (16#C2#) & Character'Val (16#81#) & " hit" & LF;
      Expected : constant String := "1:45:" & Decoded;

      procedure Assert_Alias (Label : String);
      procedure Assert_Invalid (Label : String);

      procedure Assert_Alias (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Result.Output) = Decoded,
            "ISO-8859-8 alias " & Label & " follows the reference mapping");
      end Assert_Alias;

      procedure Assert_Invalid (Label : String) is
         Result : constant Run_Outcome := Run_Rg (["--encoding", Label, "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
            and then Test_Support.Contains
              (To_String (Result.Errors), "unknown encoding: " & Label),
            "non-reference ISO-8859-8 label " & Label & " is rejected");
      end Assert_Invalid;
   begin
      Test_Support.Write_File (Path, Bytes);
      declare
         File_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "iso-8859-8", "hit", Path]);
         Stdin_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "hebrew", "hit", "-"], Bytes);
         Json_Result : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "iso-8859-8", "hit", Path]);
      begin
         AUnit.Assertions.Assert
           (To_String (File_Result.Output) = Expected,
            "ISO-8859-8 decoding preserves Hebrew text, controls, replacements, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (Stdin_Result.Output) = Expected,
            "ISO-8859-8 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Json_Result.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":44,""end"":47}]")
            and then Test_Support.Contains
              (To_String (Json_Result.Output), """bytes_searched"":48"),
            "ISO-8859-8 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
      end;

      Assert_Alias ("csiso88598i");
      Assert_Alias ("csisolatinhebrew");
      Assert_Alias ("hebrew");
      Assert_Alias ("iso-8859-8");
      Assert_Alias ("iso-8859-8-e");
      Assert_Alias ("iso-8859-8-i");
      Assert_Alias ("iso-ir-138");
      Assert_Alias ("iso8859-8");
      Assert_Alias ("iso88598");
      Assert_Alias ("iso_8859-8");
      Assert_Alias ("iso_8859-8:1988");
      Assert_Alias ("logical");
      Assert_Alias ("visual");
      Assert_Invalid ("iso8859_8");
      Assert_Invalid ("iso-8859_8");
      Assert_Invalid ("hebrew-iso");
      Assert_Invalid ("l8");
      Assert_Invalid ("latin8");
   end Check_ISO_8859_8;

   procedure Test_Encoding (T : in out Fixture) is
      pragma Unreferenced (T);
      LF : constant Character := ASCII.LF;
      Root : constant String := Test_Support.Work_Path ("rg-encoding");
      LE_BOM : constant String := Root & "/utf16le-bom.txt";
      BE_BOM : constant String := Root & "/utf16be-bom.txt";
      LE_Raw : constant String := Root & "/utf16le.txt";
      BE_Raw : constant String := Root & "/utf16be.txt";
      UTF8_BOM : constant String := Root & "/utf8-bom.txt";
      UTF8_Aliases : constant String := Root & "/utf8-aliases.txt";
      ISO_8859_2 : constant String := Root & "/iso-8859-2.txt";
      ISO_8859_3 : constant String := Root & "/iso-8859-3.txt";
      ISO_8859_4 : constant String := Root & "/iso-8859-4.txt";
      Windows_1250 : constant String := Root & "/windows-1250.txt";
      Windows_1251 : constant String := Root & "/windows-1251.txt";
      Windows_1252 : constant String := Root & "/windows-1252.txt";
      Windows_1252_Control : constant String := Root & "/windows-1252-control.txt";
      Invalid_UTF8 : constant String := Root & "/invalid-utf8.txt";
      Invalid_UTF16 : constant String := Root & "/invalid-utf16.txt";
      Source : constant Wide_Wide_String :=
        "alpha" & Wide_Wide_Character'Val (10)
        & "caf" & Wide_Wide_Character'Val (16#E9#) & " hit"
        & Wide_Wide_Character'Val (10)
        & "smile " & Wide_Wide_Character'Val (16#1F600#) & " hit"
        & Wide_Wide_Character'Val (10);
      E_Acute : constant String := Character'Val (16#C3#) & Character'Val (16#A9#);
      Euro : constant String :=
        Character'Val (16#E2#) & Character'Val (16#82#) & Character'Val (16#AC#);
      Currency : constant String := Character'Val (16#C2#) & Character'Val (16#A4#);
      C1_Control : constant String := Character'Val (16#C2#) & Character'Val (16#81#);
      C1_98 : constant String := Character'Val (16#C2#) & Character'Val (16#98#);
      Replacement : constant String :=
        Character'Val (16#EF#) & Character'Val (16#BF#) & Character'Val (16#BD#);
      ISO_8859_4_Bytes : constant String :=
        Character'Val (16#A1#) & Character'Val (16#B1#)
        & Character'Val (16#A2#) & Character'Val (16#A3#)
        & Character'Val (16#B3#) & Character'Val (16#BD#)
        & Character'Val (16#BF#) & Character'Val (16#C0#)
        & Character'Val (16#E0#) & " " & Character'Val (16#A4#)
        & " " & Character'Val (16#81#) & " hit" & LF;
      Central_European : constant String :=
        "Za" & Character'Val (16#C5#) & Character'Val (16#BC#)
        & Character'Val (16#C3#) & Character'Val (16#B3#)
        & Character'Val (16#C5#) & Character'Val (16#82#)
        & Character'Val (16#C4#) & Character'Val (16#87#);
      Maltese : constant String :=
        Character'Val (16#C4#) & Character'Val (16#A6#)
        & Character'Val (16#C4#) & Character'Val (16#A7#)
        & Character'Val (16#C4#) & Character'Val (16#8A#)
        & Character'Val (16#C4#) & Character'Val (16#8B#)
        & Character'Val (16#C4#) & Character'Val (16#A0#)
        & Character'Val (16#C4#) & Character'Val (16#A1#)
        & Character'Val (16#C5#) & Character'Val (16#BB#)
        & Character'Val (16#C5#) & Character'Val (16#BC#);
      Baltic : constant String :=
        Character'Val (16#C4#) & Character'Val (16#84#)
        & Character'Val (16#C4#) & Character'Val (16#85#)
        & Character'Val (16#C4#) & Character'Val (16#B8#)
        & Character'Val (16#C5#) & Character'Val (16#96#)
        & Character'Val (16#C5#) & Character'Val (16#97#)
        & Character'Val (16#C5#) & Character'Val (16#8A#)
        & Character'Val (16#C5#) & Character'Val (16#8B#)
        & Character'Val (16#C4#) & Character'Val (16#80#)
        & Character'Val (16#C4#) & Character'Val (16#81#);
      Cyrillic : constant String :=
        Character'Val (16#D0#) & Character'Val (16#9F#)
        & Character'Val (16#D1#) & Character'Val (16#80#)
        & Character'Val (16#D0#) & Character'Val (16#B8#)
        & Character'Val (16#D0#) & Character'Val (16#B2#)
        & Character'Val (16#D0#) & Character'Val (16#B5#)
        & Character'Val (16#D1#) & Character'Val (16#82#);
      Smile : constant String :=
        Character'Val (16#F0#) & Character'Val (16#9F#)
        & Character'Val (16#98#) & Character'Val (16#80#);
      Expected : constant String :=
        "2:7:caf" & E_Acute & " hit" & LF
        & "3:12:smile " & Smile & " hit" & LF;
      Expected_Windows_1252 : constant String :=
        "1:11:caf" & E_Acute & " " & Euro & " hit" & LF;
      Decoded_ISO_8859_2 : constant String :=
        Central_European & " " & Currency & " " & C1_Control & " hit" & LF;
      Expected_ISO_8859_2 : constant String :=
        "1:18:" & Decoded_ISO_8859_2;
      Decoded_ISO_8859_3 : constant String :=
        Maltese & " " & Currency & " " & C1_Control & " " & Replacement & " hit" & LF;
      Expected_ISO_8859_3 : constant String :=
        "1:28:" & Decoded_ISO_8859_3;
      Decoded_ISO_8859_4 : constant String :=
        Baltic & " " & Currency & " " & C1_Control & " hit" & LF;
      Expected_ISO_8859_4 : constant String :=
        "1:26:" & Decoded_ISO_8859_4;
      Decoded_Windows_1250 : constant String :=
        Central_European & " " & Euro & " " & C1_Control & " hit" & LF;
      Expected_Windows_1250 : constant String :=
        "1:19:" & Decoded_Windows_1250;
      Decoded_Windows_1251 : constant String :=
        Cyrillic & " " & Euro & " " & C1_98 & " hit" & LF;
      Expected_Windows_1251 : constant String :=
        "1:21:" & Decoded_Windows_1251;
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Root);
      Test_Support.Write_File (LE_BOM, UTF_16 (Source, Big_Endian => False, BOM => True));
      Test_Support.Write_File (BE_BOM, UTF_16 (Source, Big_Endian => True, BOM => True));
      Test_Support.Write_File (LE_Raw, UTF_16 (Source, Big_Endian => False, BOM => False));
      Test_Support.Write_File (BE_Raw, UTF_16 (Source, Big_Endian => True, BOM => False));
      Test_Support.Write_File
        (UTF8_BOM,
         Character'Val (16#EF#) & Character'Val (16#BB#) & Character'Val (16#BF#)
         & "alpha" & LF);
      Test_Support.Write_File (UTF8_Aliases, "caf" & E_Acute & " hit" & LF);
      Test_Support.Write_File
        (ISO_8859_2,
         "Za" & Character'Val (16#BF#) & Character'Val (16#F3#)
         & Character'Val (16#B3#) & Character'Val (16#E6#)
         & " " & Character'Val (16#A4#) & " " & Character'Val (16#81#)
         & " hit" & LF);
      Test_Support.Write_File
        (ISO_8859_3,
         Character'Val (16#A1#) & Character'Val (16#B1#)
         & Character'Val (16#C5#) & Character'Val (16#E5#)
         & Character'Val (16#D5#) & Character'Val (16#F5#)
         & Character'Val (16#AF#) & Character'Val (16#BF#)
         & " " & Character'Val (16#A4#) & " " & Character'Val (16#81#)
         & " " & Character'Val (16#A5#) & " hit" & LF);
      Test_Support.Write_File (ISO_8859_4, ISO_8859_4_Bytes);
      Test_Support.Write_File
        (Windows_1250,
         "Za" & Character'Val (16#BF#) & Character'Val (16#F3#)
         & Character'Val (16#B3#) & Character'Val (16#E6#)
         & " " & Character'Val (16#80#) & " " & Character'Val (16#81#)
         & " hit" & LF);
      Test_Support.Write_File
        (Windows_1251,
         Character'Val (16#CF#) & Character'Val (16#F0#)
         & Character'Val (16#E8#) & Character'Val (16#E2#)
         & Character'Val (16#E5#) & Character'Val (16#F2#)
         & " " & Character'Val (16#88#) & " " & Character'Val (16#98#)
         & " hit" & LF);
      Test_Support.Write_File
        (Windows_1252,
         "caf" & Character'Val (16#E9#) & " " & Character'Val (16#80#) & " hit" & LF);
      Test_Support.Write_File
        (Windows_1252_Control, Character'Val (16#81#) & " hit" & LF);
      Test_Support.Write_File (Invalid_UTF8, "a" & Character'Val (16#FF#) & " hit" & LF);
      Test_Support.Write_File
        (Invalid_UTF16,
         UTF_16
           (Wide_Wide_String'(1 => Wide_Wide_Character'Val (16#D800#)) & " hit"
            & Wide_Wide_Character'Val (10),
            Big_Endian => False,
            BOM => False));

      declare
         Auto_LE : constant Run_Outcome := Run_Rg (["-n", "--column", "hit", LE_BOM]);
         Auto_BE : constant Run_Outcome := Run_Rg (["-n", "--column", "hit", BE_BOM]);
         Explicit_LE : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "utf-16le", "hit", LE_Raw]);
         Explicit_BE : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding=utf-16be", "hit", BE_Raw]);
         Generic_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "-Eutf-16", "hit", LE_Raw]);
         Joined_Upper : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "-EUTF-16LE", "hit", LE_Raw]);
         Json_Result : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "utf-16le", "hit", LE_Raw]);
         ISO_8859_2_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "iso-8859-2", "hit", ISO_8859_2]);
         ISO_8859_3_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "iso-8859-3", "hit", ISO_8859_3]);
         ISO_8859_4_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "iso-8859-4", "hit", ISO_8859_4]);
         Windows_1250_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "windows-1250", "hit", Windows_1250]);
         Windows_1251_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "windows-1251", "hit", Windows_1251]);
         Windows_Result : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "--encoding", "windows-1252", "hit", Windows_1252]);
         LE_With_BE_BOM : constant Run_Outcome :=
           Run_Rg (["--encoding", "utf-16le", "hit", BE_BOM]);
         BE_With_LE_BOM : constant Run_Outcome :=
           Run_Rg (["--encoding", "utf-16be", "hit", LE_BOM]);
         LE_Alias_With_BE_BOM : constant Run_Outcome :=
           Run_Rg (["--encoding", "unicode", "hit", BE_BOM]);
         BE_Alias_With_LE_BOM : constant Run_Outcome :=
           Run_Rg (["--encoding", "unicodefffe", "hit", LE_BOM]);
      begin
         AUnit.Assertions.Assert
           (To_String (Auto_LE.Output) = Expected
            and then To_String (Auto_BE.Output) = Expected,
            "automatic encoding detects little- and big-endian UTF-16 BOMs");
         AUnit.Assertions.Assert
           (To_String (Explicit_LE.Output) = Expected
            and then To_String (Explicit_BE.Output) = Expected
            and then To_String (Generic_Result.Output) = Expected
            and then To_String (Joined_Upper.Output) = Expected,
            "explicit UTF-16 labels and joined -E forms decode to UTF-8");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Json_Result.Output),
               """line_number"":2,""absolute_offset"":6,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":6,""end"":9}]")
            and then Test_Support.Contains
              (To_String (Json_Result.Output), """bytes_searched"":31"),
            "JSON offsets and searched-byte totals use decoded UTF-8 bytes");
         AUnit.Assertions.Assert
           (To_String (Windows_Result.Output) = Expected_Windows_1252,
            "Windows-1252 decoding preserves UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (ISO_8859_2_Result.Output) = Expected_ISO_8859_2,
            "ISO-8859-2 decoding preserves Central European text, controls, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (ISO_8859_3_Result.Output) = Expected_ISO_8859_3,
            "ISO-8859-3 decoding preserves Latin-3 text, controls, replacements, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (ISO_8859_4_Result.Output) = Expected_ISO_8859_4,
            "ISO-8859-4 decoding preserves Baltic text, controls, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (Windows_1251_Result.Output) = Expected_Windows_1251,
            "Windows-1251 decoding preserves Cyrillic text, controls, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (Windows_1250_Result.Output) = Expected_Windows_1250,
            "Windows-1250 decoding preserves Central European text, controls, and UTF-8 byte columns");
         AUnit.Assertions.Assert
           (To_String (LE_With_BE_BOM.Output) = "caf" & E_Acute & " hit" & LF
            & "smile " & Smile & " hit" & LF
            and then To_String (BE_With_LE_BOM.Output) = "caf" & E_Acute & " hit" & LF
              & "smile " & Smile & " hit" & LF
            and then To_String (LE_Alias_With_BE_BOM.Output) = "caf" & E_Acute & " hit" & LF
              & "smile " & Smile & " hit" & LF
            and then To_String (BE_Alias_With_LE_BOM.Output) = "caf" & E_Acute & " hit" & LF
              & "smile " & Smile & " hit" & LF,
            "explicit UTF-16 labels let either BOM override their default byte order");
      end;

      Check_Encoding_Aliases
        (LE_Raw               => LE_Raw,
         BE_Raw               => BE_Raw,
         UTF8_Aliases         => UTF8_Aliases,
         ISO_8859_2           => ISO_8859_2,
         ISO_8859_3           => ISO_8859_3,
         ISO_8859_4           => ISO_8859_4,
         Windows_1250         => Windows_1250,
         Windows_1251         => Windows_1251,
         Windows_1252         => Windows_1252,
         E_Acute              => E_Acute,
         Euro                 => Euro,
         Smile                => Smile,
         Decoded_ISO_8859_2   => Decoded_ISO_8859_2,
         Decoded_ISO_8859_3   => Decoded_ISO_8859_3,
         Decoded_ISO_8859_4   => Decoded_ISO_8859_4,
         Decoded_Windows_1250 => Decoded_Windows_1250,
         Decoded_Windows_1251 => Decoded_Windows_1251);

      declare
         Stdin_LE : constant Run_Outcome :=
           Run_Rg (["-n", "--column", "hit", "-"], UTF_16 (Source, False, True));
         No_Decode : constant Run_Outcome := Run_Rg (["--encoding", "none", "hit", LE_BOM]);
         Reset_Auto : constant Run_Outcome :=
           Run_Rg (["--encoding", "none", "--no-encoding", "hit", LE_BOM]);
         UTF8_Auto : constant Run_Outcome := Run_Rg (["^alpha", UTF8_BOM]);
         Replaced : constant Run_Outcome :=
           Run_Rg (["--encoding", "utf-8", "hit", Invalid_UTF8]);
         Replaced_UTF16 : constant Run_Outcome :=
           Run_Rg (["--encoding", "utf-16le", "hit", Invalid_UTF16]);
         Windows_Stdin : constant Run_Outcome :=
           Run_Rg
             (["-n", "--column", "--encoding", "cp1252", "hit", "-"],
              "caf" & Character'Val (16#E9#) & " " & Character'Val (16#80#) & " hit" & LF);
         ISO_8859_2_Stdin : constant Run_Outcome :=
           Run_Rg
             (["-n", "--column", "--encoding", "latin2", "hit", "-"],
              "Za" & Character'Val (16#BF#) & Character'Val (16#F3#)
              & Character'Val (16#B3#) & Character'Val (16#E6#)
              & " " & Character'Val (16#A4#) & " " & Character'Val (16#81#)
              & " hit" & LF);
         ISO_8859_2_Json : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "iso-8859-2", "hit", ISO_8859_2]);
         ISO_8859_3_Stdin : constant Run_Outcome :=
           Run_Rg
             (["-n", "--column", "--encoding", "latin3", "hit", "-"],
              Character'Val (16#A1#) & Character'Val (16#B1#)
              & Character'Val (16#C5#) & Character'Val (16#E5#)
              & Character'Val (16#D5#) & Character'Val (16#F5#)
              & Character'Val (16#AF#) & Character'Val (16#BF#)
              & " " & Character'Val (16#A4#) & " " & Character'Val (16#81#)
              & " " & Character'Val (16#A5#) & " hit" & LF);
         ISO_8859_3_Json : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "iso-8859-3", "hit", ISO_8859_3]);
         ISO_8859_4_Stdin : constant Run_Outcome :=
           Run_Rg
             (["-n", "--column", "--encoding", "latin4", "hit", "-"],
              ISO_8859_4_Bytes);
         ISO_8859_4_Json : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "iso-8859-4", "hit", ISO_8859_4]);
         Windows_1250_Stdin : constant Run_Outcome :=
           Run_Rg
             (["-n", "--column", "--encoding", "cp1250", "hit", "-"],
              "Za" & Character'Val (16#BF#) & Character'Val (16#F3#)
              & Character'Val (16#B3#) & Character'Val (16#E6#)
              & " " & Character'Val (16#80#) & " " & Character'Val (16#81#)
              & " hit" & LF);
         Windows_1250_Json : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "windows-1250", "hit", Windows_1250]);
         Windows_1251_Stdin : constant Run_Outcome :=
           Run_Rg
             (["-n", "--column", "--encoding", "cp1251", "hit", "-"],
              Character'Val (16#CF#) & Character'Val (16#F0#)
              & Character'Val (16#E8#) & Character'Val (16#E2#)
              & Character'Val (16#E5#) & Character'Val (16#F2#)
              & " " & Character'Val (16#88#) & " " & Character'Val (16#98#)
              & " hit" & LF);
         Windows_1251_Json : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "windows-1251", "hit", Windows_1251]);
         Windows_Json : constant Run_Outcome :=
           Run_Rg (["--json", "--encoding", "windows-1252", "hit", Windows_1252]);
         Windows_Control : constant Run_Outcome :=
           Run_Rg (["--encoding", "windows-1252", C1_Control, Windows_1252_Control]);
      begin
         AUnit.Assertions.Assert
           (To_String (Stdin_LE.Output) = Expected,
            "UTF-16 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (No_Decode.Status = Posix_Tools.Exit_Status.Operational_Failure
            and then Reset_Auto.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Reset_Auto.Output) = "caf" & E_Acute & " hit" & LF
              & "smile " & Smile & " hit" & LF,
            "none disables BOM decoding and --no-encoding restores automatic detection");
         AUnit.Assertions.Assert
           (To_String (UTF8_Auto.Output) = "alpha" & LF,
            "automatic encoding strips a UTF-8 BOM before matching");
         AUnit.Assertions.Assert
           (To_String (Replaced.Output) =
              "a" & Character'Val (16#EF#) & Character'Val (16#BF#)
              & Character'Val (16#BD#) & " hit" & LF,
            "explicit UTF-8 replaces malformed input without losing following text");
         AUnit.Assertions.Assert
           (To_String (Replaced_UTF16.Output) =
              Character'Val (16#EF#) & Character'Val (16#BF#)
              & Character'Val (16#BD#) & " hit" & LF,
            "explicit UTF-16 replaces an unpaired surrogate");
         AUnit.Assertions.Assert
           (To_String (Windows_Stdin.Output) = Expected_Windows_1252,
            "Windows-1252 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (To_String (ISO_8859_2_Stdin.Output) = Expected_ISO_8859_2,
            "ISO-8859-2 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (ISO_8859_2_Json.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":17,""end"":20}]")
            and then Test_Support.Contains
              (To_String (ISO_8859_2_Json.Output), """bytes_searched"":21"),
            "ISO-8859-2 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
         AUnit.Assertions.Assert
           (To_String (ISO_8859_3_Stdin.Output) = Expected_ISO_8859_3,
            "ISO-8859-3 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (ISO_8859_3_Json.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":27,""end"":30}]")
            and then Test_Support.Contains
              (To_String (ISO_8859_3_Json.Output), """bytes_searched"":31"),
            "ISO-8859-3 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
         AUnit.Assertions.Assert
           (To_String (ISO_8859_4_Stdin.Output) = Expected_ISO_8859_4,
            "ISO-8859-4 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (ISO_8859_4_Json.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":25,""end"":28}]")
            and then Test_Support.Contains
              (To_String (ISO_8859_4_Json.Output), """bytes_searched"":29"),
            "ISO-8859-4 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
         AUnit.Assertions.Assert
           (To_String (Windows_1251_Stdin.Output) = Expected_Windows_1251,
            "Windows-1251 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (To_String (Windows_1250_Stdin.Output) = Expected_Windows_1250,
            "Windows-1250 standard input decodes across bounded three-byte reads");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Windows_1250_Json.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":18,""end"":21}]")
            and then Test_Support.Contains
              (To_String (Windows_1250_Json.Output), """bytes_searched"":22"),
            "Windows-1250 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Windows_1251_Json.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":20,""end"":23}]")
            and then Test_Support.Contains
              (To_String (Windows_1251_Json.Output), """bytes_searched"":24"),
            "Windows-1251 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
         AUnit.Assertions.Assert
           (Test_Support.Contains
              (To_String (Windows_Json.Output),
               """line_number"":1,""absolute_offset"":0,""submatches"":["
               & "{""match"":{""text"":""hit""},""start"":10,""end"":13}]")
            and then Test_Support.Contains
              (To_String (Windows_Json.Output), """bytes_searched"":14"),
            "Windows-1252 JSON offsets and searched-byte totals use decoded UTF-8 bytes");
         AUnit.Assertions.Assert
           (To_String (Windows_Control.Output) = C1_Control & " hit" & LF,
            "Windows-1252 preserves unmapped C1 bytes as Unicode controls like the reference");
      end;

      Check_ISO_8859_5 (Root);
      Check_ISO_8859_6 (Root);
      Check_ISO_8859_7 (Root);
      Check_ISO_8859_8 (Root);
      Test_Support.Delete_If_Exists (Root);
   end Test_Encoding;

   procedure Test_Max_File_Size (T : in out Fixture) is
      pragma Unreferenced (T);
      LF       : constant Character := ASCII.LF;
      Root     : constant String := Test_Support.Work_Path ("rg-max-filesize");
      Small    : constant String := Root & "/small.txt";
      Large    : constant String := Root & "/large.txt";
      Large_Text : constant String := "needle" & String'(1 .. 58 => 'x') & LF;
   begin
      Test_Support.Delete_If_Exists (Root);
      Ada.Directories.Create_Path (Root);
      Test_Support.Write_File (Small, "needle" & LF);
      Test_Support.Write_File (Large, Large_Text);
      declare
         Capped : constant Run_Outcome :=
           Run_Rg (["--max-filesize", "10", "needle", Root]);
         Listed  : constant Run_Outcome :=
           Run_Rg (["--files", "--max-filesize=10", Root]);
         Explicit : constant Run_Outcome :=
           Run_Rg (["--max-filesize", "10", "needle", Large]);
         Suffix  : constant Run_Outcome :=
           Run_Rg (["--max-filesize", "1K", "needle", Root]);
         Invalid : constant Run_Outcome :=
           Run_Rg (["--max-filesize", "1k", "needle", Root]);
         Empty   : constant Run_Outcome :=
           Run_Rg (["--max-filesize=", "needle", Root]);
      begin
         AUnit.Assertions.Assert
           (To_String (Capped.Output) = Small & ":needle" & LF,
            "--max-filesize skips oversized discovered search inputs");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Listed.Output), Small & LF)
            and then not Test_Support.Contains (To_String (Listed.Output), Large),
            "--files applies the same discovered-file size limit");
         AUnit.Assertions.Assert
           (Explicit.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Explicit.Output) = Large_Text,
            "--max-filesize does not filter an explicit file operand");
         AUnit.Assertions.Assert
           (Test_Support.Contains (To_String (Suffix.Output), Large & ":" & Large_Text),
            "uppercase K size suffixes use 1024-byte units");
         AUnit.Assertions.Assert
           (Invalid.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (To_String (Invalid.Errors), "invalid value for --max-filesize: 1k"),
            "invalid size suffixes produce status 2 and a diagnostic");
         AUnit.Assertions.Assert
           (Empty.Status = Posix_Tools.Commands.Rg.Trouble
            and then Test_Support.Contains
              (To_String (Empty.Errors), "invalid value for --max-filesize:"),
            "an empty equals-form size produces status 2 and a size diagnostic");
      end;
      Test_Support.Delete_If_Exists (Root);
   end Test_Max_File_Size;
end Rg_Input_Tests;
