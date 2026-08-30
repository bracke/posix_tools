with I18N.Collation;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
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

      function Evaluate_One (Operand : String) return Boolean is
      begin
         return Operand /= "";
      end Evaluate_One;

      function Evaluate_Three (Left, Op, Right : String) return Boolean is
      begin
         return
           (if Op = "=" then Left = Right
            elsif Op = "!=" then Left /= Right
            elsif Op = "<" or else Op = ">" then String_Comparison (Left, Op, Right)
            elsif Op = "-ef" then FS.Same_File (Left, Right)
            elsif Op in "-eq" | "-ne" | "-gt" | "-ge" | "-lt" | "-le" then
               Posix_Tools.Text.Test_Operators.Numeric_Comparison (Left, Op, Right)
            else False);
      exception
         when others =>
            return False;
      end Evaluate_Three;

      function Evaluate_Two (Op, Operand : String) return Boolean is
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
         elsif Op = "!" then
            return not Evaluate_One (Operand);
         else
            return False;
         end if;
      exception
         when others =>
            return False;
      end Evaluate_Two;

      function Parentheses_Balanced (First : Positive; Last : Natural) return Boolean is
         Depth : Integer := 0;
      begin
         for I in First .. Last loop
            if Context.Argument (I) = "(" then
               Depth := Depth + 1;
            elsif Context.Argument (I) = ")" then
               Depth := Depth - 1;
               if Depth < 0 then
                  return False;
               end if;
            end if;
         end loop;

         return Depth = 0;
      end Parentheses_Balanced;

      function Evaluate_Range (First : Positive; Last : Natural) return Boolean is
         Count : constant Natural := (if Last < First then 0 else Last - First + 1);
         Depth : Integer;
      begin
         if Count = 0 then
            return False;
         elsif Count >= 3
           and then Context.Argument (First) = "("
           and then Context.Argument (Last) = ")"
         then
            return Evaluate_Range (First + 1, Last - 1);
         end if;

         Depth := 0;
         for I in reverse First .. Last loop
            if Context.Argument (I) = ")" then
               Depth := Depth + 1;
            elsif Context.Argument (I) = "(" then
               Depth := Depth - 1;
            elsif Depth = 0 and then Context.Argument (I) = "-o" then
               return Evaluate_Range (First, I - 1) or else Evaluate_Range (I + 1, Last);
            end if;
         end loop;

         Depth := 0;
         for I in reverse First .. Last loop
            if Context.Argument (I) = ")" then
               Depth := Depth + 1;
            elsif Context.Argument (I) = "(" then
               Depth := Depth - 1;
            elsif Depth = 0 and then Context.Argument (I) = "-a" then
               return Evaluate_Range (First, I - 1) and then Evaluate_Range (I + 1, Last);
            end if;
         end loop;

         if Context.Argument (First) = "!" then
            return not Evaluate_Range (First + 1, Last);
         elsif Count = 1 then
            return Evaluate_One (Context.Argument (First));
         elsif Count = 2 then
            return Evaluate_Two (Context.Argument (First), Context.Argument (Last));
         elsif Count = 3 then
            return Evaluate_Three
              (Context.Argument (First), Context.Argument (First + 1), Context.Argument (Last));
         else
            return False;
         end if;
      end Evaluate_Range;

      Truth : Boolean;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 and then not Parentheses_Balanced (1, Context.Argument_Count) then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid expression");
         return;
      elsif Context.Argument_Count >= 1
        and then Context.Argument (Context.Argument_Count) in "-a" | "-o" | "!"
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid expression");
         return;
      elsif Context.Argument_Count = 2
        and then Context.Argument (1)'Length > 0
        and then Context.Argument (1) (Context.Argument (1)'First) = '-'
        and then not Posix_Tools.Text.Test_Operators.Is_Unary_Operator (Context.Argument (1))
        and then Context.Argument (1) /= "!"
      then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "unknown option '" & Context.Argument (1) & "'");
         return;
      elsif Context.Argument_Count = 3
        and then Context.Argument (1) /= "!"
        and then (Context.Argument (2)'Length > 0
                  and then (Context.Argument (2) (Context.Argument (2)'First) in '-' | '=' | '<' | '>'))
        and then Context.Argument (2) not in "-a" | "-o"
        and then not Posix_Tools.Text.Test_Operators.Is_Binary_Operator (Context.Argument (2))
      then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "unknown operator '" & Context.Argument (2) & "'");
         return;
      end if;

      Truth := Evaluate_Range (1, Context.Argument_Count);
      Result.Status :=
        (if Truth then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Test_Command;
