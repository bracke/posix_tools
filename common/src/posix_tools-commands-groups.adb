with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Host;

package body Posix_Tools.Commands.Groups is
   use Ada.Strings.Unbounded;

   package Host renames Posix_Tools.Host_Adapters.Host;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Groups     : Host.Group_Id_List (1 .. 256);
      Group_Last : Natural := 0;

   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 0 then
         if not Context.Current_Group_Ids (Groups, Group_Last) then
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;
      else
         declare
            First : Positive := 1;
         begin
            if Context.Argument (1) = "--" then
               First := 2;
               if Context.Argument_Count = 1 then
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
                  return;
               end if;
            end if;

            for Operand in First .. Context.Argument_Count loop
               declare
                  User_Groups : Host.Group_Id_List (1 .. 256);
                  User_Last   : Natural := 0;
                  Output      : Unbounded_String;
               begin
                  if not Context.User_Group_Ids (Context.Argument (Operand), User_Groups, User_Last) then
                     Posix_Tools.Commands.Helpers.Subject_Operational_Error
                       (Context, Context.Argument (Operand), "posix_tools.diagnostic.unsupported",
                        "unsupported platform capability");
                     Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                     return;
                  end if;

                  Append (Output, Context.Argument (Operand) & " :");
                  for Index in 1 .. User_Last loop
                     Append
                       (Output,
                        " " & Posix_Tools.Commands.Helpers.Group_Id_Text (Context, User_Groups (Index)));
                  end loop;
                  Context.Put_Line (To_String (Output));
               end;
            end loop;
         end;
         Result.Status :=
           (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
            else Posix_Tools.Exit_Status.Success);
         return;
      end if;

      declare
         Output : Unbounded_String;
      begin
         for Index in 1 .. Group_Last loop
            if Index > 1 then
               Append (Output, " ");
            end if;
            Append (Output, Posix_Tools.Commands.Helpers.Group_Id_Text (Context, Groups (Index)));
         end loop;
         Context.Put_Line (To_String (Output));
      end;

      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Groups;
