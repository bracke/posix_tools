with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Nl_Numbering;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.NL_Fields;

package body Posix_Tools.Commands.Nl is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      use type Posix_Tools.Text.NL_Fields.Number_Mode;

      State      : Posix_Tools.Commands.Nl_Numbering.Numbering_State;
      First_File : Positive := 1;
      All_Ok     : Boolean := True;

      procedure Invalid_Value (Text : String);

      function Option_Value
        (Arg : String;
         Name : Character;
         Value_Text : out Unbounded_String) return Boolean;

      function Parse_Mode
        (Text : String;
         Mode : out Posix_Tools.Text.NL_Fields.Number_Mode) return Boolean;

      function Parse_Positive_Long (Text : String; Parsed : out Long_Long_Integer) return Boolean;

      procedure Set_Mode_Option (Option, Text : String; Ok : out Boolean);

      procedure Invalid_Value (Text : String) is
      begin
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "invalid operand '" & Text & "'");
      end Invalid_Value;

      function Option_Value (Arg : String; Name : Character; Value_Text : out Unbounded_String) return Boolean is
      begin
         if Arg'Length > 2 and then Arg (Arg'First) = '-' and then Arg (Arg'First + 1) = Name then
            Value_Text := To_Unbounded_String (Arg (Arg'First + 2 .. Arg'Last));
            return True;
         end if;

         return False;
      end Option_Value;

      function Parse_Mode
        (Text : String;
         Mode : out Posix_Tools.Text.NL_Fields.Number_Mode) return Boolean
      is
      begin
         Mode := Posix_Tools.Text.NL_Fields.Mode_For (Text);
         if Mode = Posix_Tools.Text.NL_Fields.Unknown_Number_Mode then
            Mode := Posix_Tools.Text.NL_Fields.No_Lines;
            return False;
         else
            return True;
         end if;
      end Parse_Mode;

      function Parse_Positive_Long (Text : String; Parsed : out Long_Long_Integer) return Boolean is
         Value : constant Posix_Tools.Text.NL_Fields.Parsed_Long_Long :=
           Posix_Tools.Text.NL_Fields.Positive_Long_Value (Text);
      begin
         if Value.Valid then
            Parsed := Value.Value;
            return True;
         else
            Parsed := 0;
            return False;
         end if;
      end Parse_Positive_Long;

      procedure Set_Mode_Option (Option, Text : String; Ok : out Boolean) is
         Parsed_Mode : Posix_Tools.Text.NL_Fields.Number_Mode;
      begin
         Ok := Parse_Mode (Text, Parsed_Mode);
         if not Ok then
            Invalid_Value (Text);
            return;
         end if;

         if Option = "-b" then
            State.Body_Mode := Parsed_Mode;
         elsif Option = "-h" then
            State.Header_Mode := Parsed_Mode;
         else
            State.Footer_Mode := Parsed_Mode;
         end if;
      end Set_Mode_Option;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First_File <= Context.Argument_Count loop
         declare
            Arg        : constant String := Context.Argument (First_File);
            Parsed     : Long_Long_Integer;
            Option_Arg : Unbounded_String;
            Mode_Ok    : Boolean;
         begin
            if Arg = "--" then
               First_File := First_File + 1;
               exit;
            elsif Arg = "-p" then
               State.No_Restart := True;
               First_File := First_File + 1;
            elsif Arg = "-b" or else Arg = "-h" or else Arg = "-f" then
               if First_File >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '" & Arg & "'");
                  return;
               end if;
               Set_Mode_Option (Arg, Context.Argument (First_File + 1), Mode_Ok);
               if not Mode_Ok then
                  return;
               end if;
               First_File := First_File + 2;
            elsif Arg'Length = 3
              and then Arg (Arg'First) = '-'
              and then Arg (Arg'First + 1) in 'b' | 'h' | 'f'
            then
               Set_Mode_Option
                 (Arg (Arg'First .. Arg'First + 1), Arg (Arg'Last .. Arg'Last), Mode_Ok);
               if not Mode_Ok then
                  return;
               end if;
               First_File := First_File + 1;
            elsif Arg = "-i" or else Arg = "-v" or else Arg = "-w" or else Arg = "-s" or else Arg = "-d" then
               if First_File >= Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "missing option argument '" & Arg & "'");
                  return;
               end if;
               Option_Arg := To_Unbounded_String (Context.Argument (First_File + 1));
               if Arg = "-i" then
                  if not Parse_Positive_Long (To_String (Option_Arg), State.Increment) then
                     Invalid_Value (To_String (Option_Arg));
                     return;
                  end if;
               elsif Arg = "-v" then
                  if not Posix_Tools.Commands.Text_Helpers.Parse_Long_Long_Text
                    (To_String (Option_Arg), State.Value)
                  then
                     Invalid_Value (To_String (Option_Arg));
                     return;
                  end if;
                  State.Initial_Value := State.Value;
               elsif Arg = "-w" then
                  if not Parse_Positive_Long (To_String (Option_Arg), Parsed)
                    or else Parsed > Long_Long_Integer (Natural'Last)
                  then
                     Invalid_Value (To_String (Option_Arg));
                     return;
                  end if;
                  State.Width := Natural (Parsed);
               elsif Arg = "-d" then
                  if Length (Option_Arg) /= 2 then
                     Invalid_Value (To_String (Option_Arg));
                     return;
                  end if;
                  declare
                     Text : constant String := To_String (Option_Arg);
                  begin
                     State.Delimiter := [1 => Text (Text'First), 2 => Text (Text'First + 1)];
                  end;
               else
                  State.Separator := Option_Arg;
               end if;
               First_File := First_File + 2;
            elsif Option_Value (Arg, 'i', Option_Arg) then
               if not Parse_Positive_Long (To_String (Option_Arg), State.Increment) then
                  Invalid_Value (To_String (Option_Arg));
                  return;
               end if;
               First_File := First_File + 1;
            elsif Option_Value (Arg, 'v', Option_Arg) then
               if not Posix_Tools.Commands.Text_Helpers.Parse_Long_Long_Text
                 (To_String (Option_Arg), State.Value)
               then
                  Invalid_Value (To_String (Option_Arg));
                  return;
               end if;
               State.Initial_Value := State.Value;
               First_File := First_File + 1;
            elsif Option_Value (Arg, 'w', Option_Arg) then
               if not Parse_Positive_Long (To_String (Option_Arg), Parsed)
                 or else Parsed > Long_Long_Integer (Natural'Last)
               then
                  Invalid_Value (To_String (Option_Arg));
                  return;
               end if;
               State.Width := Natural (Parsed);
               First_File := First_File + 1;
            elsif Option_Value (Arg, 's', Option_Arg) then
               State.Separator := Option_Arg;
               First_File := First_File + 1;
            elsif Option_Value (Arg, 'd', Option_Arg) then
               if Length (Option_Arg) /= 2 then
                  Invalid_Value (To_String (Option_Arg));
                  return;
               end if;
               declare
                  Text : constant String := To_String (Option_Arg);
               begin
                  State.Delimiter := [1 => Text (Text'First), 2 => Text (Text'First + 1)];
               end;
               First_File := First_File + 1;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option " & Arg);
               return;
            else
               exit;
            end if;
         end;
      end loop;

      if Context.Argument_Count < First_File then
         Posix_Tools.Commands.Nl_Numbering.Number_File (Context, State, "-", All_Ok);
      else
         for I in First_File .. Context.Argument_Count loop
            declare
               Ok : Boolean;
            begin
               Posix_Tools.Commands.Nl_Numbering.Number_File (Context, State, Context.Argument (I), Ok);
               All_Ok := All_Ok and Ok;
               exit when Context.Output_Failed;
            end;
         end loop;
      end if;

      Result.Status :=
        (if All_Ok and then not Context.Output_Failed then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Nl;
