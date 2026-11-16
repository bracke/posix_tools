with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Line_Readers;
with Posix_Tools.Commands.Text_Helpers.Collation;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Comm is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Suppress_1 : Boolean := False;
      Suppress_2 : Boolean := False;
      Suppress_3 : Boolean := False;
      First      : Positive;
      Valid      : Boolean;
      Locale     : constant String :=
        Context.Category_Locale (Posix_Tools.Commands.Contexts.Collation);
      Byte_Collation : constant Boolean :=
        Posix_Tools.Commands.Text_Helpers.Collation.Is_Byte_Collation_Locale
          (Locale);
      Left       : Posix_Tools.Commands.Line_Readers.Reader
        (Posix_Tools.Commands.Line_Readers.Bulk_Buffer_Length);
      Right      : Posix_Tools.Commands.Line_Readers.Reader
        (Posix_Tools.Commands.Line_Readers.Bulk_Buffer_Length);
      Left_Line  : Unbounded_String;
      Right_Line : Unbounded_String;
      Left_Key   : Unbounded_String;
      Right_Key  : Unbounded_String;
      Have_Left  : Boolean := False;
      Have_Right : Boolean := False;
      Ok         : Boolean := True;
      Pending    : Unbounded_String;
      Output_Limit : constant := 64 * 1024;

      procedure Emit (Column : Positive; Text : Unbounded_String);
      procedure Flush_Output;
      procedure Read_Next
        (Input     : in out Posix_Tools.Commands.Line_Readers.Reader;
         Line      : out Unbounded_String;
         Key       : out Unbounded_String;
         Available : out Boolean;
         Success   : out Boolean);

      procedure Flush_Output is
      begin
         if Length (Pending) > 0 then
            if not Context.Output_Failed then
               Context.Put (To_String (Pending));
            end if;
            Pending := Null_Unbounded_String;
         end if;
      end Flush_Output;

      --  How Left collates against Right; lines the locale ranks equal
      --  but that differ are ordered by their bytes.
      function Compare
        (Left, Right, Left_Key, Right_Key : Unbounded_String) return Integer is
      begin
         if Byte_Collation then
            return
              (if Left < Right then -1
               elsif Left > Right then 1
               else 0);
         end if;
         declare
            Left_Text  : constant String := To_String (Left);
            Right_Text : constant String := To_String (Right);
         begin
            return
              (if Left_Key < Right_Key then -1
               elsif Left_Key > Right_Key then 1
               elsif Left_Text < Right_Text then -1
               elsif Left_Text > Right_Text then 1
               else 0);
         end;
      end Compare;

      procedure Read_Next
        (Input     : in out Posix_Tools.Commands.Line_Readers.Reader;
         Line      : out Unbounded_String;
         Key       : out Unbounded_String;
         Available : out Boolean;
         Success   : out Boolean)
      is
      begin
         Posix_Tools.Commands.Line_Readers.Next
           (Input, Context, Line, Available, Success);
         if Success and then Available and then not Byte_Collation then
            Key := To_Unbounded_String
              (Posix_Tools.Commands.Text_Helpers.Collation.Locale_Sort_Text
                 (Locale, To_String (Line)));
         else
            Key := Null_Unbounded_String;
         end if;
      end Read_Next;

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         pragma Unreferenced (Value, Result);
      begin
         case Name is
            when '1' => Suppress_1 := True;
            when '2' => Suppress_2 := True;
            when others => Suppress_3 := True;
         end case;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);

      procedure Emit (Column : Positive; Text : Unbounded_String) is
         Tabs : constant Natural :=
           (if Column = 1 then 0
            elsif Column = 2 then (if Suppress_1 then 0 else 1)
            else (if Suppress_1 then 0 else 1) + (if Suppress_2 then 0 else 1));
         Needed : constant Natural := Tabs + Length (Text) + 1;
      begin
         if Needed >= Output_Limit then
            Flush_Output;
            if Tabs > 0 and then not Context.Output_Failed then
               Context.Put (String'(1 .. Tabs => Character'Val (9)));
            end if;
            declare
               First : Positive := 1;
            begin
               while First <= Length (Text) and then not Context.Output_Failed loop
                  declare
                     Last : constant Natural :=
                       Natural'Min (Length (Text), First + Output_Limit - 1);
                  begin
                     Context.Put (Slice (Text, First, Last));
                     First := Last + 1;
                  end;
               end loop;
            end;
            if not Context.Output_Failed then
               Append (Pending, Character'Val (10));
            end if;
         else
            if Length (Pending) > Output_Limit - Needed then
               Flush_Output;
            end if;
            if not Context.Output_Failed then
               if Tabs > 0 then
                  Append (Pending, String'(1 .. Tabs => Character'Val (9)));
               end if;
               Append (Pending, Text);
               Append (Pending, Character'Val (10));
            end if;
         end if;
      end Emit;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "123", "", First, Valid);
      if not Valid then
         return;
      elsif Context.Argument_Count > First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (First + 2));
         return;
      elsif Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      --  Two logical inputs cannot both own the one standard-input cursor.
      --  Giving each a private buffer makes the result depend on which reader
      --  happened to fill first and how much it read.
      if Context.Argument (First) = "-"
        and then Context.Argument (First + 1) = "-"
      then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, "-",
            "posix_tools.diagnostic.file.read_failed", "cannot read file");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      Posix_Tools.Commands.Line_Readers.Open (Left, Context.Argument (First), Ok);
      if not Ok then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (First),
            "posix_tools.diagnostic.file.read_failed", "cannot read file");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;
      Posix_Tools.Commands.Line_Readers.Open (Right, Context.Argument (First + 1), Ok);
      if not Ok then
         declare
            Closed : Boolean;
         begin
            Posix_Tools.Commands.Line_Readers.Close (Left, Closed);
         end;
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (First + 1),
            "posix_tools.diagnostic.file.read_failed", "cannot read file");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      Read_Next (Left, Left_Line, Left_Key, Have_Left, Ok);
      if Ok then
         Read_Next (Right, Right_Line, Right_Key, Have_Right, Ok);
      end if;

      while Ok and then (Have_Left or else Have_Right) loop
         if not Have_Left then
            if not Suppress_2 then
               Emit (2, Right_Line);
            end if;
            Read_Next (Right, Right_Line, Right_Key, Have_Right, Ok);
         elsif not Have_Right then
            if not Suppress_1 then
               Emit (1, Left_Line);
            end if;
            Read_Next (Left, Left_Line, Left_Key, Have_Left, Ok);
         else
            declare
               Compared : constant Integer :=
                 Compare (Left_Line, Right_Line, Left_Key, Right_Key);
            begin
               if Compared = 0 then
                  if not Suppress_3 then
                     Emit (3, Left_Line);
                  end if;
                  Read_Next (Left, Left_Line, Left_Key, Have_Left, Ok);
                  if Ok then
                     Read_Next (Right, Right_Line, Right_Key, Have_Right, Ok);
                  end if;
               elsif Compared < 0 then
                  if not Suppress_1 then
                     Emit (1, Left_Line);
                  end if;
                  Read_Next (Left, Left_Line, Left_Key, Have_Left, Ok);
               else
                  if not Suppress_2 then
                     Emit (2, Right_Line);
                  end if;
                  Read_Next (Right, Right_Line, Right_Key, Have_Right, Ok);
               end if;
            end;
         end if;
         Ok := Ok and then not Context.Output_Failed;
      end loop;

      Flush_Output;
      Ok := Ok and then not Context.Output_Failed;

      declare
         Left_Closed, Right_Closed : Boolean;
      begin
         Posix_Tools.Commands.Line_Readers.Close (Left, Left_Closed);
         Posix_Tools.Commands.Line_Readers.Close (Right, Right_Closed);
         Ok := Ok and Left_Closed and Right_Closed;
      end;
      if not Ok and then not Context.Output_Failed then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end if;
      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Comm;
