with Ada.Strings.Unbounded;
with I18N.Collation;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Decimal_Parsing;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Test_Operators;

package body Posix_Tools.Commands.Test_Command is
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;
   use type Posix_Tools.Host_Adapters.File_System.Special_File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      use Ada.Strings.Unbounded;

      --  The expression could not be parsed.
      Syntax_Error  : Boolean := False;
      --  The usage diagnostic for it, when a more precise one than
      --  "invalid expression" applies.
      Syntax_Detail : Unbounded_String;
      --  The first operand of an integer comparison that is not an integer.
      Bad_Integer   : Unbounded_String;
      Has_Bad_Integer : Boolean := False;

      --  The general grammar for more than four arguments (XSI): '!' binds
      --  tighter than -a, -a tighter than -o, and parentheses group.
      Position : Positive := 1;
      Last     : Natural := 0;

      function Arg (Index : Positive) return String is (Context.Argument (Index));
      function Binary_Test (Left, Op, Right : String) return Boolean;
      function Collation_Locale return String;
      function Evaluate (First : Positive; Count : Natural) return Boolean;
      function Integer_Operand (Text : String) return Boolean;
      procedure Invalid (Detail : String := "");
      function Parse_And return Boolean;
      function Parse_Expression (First, Final : Positive) return Boolean;
      function Parse_Not return Boolean;
      function Parse_Or return Boolean;
      function Parse_Primary return Boolean;
      function String_Comparison (Left, Op, Right : String) return Boolean;
      function Unary_Test (Op, Operand : String) return Boolean;

      --  A binary primary of $2 between $1 and $3; -a and -o are the XSI
      --  binary primaries "both nonempty" and "either nonempty".
      function Binary_Test (Left, Op, Right : String) return Boolean is
      begin
         if Op = "-a" then
            return Left /= "" and then Right /= "";
         elsif Op = "-o" then
            return Left /= "" or else Right /= "";
         elsif Op = "=" then
            return Left = Right;
         elsif Op = "!=" then
            return Left /= Right;
         elsif Op = "<" or else Op = ">" then
            return String_Comparison (Left, Op, Right);
         elsif Op = "-ef" then
            return FS.Same_File (Left, Right);
         elsif not Integer_Operand (Left) or else not Integer_Operand (Right) then
            return False;
         else
            return Posix_Tools.Text.Test_Operators.Numeric_Comparison (Left, Op, Right);
         end if;
      exception
         when Constraint_Error =>
            return False;
      end Binary_Test;

      function Collation_Locale return String is
         LC_All     : constant String := Context.Environment_Value ("LC_ALL");
         LC_Collate : constant String := Context.Environment_Value ("LC_COLLATE");
         Lang       : constant String := Context.Environment_Value ("LANG");
      begin
         if LC_All /= "" then
            return LC_All;
         elsif LC_Collate /= "" then
            return LC_Collate;
         elsif Lang /= "" then
            return Lang;
         else
            return Context.Effective_Locale;
         end if;
      end Collation_Locale;

      --  XCU test decides by the number of arguments before it parses: the
      --  rules for up to four arguments come first, so "x = -a" compares two
      --  strings and "( = (" is true.
      function Evaluate (First : Positive; Count : Natural) return Boolean is
      begin
         case Count is
            when 0 =>
               return False;
            when 1 =>
               return Arg (First) /= "";
            when 2 =>
               if Arg (First) = "!" then
                  return Arg (First + 1) = "";
               elsif Posix_Tools.Text.Test_Operators.Is_Unary_Operator (Arg (First)) then
                  return Unary_Test (Arg (First), Arg (First + 1));
               elsif Arg (First)'Length > 1 and then Arg (First) (Arg (First)'First) = '-' then
                  Invalid ("unknown option '" & Arg (First) & "'");
               else
                  Invalid;
               end if;
               return False;
            when 3 =>
               if Posix_Tools.Text.Test_Operators.Is_Binary_Operator (Arg (First + 1))
                 or else Arg (First + 1) in "-a" | "-o"
               then
                  return Binary_Test (Arg (First), Arg (First + 1), Arg (First + 2));
               elsif Arg (First) = "!" then
                  return not Evaluate (First + 1, 2);
               elsif Arg (First) = "(" and then Arg (First + 2) = ")" then
                  return Evaluate (First + 1, 1);
               elsif Arg (First + 1)'Length > 0
                 and then Arg (First + 1) (Arg (First + 1)'First) in '-' | '=' | '<' | '>'
               then
                  Invalid ("unknown operator '" & Arg (First + 1) & "'");
               else
                  Invalid;
               end if;
               return False;
            when 4 =>
               if Arg (First) = "!" then
                  return not Evaluate (First + 1, 3);
               elsif Arg (First) = "(" and then Arg (First + 3) = ")" then
                  return Evaluate (First + 1, 2);
               else
                  return Parse_Expression (First, First + 3);
               end if;
            when others =>
               return Parse_Expression (First, First + Count - 1);
         end case;
      end Evaluate;

      --  Is Text an integer for -eq and its kind? The first one that is not
      --  is kept for the diagnostic.
      function Integer_Operand (Text : String) return Boolean is
      begin
         if Posix_Tools.Text.Decimal_Parsing.Long_Long_Value (Text).Valid then
            return True;
         end if;
         if not Has_Bad_Integer then
            Has_Bad_Integer := True;
            Bad_Integer := To_Unbounded_String (Text);
         end if;
         return False;
      end Integer_Operand;

      procedure Invalid (Detail : String := "") is
      begin
         if not Syntax_Error then
            Syntax_Error := True;
            Syntax_Detail := To_Unbounded_String (Detail);
         end if;
      end Invalid;

      function Parse_And return Boolean is
         Value : Boolean := Parse_Not;
      begin
         while not Syntax_Error and then Position <= Last and then Arg (Position) = "-a" loop
            Position := Position + 1;
            declare
               Right : constant Boolean := Parse_Not;
            begin
               Value := Value and Right;
            end;
         end loop;
         return Value;
      end Parse_And;

      function Parse_Expression (First, Final : Positive) return Boolean is
         Value : Boolean;
      begin
         Position := First;
         Last := Final;
         Value := Parse_Or;
         if not Syntax_Error and then Position <= Last then
            Invalid;
         end if;
         return Value;
      end Parse_Expression;

      function Parse_Not return Boolean is
      begin
         if Position <= Last and then Arg (Position) = "!" then
            Position := Position + 1;
            return not Parse_Not;
         end if;
         return Parse_Primary;
      end Parse_Not;

      function Parse_Or return Boolean is
         Value : Boolean := Parse_And;
      begin
         while not Syntax_Error and then Position <= Last and then Arg (Position) = "-o" loop
            Position := Position + 1;
            declare
               Right : constant Boolean := Parse_And;
            begin
               Value := Value or Right;
            end;
         end loop;
         return Value;
      end Parse_Or;

      function Parse_Primary return Boolean is
      begin
         if Position > Last then
            Invalid;
            return False;
         end if;

         declare
            Token : constant String := Arg (Position);
         begin
            if Position + 2 <= Last
              and then Posix_Tools.Text.Test_Operators.Is_Binary_Operator (Arg (Position + 1))
            then
               Position := Position + 3;
               return Binary_Test (Token, Arg (Position - 2), Arg (Position - 1));
            elsif Token = "(" then
               Position := Position + 1;
               declare
                  Value : constant Boolean := Parse_Or;
               begin
                  if Syntax_Error or else Position > Last or else Arg (Position) /= ")" then
                     Invalid;
                     return False;
                  end if;
                  Position := Position + 1;
                  return Value;
               end;
            elsif Posix_Tools.Text.Test_Operators.Is_Unary_Operator (Token) and then Position < Last then
               Position := Position + 2;
               return Unary_Test (Token, Arg (Position - 1));
            elsif Token in ")" | "-a" | "-o" then
               Invalid;
               return False;
            else
               Position := Position + 1;
               return Token /= "";
            end if;
         end;
      end Parse_Primary;

      function String_Comparison (Left, Op, Right : String) return Boolean is
         Locale   : constant String := Collation_Locale;
         Family   : constant String := Posix_Tools.Commands.Text_Helpers.Locale_Family (Locale);
         Compared : Integer;
      begin
         if Family = ""
           or else Family = "c"
           or else Family = "C"
           or else Family = "posix"
           or else Family = "POSIX"
         then
            Compared :=
              (if Left < Right then -1
               elsif Left > Right then 1
               else 0);
         elsif I18N.Collation.Available then
            Compared := I18N.Collation.Compare (Left, Right, Locale, I18N.Collation.Tertiary);
         else
            declare
               Left_Key  : constant String :=
                 Posix_Tools.Commands.Text_Helpers.Locale_Sort_Text (Locale, Left);
               Right_Key : constant String :=
                 Posix_Tools.Commands.Text_Helpers.Locale_Sort_Text (Locale, Right);
            begin
               Compared :=
                 (if Left_Key < Right_Key then -1
                  elsif Left_Key > Right_Key then 1
                  else 0);
            end;
         end if;

         return
           (if Op = "<" then Compared < 0
            elsif Op = ">" then Compared > 0
            else False);
      exception
         when Constraint_Error =>
            return
              (if Op = "<" then Left < Right
               elsif Op = ">" then Left > Right
               else False);
      end String_Comparison;

      function Unary_Test (Op, Operand : String) return Boolean is
         function Has_Any_Mode_Bit (Mode, Mask : Natural) return Boolean;
         function Terminal_File_Descriptor return Boolean;

         function Has_Any_Mode_Bit (Mode, Mask : Natural) return Boolean is
         begin
            return Posix_Tools.Text.File_Modes.Has_Any_Mode_Bit (Mode, Mask);
         end Has_Any_Mode_Bit;

         function Terminal_File_Descriptor return Boolean is
         begin
            if Operand = "0" then
               return Context.Standard_Input_Is_Terminal;
            elsif Operand = "1" then
               return Context.Standard_Output_Is_Terminal;
            elsif Operand = "2" then
               return Context.Standard_Error_Is_Terminal;
            else
               return False;
            end if;
         end Terminal_File_Descriptor;
      begin
         if Op = "-e" then
            return FS.Exists (Operand);
         elsif Op = "-h" or else Op = "-L" then
            return FS.Is_Link (Operand);
         elsif Op = "-n" then
            return Operand /= "";
         elsif Op = "-z" then
            return Operand = "";
         elsif Op = "-d" then
            return FS.Kind (Operand) = FS.Directory;
         elsif Op = "-f" then
            return FS.Kind (Operand) = FS.Ordinary_File;
         elsif Op in "-b" | "-c" | "-p" | "-S" then
            declare
               Info : constant FS.Special_File_Info := FS.Special_File_Info_Of (Operand);
            begin
               return Info.Available
                 and then
                   (if Op = "-b" then Info.Kind = FS.Block_Device
                    elsif Op = "-c" then Info.Kind = FS.Character_Device
                    elsif Op = "-p" then Info.Kind = FS.FIFO
                    else Info.Kind = FS.Socket);
            end;
         elsif Op = "-s" then
            return FS.Kind (Operand) = FS.Ordinary_File
              and then FS.Size (Operand) > 0;
         elsif Op = "-t" then
            return Terminal_File_Descriptor;
         elsif Op in "-g" | "-k" | "-u" then
            declare
               Available : Boolean;
               Mode      : constant Natural := FS.File_Permission_Bits (Operand, Available);
               Mask      : constant Natural :=
                 (if Op = "-u" then 8#4000#
                  elsif Op = "-g" then 8#2000#
                  else 8#1000#);
            begin
               return FS.Permissions_Supported
                 and then Available
                 and then (Mode / Mask) mod 2 = 1;
            end;
         elsif Op = "-r" then
            declare
               Ok      : Boolean := False;
               Ignored : constant String :=
                 Posix_Tools.Commands.File_Helpers.Read_File (Context, Operand, Ok);
            begin
               return Ok;
            end;
         elsif Op = "-w" or else Op = "-x" then
            declare
               Available : Boolean;
               Mode      : constant Natural := FS.File_Permission_Bits (Operand, Available);
               Mask      : constant Natural := (if Op = "-w" then 8#222# else 8#111#);
            begin
               return FS.Permissions_Supported
                 and then Available
                 and then Has_Any_Mode_Bit (Mode, Mask);
            end;
         else
            return False;
         end if;
      exception
         when others =>
            return False;
      end Unary_Test;

      Truth : Boolean;
   begin
      --  Every argument is an operand of the expression, so the project
      --  extensions are recognized only as a sole argument.
      if Posix_Tools.Commands.Helpers.Intercept_Extension
        (Context, Result, Conventional => False)
      then
         return;
      end if;

      Truth := Evaluate (1, Context.Argument_Count);

      if Syntax_Error then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context,
            Result,
            (if Length (Syntax_Detail) > 0 then To_String (Syntax_Detail) else "invalid expression"));
      elsif Has_Bad_Integer then
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context,
            To_String (Bad_Integer),
            "posix_tools.diagnostic.integer.expected",
            "integer expression expected");
         Result.Status := Posix_Tools.Exit_Status.Invalid_Usage;
      else
         Result.Status :=
           (if Truth then Posix_Tools.Exit_Status.Success
            else Posix_Tools.Exit_Status.Operational_Failure);
      end if;
   end Run;
end Posix_Tools.Commands.Test_Command;
