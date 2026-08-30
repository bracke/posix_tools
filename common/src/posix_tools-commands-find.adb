with Ada.Containers;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Find_Evaluation;
with Posix_Tools.Commands.Find_Validation;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Find_Expressions;

package body Posix_Tools.Commands.Find is
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Paths       : Posix_Tools.Arguments.Vector;
      Expression  : Posix_Tools.Arguments.Vector;
      Evaluation  : Posix_Tools.Commands.Find_Evaluation.Evaluation_State;
      Has_Print   : Boolean := False;
      Ok          : Boolean := True;

      procedure Visit
        (Path                  : String;
         Root_Device           : Long_Long_Integer;
         Root_Device_Available : Boolean)
      is
         Exists : constant Boolean := FS.Exists (Path);
         Kind   : constant FS.File_Kind := FS.Kind (Path);
         Current_Device_Available : Boolean := False;
         Current_Device : constant Long_Long_Integer := FS.Device_Id (Path, Current_Device_Available);
         Crosses_Device : constant Boolean :=
           Posix_Tools.Commands.Find_Evaluation.Has_Xdev (Evaluation)
           and then Root_Device_Available
           and then Current_Device_Available
           and then Current_Device /= Root_Device;
         Path_Result : Posix_Tools.Commands.Find_Evaluation.Path_Result;

         procedure Evaluate_And_Maybe_Print is
         begin
            Posix_Tools.Commands.Find_Evaluation.Evaluate_Path
              (Evaluation, Context, Path, Path_Result);
            if not Path_Result.Valid then
               Ok := False;
            elsif not Has_Print and then Path_Result.Matches then
               Context.Put_Line (Path);
            end if;
         end Evaluate_And_Maybe_Print;
      begin
         if not Posix_Tools.Commands.Find_Evaluation.Has_Depth (Evaluation) then
            Evaluate_And_Maybe_Print;
         end if;

         if Exists
           and then Kind = FS.Directory
           and then not Path_Result.Pruned
           and then not Crosses_Device
         then
            declare
               Iteration_Ok : Boolean;

               procedure Visit_Child (Name : String; Full_Name : String; Stop : in out Boolean) is
               begin
                  pragma Unreferenced (Name, Stop);
                  Visit (Full_Name, Root_Device, Root_Device_Available);
               end Visit_Child;

               procedure For_Each_Child is new FS.For_Each_Directory_Entry (Visit_Child);
            begin
               For_Each_Child (Path, Iteration_Ok);
               Ok := Ok and Iteration_Ok;
            end;
         end if;

         if Posix_Tools.Commands.Find_Evaluation.Has_Depth (Evaluation) then
            Evaluate_And_Maybe_Print;
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end Visit;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      declare
         I : Positive := 1;
         End_Options : Boolean := False;
      begin
         while I <= Context.Argument_Count loop
            if not End_Options and then Context.Argument (I) = "--" then
               End_Options := True;
               I := I + 1;
            elsif not End_Options
              and then Posix_Tools.Text.Find_Expressions.Is_Expression_Start (Context.Argument (I))
            then
               for J in I .. Context.Argument_Count loop
                  Expression.Append (Context.Argument (J));
                  if Context.Argument (J) = "-print"
                    or else Context.Argument (J) = "-exec"
                    or else Context.Argument (J) = "-ok"
                  then
                     Has_Print := True;
                  end if;
               end loop;
               exit;
            elsif not End_Options
              and then Context.Argument (I)'Length > 1
              and then Context.Argument (I) (Context.Argument (I)'First) = '-'
            then
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, "unknown option '" & Context.Argument (I) & "'");
               return;
            else
               Paths.Append (Context.Argument (I));
               I := I + 1;
            end if;
         end loop;
      end;

      if Expression.Length > 0
        and then not Posix_Tools.Commands.Find_Validation.Validate_Expression
          (Context, Result, Expression)
      then
         return;
      end if;

      Posix_Tools.Commands.Find_Evaluation.Initialize (Evaluation, Expression);

      if Paths.Length = 0 then
         declare
            Available : Boolean := False;
            Device    : constant Long_Long_Integer := FS.Device_Id (".", Available);
         begin
            Visit (".", Device, Available);
         end;
      else
         for I in 1 .. Natural (Paths.Length) loop
            declare
               Available : Boolean := False;
               Device    : constant Long_Long_Integer := FS.Device_Id (Paths.Element (I), Available);
            begin
               Visit (Paths.Element (I), Device, Available);
            end;
         end loop;
      end if;

      Posix_Tools.Commands.Find_Evaluation.Flush_Exec_Batches
        (Evaluation, Context, Ok);

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;

end Posix_Tools.Commands.Find;
