with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Uname is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Show_System  : Boolean := False;
      Show_Node    : Boolean := False;
      Show_Release : Boolean := False;
      Show_Version : Boolean := False;
      Show_Machine : Boolean := False;

      procedure Add_Field (Output : in out Unbounded_String; Value : String);

      procedure Add_Field (Output : in out Unbounded_String; Value : String) is
      begin
         if Length (Output) > 0 then
            Append (Output, " ");
         end if;
         Append (Output, (if Value = "" then "unknown" else Value));
      end Add_Field;

   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Arg = "--" then
               if I < Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "extra operand '" & Context.Argument (I + 1) & "'");
                  return;
               end if;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'a' =>
                        Show_System := True;
                        Show_Node := True;
                        Show_Release := True;
                        Show_Version := True;
                        Show_Machine := True;
                     when 's' =>
                        Show_System := True;
                     when 'n' =>
                        Show_Node := True;
                     when 'r' =>
                        Show_Release := True;
                     when 'v' =>
                        Show_Version := True;
                     when 'm' =>
                        Show_Machine := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Arg & "'");
               return;
            end if;
         end;
      end loop;

      if not (Show_System or else Show_Node or else Show_Release or else Show_Version or else Show_Machine) then
         Show_System := True;
      end if;

      declare
         Output : Unbounded_String;
      begin
         if Show_System then
            Add_Field (Output, Context.Current_System_Name);
         end if;
         if Show_Node then
            Add_Field (Output, Context.Current_Node_Name);
         end if;
         if Show_Release then
            Add_Field (Output, Context.Current_Release_Name);
         end if;
         if Show_Version then
            Add_Field (Output, Context.Current_Version_Name);
         end if;
         if Show_Machine then
            Add_Field (Output, Context.Current_Machine_Name);
         end if;
         Context.Put_Line (To_String (Output));
      end;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Uname;
