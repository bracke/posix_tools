with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Cmp is
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Silent : Boolean := False;
      List   : Boolean := False;
      First  : Positive := 1;
      Left   : Unbounded_String;
      Right  : Unbounded_String;
      Ok     : Boolean;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "-s" then
            Silent := True;
            First := First + 1;
         elsif Context.Argument (First) = "-l" then
            List := True;
            First := First + 1;
         elsif Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         else
            exit;
         end if;
      end loop;
      if Context.Argument_Count /= First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      Posix_Tools.Commands.File_Helpers.Read_All (Context, Context.Argument (First), Left, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;
      Posix_Tools.Commands.File_Helpers.Read_All (Context, Context.Argument (First + 1), Right, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      declare
         L : constant String := To_String (Left);
         R : constant String := To_String (Right);
         Different : Boolean := False;
      begin
         for I in 1 .. Natural'Min (L'Length, R'Length) loop
            if L (I) /= R (I) then
               Different := True;
               if List and then not Silent then
                  Context.Put_Line
                    (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                       (Long_Long_Integer (I)) & " "
                     & Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image
                       (Character'Pos (L (I)), 3) & " "
                     & Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image
                       (Character'Pos (R (I)), 3));
               elsif not Silent then
                  Context.Put_Line
                    (Context.Argument (First) & " " & Context.Argument (First + 1)
                     & " differ: byte "
                     & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                         (Long_Long_Integer (I))
                     & ", line " &
                       Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                         (Posix_Tools.Text.Line_Breaks.Line_Number_Through
                            (L, I)));
                  Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
                  return;
               end if;
            end if;
         end loop;
         if L'Length /= R'Length then
            if not Silent then
               Context.Put_Line
                 ("cmp: EOF on "
                  & (if L'Length < R'Length then Context.Argument (First) else Context.Argument (First + 1)));
            end if;
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         elsif Different then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         else
            Result.Status :=
              (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
               else Posix_Tools.Exit_Status.Success);
         end if;
      end;
   end Run;
end Posix_Tools.Commands.Cmp;
