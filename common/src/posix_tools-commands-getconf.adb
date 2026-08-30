with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Getconf is
   use Ada.Strings.Unbounded;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Value : Unbounded_String;

      function Config_Value (Name : String; Value : out Unbounded_String) return Boolean;

      function Config_Value (Name : String; Value : out Unbounded_String) return Boolean is
         procedure Set (Text : String);

         procedure Set (Text : String) is
         begin
            Value := To_Unbounded_String (Text);
         end Set;
      begin
         if Name = "POSIX_VERSION" then
            Set ("202405");
         elsif Name = "POSIX2_VERSION" then
            Set ("202405");
         elsif Name = "PATH" then
            Set ("/bin:/usr/bin");
         elsif Name = "NAME_MAX" then
            declare
               Available : Boolean := False;
               Limit     : constant Natural := FS.File_Name_Limit (".", Available);
            begin
               Set
                 ((if Available
                   then Posix_Tools.Text.Numeric_Images.Integer_Image (Integer (Limit))
                   else "undefined"));
            end;
         elsif Name = "PATH_MAX" then
            declare
               Available : Boolean := False;
               Limit     : constant Natural := FS.Path_Name_Limit (".", Available);
            begin
               Set
                 ((if Available
                   then Posix_Tools.Text.Numeric_Images.Integer_Image (Integer (Limit))
                   else "undefined"));
            end;
         else
            Value := Null_Unbounded_String;
            return False;
         end if;

         return True;
      end Config_Value;

   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      if Context.Argument_Count = 0 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      elsif Context.Argument_Count > 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Context.Argument (3) & "'");
         return;
      end if;

      if Context.Argument_Count = 2 then
         if Context.Argument (2) = "" then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (2) & "'");
            return;
         elsif not FS.Exists (Context.Argument (2)) then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Context.Argument (2), "posix_tools.diagnostic.file.open_failed", "cannot open file");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;
      end if;

      if Config_Value (Context.Argument (1), Value) then
         Context.Put_Line (To_String (Value));
         Result.Status :=
           (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
            else Posix_Tools.Exit_Status.Success);
      else
         Posix_Tools.Commands.Helpers.Usage_Error
           (Context, Result, "invalid operand '" & Context.Argument (1) & "'");
      end if;
   end Run;
end Posix_Tools.Commands.Getconf;
