with Posix_Tools.Commands.Helpers;
with Posix_Tools.Localization;

package body Explore.Application.Options is
   package Unbounded renames Ada.Strings.Unbounded;

   procedure Parse
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Into    : out Option_Set;
      Ok      : out Boolean)
   is
      I             : Natural := 1;
      Operands_Only : Boolean := False;
      --  An option that takes a value was the last argument, without one.
      Missing       : Boolean := False;

      --  Report the usage error of Key, with Name standing for Value in it.
      procedure Refuse (Key, Name, Value, Default : String);

      --  Whether Argument is the option Name, taking its value into Value:
      --  the rest of Argument after "Name=", or the next argument.
      function Takes (Argument, Name : String; Value : in out Unbounded.Unbounded_String) return Boolean;

      procedure Refuse (Key, Name, Value, Default : String) is
      begin
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, Posix_Tools.Localization.Text_1 (Context.Effective_Locale, Key, Name, Value, Default));
         Ok := False;
      end Refuse;

      function Takes (Argument, Name : String; Value : in out Unbounded.Unbounded_String) return Boolean is
      begin
         if Argument = Name and then I = Context.Argument_Count then
            Missing := True;
            return True;
         elsif Argument = Name then
            I := I + 1;
            Value := Unbounded.To_Unbounded_String (Context.Argument (I));
            return True;
         elsif Argument'Length > Name'Length + 1
           and then Argument (Argument'First .. Argument'First + Name'Length) = Name & "="
         then
            Value := Unbounded.To_Unbounded_String (Argument (Argument'First + Name'Length + 1 .. Argument'Last));
            return True;
         else
            return False;
         end if;
      end Takes;
   begin
      Into := (others => <>);
      Ok := True;

      while I <= Context.Argument_Count loop
         declare
            Argument : constant String := Context.Argument (I);
         begin
            if not Operands_Only and then Argument = "--" then
               Operands_Only := True;
            elsif not Operands_Only and then Argument'Length > 1 and then Argument (Argument'First) = '-' then
               if not (Takes (Argument, "--config", Into.Config_Path)
                       or else Takes (Argument, "--cwd-file", Into.Cwd_File)
                       or else Takes (Argument, "--chooser-file", Into.Chooser_File))
               then
                  Refuse
                    ("posix_tools.diagnostic.option.unknown", "option", Argument, "unknown option '" & Argument & "'");
                  return;
               elsif Missing then
                  Refuse
                    ("posix_tools.diagnostic.missing_option_argument", "option", Argument,
                     "missing option argument '" & Argument & "'");
                  return;
               end if;
            elsif Unbounded.Length (Into.Directory) > 0 then
               Refuse
                 ("posix_tools.diagnostic.extra_operand", "operand", Argument, "extra operand '" & Argument & "'");
               return;
            else
               Into.Directory := Unbounded.To_Unbounded_String (Argument);
            end if;
         end;

         I := I + 1;
      end loop;
   end Parse;
end Explore.Application.Options;
