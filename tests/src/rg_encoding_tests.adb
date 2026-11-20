with Ada.Strings.Unbounded;
with AUnit.Assertions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Rg;
with Posix_Tools.Commands.Rg.Encodings;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.UTF_8;
with Test_Contexts;

package body Rg_Encoding_Tests is
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Exit_Status.Code;

   type Run_Outcome is record
      Output : Unbounded_String;
      Status : Posix_Tools.Exit_Status.Code := Posix_Tools.Exit_Status.Success;
   end record;

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
         Status => Result.Status);
   end Run_Rg;

   procedure Test_Encoding_Surface (T : in out Fixture) is
      pragma Unreferenced (T);
      LF          : constant Character := ASCII.LF;
      Replacement : constant String := Posix_Tools.Text.UTF_8.Encode (16#FFFD#);

      procedure Check (Label, Bytes, Expected : String) is
         Result : constant Run_Outcome :=
           Run_Rg (["--encoding", Label, "hit", "-"], Bytes & " hit" & LF);
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Result.Output) = Expected & " hit" & LF,
            "WHATWG decoder " & Label & " maps its streaming fixture");
      end Check;

      procedure Check_80 (Label : String; Expected : Natural) is
      begin
         Check
           (Label,
            String'(1 => Character'Val (16#80#)),
            Posix_Tools.Text.UTF_8.Encode (Long_Long_Integer (Expected)));
      end Check_80;

      procedure Check_Label
        (Label    : String;
         Expected : Posix_Tools.Commands.Rg.Encodings.Encoding_Mode)
      is
         use type Posix_Tools.Commands.Rg.Encodings.Encoding_Mode;
         Actual   : Posix_Tools.Commands.Rg.Encodings.Encoding_Mode;
         Resolved : Boolean;
      begin
         Resolved := Posix_Tools.Commands.Rg.Encodings.Resolve_Label (Label, Actual);
         AUnit.Assertions.Assert (Resolved, "WHATWG label " & Label & " is accepted");
         if Resolved then
            AUnit.Assertions.Assert
              (Actual = Expected,
               "WHATWG label " & Label & " resolves to the expected decoder");
         end if;
      end Check_Label;

      Chinese : constant String :=
        Posix_Tools.Text.UTF_8.Encode (16#4E2D#) & Posix_Tools.Text.UTF_8.Encode (16#6587#);
      Japanese : constant String :=
        Posix_Tools.Text.UTF_8.Encode (16#65E5#) & Posix_Tools.Text.UTF_8.Encode (16#672C#);
      Korean : constant String :=
        Posix_Tools.Text.UTF_8.Encode (16#D55C#) & Posix_Tools.Text.UTF_8.Encode (16#AD6D#);
      Smile       : constant String := Posix_Tools.Text.UTF_8.Encode (16#1F600#);
      Private_Use : constant String := Posix_Tools.Text.UTF_8.Encode (16#F780#);
   begin
      --  One non-ASCII pointer from every single-byte index catches both table
      --  errors and Encoding_Mode-to-table adapter mix-ups.
      Check_80 ("ibm866", 16#0410#);
      Check_80 ("iso-8859-2", 16#0080#);
      Check_80 ("iso-8859-3", 16#0080#);
      Check_80 ("iso-8859-4", 16#0080#);
      Check_80 ("iso-8859-5", 16#0080#);
      Check_80 ("iso-8859-6", 16#0080#);
      Check_80 ("iso-8859-7", 16#0080#);
      Check_80 ("iso-8859-8", 16#0080#);
      Check_80 ("iso-8859-10", 16#0080#);
      Check_80 ("iso-8859-13", 16#0080#);
      Check_80 ("iso-8859-14", 16#0080#);
      Check_80 ("iso-8859-15", 16#0080#);
      Check_80 ("iso-8859-16", 16#0080#);
      Check_80 ("koi8-r", 16#2500#);
      Check_80 ("koi8-u", 16#2500#);
      Check_80 ("macintosh", 16#00C4#);
      Check_80 ("windows-874", 16#20AC#);
      Check_80 ("windows-1250", 16#20AC#);
      Check_80 ("windows-1251", 16#0402#);
      Check_80 ("windows-1252", 16#20AC#);
      Check_80 ("windows-1253", 16#20AC#);
      Check_80 ("windows-1254", 16#20AC#);
      Check_80 ("windows-1255", 16#20AC#);
      Check_80 ("windows-1256", 16#20AC#);
      Check_80 ("windows-1257", 16#20AC#);
      Check_80 ("windows-1258", 16#20AC#);
      Check_80 ("x-mac-cyrillic", 16#0410#);

      --  Multibyte fixtures deliberately cross the context's three-byte read
      --  boundary, exercising retained decoder state.
      Check
        ("gbk",
         Character'Val (16#D6#) & Character'Val (16#D0#)
         & Character'Val (16#CE#) & Character'Val (16#C4#),
         Chinese);
      Check
        ("gb18030",
         Character'Val (16#94#) & Character'Val (16#39#)
         & Character'Val (16#FC#) & Character'Val (16#36#),
         Smile);
      Check
        ("big5",
         Character'Val (16#A4#) & Character'Val (16#A4#)
         & Character'Val (16#A4#) & Character'Val (16#E5#),
         Chinese);
      Check
        ("euc-jp",
         Character'Val (16#C6#) & Character'Val (16#FC#)
         & Character'Val (16#CB#) & Character'Val (16#DC#),
         Japanese);
      Check
        ("iso-2022-jp",
         Character'Val (16#1B#) & "$BF|K\" & Character'Val (16#1B#) & "(B",
         Japanese);
      Check
        ("shift_jis",
         Character'Val (16#93#) & Character'Val (16#FA#)
         & Character'Val (16#96#) & Character'Val (16#7B#),
         Japanese);
      Check
        ("euc-kr",
         Character'Val (16#C7#) & Character'Val (16#D1#)
         & Character'Val (16#B1#) & Character'Val (16#B9#),
         Korean);
      Check
        ("euc-kr",
         Character'Val (16#81#) & Character'Val (16#5B#),
         Replacement & "[");
      Check ("x-user-defined", String'(1 => Character'Val (16#80#)), Private_Use);

      declare
         Result : constant Run_Outcome :=
           Run_Rg (["--encoding", "replacement", Replacement, "-"], "discarded input");
      begin
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then To_String (Result.Output) = Replacement & LF,
            "replacement encoding emits one replacement scalar for non-empty input");
      end;

      Check_Label
        ("  ShIfT_JiS" & ASCII.HT,
         Posix_Tools.Commands.Rg.Encodings.Shift_JIS_Encoding);
      Check_Label
        ("iso-2022-kr",
         Posix_Tools.Commands.Rg.Encodings.Replacement_Encoding);
      Check_Label
        ("x-user-defined",
         Posix_Tools.Commands.Rg.Encodings.X_User_Defined_Encoding);
   end Test_Encoding_Surface;
end Rg_Encoding_Tests;
