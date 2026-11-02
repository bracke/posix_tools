with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Nl_Numbering;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Text.NL_Fields;

package body Posix_Tools.Commands.Nl is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      use type Posix_Tools.Text.NL_Fields.Number_Mode;

      State      : Posix_Tools.Commands.Nl_Numbering.Numbering_State;
      First_File : Positive;
      Valid      : Boolean;
      All_Ok     : Boolean := True;

      function Parse_Mode
        (Text : String;
         Mode : out Posix_Tools.Text.NL_Fields.Number_Mode) return Boolean;

      function Parse_Positive_Long (Text : String; Parsed : out Long_Long_Integer) return Boolean;

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
      begin
         Valid := True;
         case Name is
            when 'p' =>
               State.No_Restart := True;
            when 'b' | 'h' | 'f' =>
               declare
                  Parsed_Mode : Posix_Tools.Text.NL_Fields.Number_Mode;
               begin
                  Valid := Parse_Mode (Value, Parsed_Mode);
                  if not Valid then
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  elsif Name = 'b' then
                     State.Body_Mode := Parsed_Mode;
                  elsif Name = 'h' then
                     State.Header_Mode := Parsed_Mode;
                  else
                     State.Footer_Mode := Parsed_Mode;
                  end if;
               end;
            when 'i' =>
               if not Parse_Positive_Long (Value, State.Increment) then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               end if;
            when 'v' =>
               if Posix_Tools.Commands.Text_Helpers.Parse_Long_Long_Text (Value, State.Value) then
                  State.Initial_Value := State.Value;
               else
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               end if;
            when 'w' =>
               declare
                  Parsed : Long_Long_Integer;
               begin
                  if Parse_Positive_Long (Value, Parsed) and then Parsed <= Long_Long_Integer (Natural'Last) then
                     State.Width := Natural (Parsed);
                  else
                     Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                     Valid := False;
                  end if;
               end;
            when 's' =>
               State.Separator := To_Unbounded_String (Value);
            when others =>
               if Value'Length = 2 then
                  State.Delimiter := [1 => Value (Value'First), 2 => Value (Value'First + 1)];
               else
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Value);
                  Valid := False;
               end if;
         end case;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "bdfhipsvw", "bdfhisvw", First_File, Valid);
      if not Valid then
         return;
      end if;

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

      Posix_Tools.Commands.Helpers.Finish (Context, Result, All_Ok);
   end Run;
end Posix_Tools.Commands.Nl;
