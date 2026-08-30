with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Portable_Paths;

package body Posix_Tools.Commands.Pathchk is
   use Ada.Strings.Unbounded;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Portable_Mode : Boolean := False;
      First         : Positive := 1;
      All_Ok        : Boolean := True;

      procedure Check_Component (Path, Parent_Path, Component : String);
      procedure Check_Path (Path : String);
      function Component_Limit (Parent_Path : String) return Natural;
      function Path_Limit return Natural;
      procedure Reject (Path, Reason : String);

      procedure Check_Component (Path, Parent_Path, Component : String) is
      begin
         if Component'Length > Component_Limit (Parent_Path) then
            Reject (Path, "component too long");
         elsif Portable_Mode
           and then not Posix_Tools.Text.Portable_Paths.Portable_Component (Component)
         then
            Reject (Path, "non-portable character");
         end if;
      end Check_Component;

      procedure Check_Path (Path : String) is
         Start  : Natural := Path'First;
         Parent : Unbounded_String :=
           To_Unbounded_String (if Path'Length > 0 and then Path (Path'First) = '/' then "/" else ".");
      begin
         if Path = "" then
            Reject (Path, "empty pathname");
            return;
         elsif Path'Length > Path_Limit then
            Reject (Path, "pathname too long");
            return;
         end if;

         while Start <= Path'Last loop
            while Start <= Path'Last and then Path (Start) = '/' loop
               Start := Start + 1;
            end loop;

            exit when Start > Path'Last;

            declare
               Stop : Natural := Start;
            begin
               while Stop <= Path'Last and then Path (Stop) /= '/' loop
                  Stop := Stop + 1;
               end loop;

               declare
                  Component : constant String := Path (Start .. Stop - 1);
               begin
                  Check_Component (Path, To_String (Parent), Component);
                  if To_String (Parent) = "/" then
                     Parent := To_Unbounded_String ("/" & Component);
                  elsif To_String (Parent) = "." then
                     Parent := To_Unbounded_String (Component);
                  else
                     Append (Parent, "/" & Component);
                  end if;
               end;
               Start := Stop + 1;
            end;
         end loop;
      end Check_Path;

      function Component_Limit (Parent_Path : String) return Natural is
         Available : Boolean := False;
         Limit     : constant Natural := FS.File_Name_Limit (Parent_Path, Available);
      begin
         if Portable_Mode then
            return 14;
         elsif Available and then Limit > 0 then
            return Limit;
         else
            return 255;
         end if;
      end Component_Limit;

      function Path_Limit return Natural is
         Available : Boolean := False;
         Limit     : constant Natural := FS.Path_Name_Limit (".", Available);
      begin
         if Portable_Mode then
            return 256;
         elsif Available and then Limit > 0 then
            return Limit;
         else
            return 4_096;
         end if;
      end Path_Limit;

      procedure Reject (Path, Reason : String) is
      begin
         All_Ok := False;
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Path, "posix_tools.pathchk.invalid_path", Reason);
      end Reject;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg = "-p" then
               Portable_Mode := True;
               First := First + 1;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option " & Arg);
               return;
            else
               exit;
            end if;
         end;
      end loop;

      if First > Context.Argument_Count then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for Index in First .. Context.Argument_Count loop
         Check_Path (Context.Argument (Index));
      end loop;

      Result.Status :=
        (if All_Ok then Posix_Tools.Exit_Status.Success else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Pathchk;
