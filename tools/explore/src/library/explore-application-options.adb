with Posix_Tools.Commands.Helpers;

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

      --  Whether Argument is the option Name, taking its value into Value:
      --  the rest of Argument after "Name=", or the next argument.
      function Takes (Argument, Name : String; Value : in out Unbounded.Unbounded_String) return Boolean;

      function Takes (Argument, Name : String; Value : in out Unbounded.Unbounded_String) return Boolean is
      begin
         if Argument = Name and then I < Context.Argument_Count then
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
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '" & Argument & "'");
                  Ok := False;
                  return;
               end if;
            elsif Unbounded.Length (Into.Directory) > 0 then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Argument & "'");
               Ok := False;
               return;
            else
               Into.Directory := Unbounded.To_Unbounded_String (Argument);
            end if;
         end;

         I := I + 1;
      end loop;
   end Parse;
end Explore.Application.Options;
