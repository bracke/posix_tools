with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Logname is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Name : Unbounded_String := To_Unbounded_String (Context.Environment_Value ("LOGNAME"));
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count > 0 then
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "extra operand '" & Context.Argument (1) & "'");
         return;
      end if;

      if Length (Name) = 0 then
         Name := To_Unbounded_String (Context.Current_Login_Name);
      end if;

      if Length (Name) = 0 then
         Name := To_Unbounded_String (Posix_Tools.Commands.Helpers.Current_User_Name (Context));
      end if;

      if Length (Name) > 0 then
         Context.Put_Line (To_String (Name));
         Result.Status :=
           (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
            else Posix_Tools.Exit_Status.Success);
      else
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;
end Posix_Tools.Commands.Logname;
