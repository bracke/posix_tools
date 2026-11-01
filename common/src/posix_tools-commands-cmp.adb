with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers.Streaming;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Text.Line_Breaks;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Cmp is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Silent : Boolean := False;
      List   : Boolean := False;
      First  : Positive;
      Valid  : Boolean;
      Left   : Unbounded_String;
      Right  : Unbounded_String;
      Ok     : Boolean;

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean);

      procedure Handle
        (Name   : Character;
         Value  : String;
         Result : in out Posix_Tools.Commands.Results.Result;
         Valid  : out Boolean)
      is
         pragma Unreferenced (Value, Result);
      begin
         if Name = 's' then
            Silent := True;
         else
            List := True;
         end if;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "ls", "", First, Valid);
      if not Valid then
         return;
      elsif Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      elsif Context.Argument_Count > First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Extra_Operand, Context.Argument (First + 2));
         return;
      end if;

      --  Exit status 1 says the files differ, so a file that cannot be read
      --  is trouble, a status above it.
      Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, Context.Argument (First), Left, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Cmp_Trouble;
         return;
      end if;
      Posix_Tools.Commands.File_Helpers.Streaming.Read_All (Context, Context.Argument (First + 1), Right, Ok);
      if not Ok then
         Result.Status := Posix_Tools.Exit_Status.Cmp_Trouble;
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
               if Silent then
                  exit;
               elsif List then
                  Context.Put_Line
                    (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                       (Long_Long_Integer (I)) & " "
                     & Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image
                       (Character'Pos (L (I)), 3) & " "
                     & Posix_Tools.Text.Numeric_Images.Fixed_Octal_Image
                       (Character'Pos (R (I)), 3));
                  exit when Context.Output_Failed;
               else
                  Context.Put_Line
                    (Context.Argument (First) & " " & Context.Argument (First + 1)
                     & " differ: byte "
                     & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                         (Long_Long_Integer (I))
                     & ", line " &
                       Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
                         (Posix_Tools.Text.Line_Breaks.Line_Number_Through
                            (L, I)));
                  Result.Status :=
                    (if Context.Output_Failed then Posix_Tools.Exit_Status.Cmp_Trouble
                     else Posix_Tools.Exit_Status.Operational_Failure);
                  return;
               end if;
            end if;
         end loop;

         if Context.Output_Failed then
            Result.Status := Posix_Tools.Exit_Status.Cmp_Trouble;
         elsif L'Length /= R'Length then
            --  POSIX writes "cmp: EOF on %s%s\n", naming the shorter file,
            --  to standard error.
            if not Silent then
               Posix_Tools.Commands.Helpers.Operational_Error
                 (Context,
                  "posix_tools.cmp.eof",
                  "file",
                  (if L'Length < R'Length then Context.Argument (First) else Context.Argument (First + 1)),
                  "EOF on {file}");
            end if;
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         elsif Different then
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         else
            Result.Status := Posix_Tools.Exit_Status.Success;
         end if;
      end;
   end Run;
end Posix_Tools.Commands.Cmp;
