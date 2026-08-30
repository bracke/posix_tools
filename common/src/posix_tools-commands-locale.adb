with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Locale is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Categories : constant array (Positive range 1 .. 6) of Unbounded_String :=
        [To_Unbounded_String ("LANG"),
         To_Unbounded_String ("LC_CTYPE"),
         To_Unbounded_String ("LC_COLLATE"),
         To_Unbounded_String ("LC_MESSAGES"),
         To_Unbounded_String ("LC_NUMERIC"),
         To_Unbounded_String ("LC_TIME")];

      function Effective_Value (Name : String) return String;

      function Effective_Value (Name : String) return String is
         Specific : constant String := Context.Environment_Value (Name);
         Lang     : constant String := Context.Environment_Value ("LANG");
      begin
         if Specific /= "" then
            return Specific;
         elsif Lang /= "" then
            return Lang;
         else
            return "C";
         end if;
      end Effective_Value;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 1 and then Context.Argument (1) = "-a" then
         Context.Put_Line ("C");
         Context.Put_Line ("POSIX");
      elsif Context.Argument_Count = 1 and then Context.Argument (1) = "-m" then
         Context.Put_Line ("UTF-8");
      elsif Context.Argument_Count = 0 then
         for Name of Categories loop
            declare
               Name_Text : constant String := To_String (Name);
            begin
               Context.Put_Line (Name_Text & "=""" & Effective_Value (Name_Text) & """");
            end;
            exit when Context.Output_Failed;
         end loop;
      else
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result,
            (if Context.Argument_Count > 1 then "extra operand '" & Context.Argument (2) & "'"
             else "unknown option '" & Context.Argument (1) & "'"));
         return;
      end if;

      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Locale;
