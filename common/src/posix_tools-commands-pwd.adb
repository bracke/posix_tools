with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Pwd is
   function Usable_Logical_Path (Path : String) return Boolean is
      Component_Start : Positive;
   begin
      if Path = "" or else Path (Path'First) /= '/' then
         return False;
      end if;

      Component_Start := Path'First + 1;
      for I in Component_Start .. Path'Last + 1 loop
         if I = Path'Last + 1 or else Path (I) = '/' then
            if I > Component_Start then
               declare
                  Component : constant String := Path (Component_Start .. I - 1);
               begin
                  if Component = "." or else Component = ".." then
                     return False;
                  end if;
               end;
            end if;

            if I <= Path'Last then
               Component_Start := I + 1;
            end if;
         end if;
      end loop;

      return True;
   end Usable_Logical_Path;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Logical : Boolean := True;
      Stop_Options : Boolean := False;
      Physical_Path : String (1 .. 4096);
      Physical_Last : Natural := 0;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         if Stop_Options then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (I) & "'");
            return;
         elsif Context.Argument (I) = "--" then
            Stop_Options := True;
         elsif Context.Argument (I) = "-L" then
            Logical := True;
         elsif Context.Argument (I) = "-P" then
            Logical := False;
         else
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (I) & "'");
            return;
         end if;
      end loop;

      declare
         Logical_Path : constant String := Context.Environment_Value ("PWD");
      begin
         if Logical
           and then Usable_Logical_Path (Logical_Path)
           and then Context.Path_Names_Current_Directory (Logical_Path)
         then
            Context.Put (Logical_Path & Character'Val (10));
         elsif Context.Try_Physical_Current_Directory (Physical_Path, Physical_Last)
           and then Physical_Last > 0
         then
            Context.Put (Physical_Path (Physical_Path'First .. Physical_Path'First + Physical_Last - 1)
                         & Character'Val (10));
         else
            Posix_Tools.Commands.Helpers.Operational_Error
              (Context, "posix_tools.diagnostic.pwd.unavailable", "cannot determine current directory");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;
      end;

      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Pwd;
