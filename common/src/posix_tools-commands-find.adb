with Ada.Containers;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Find_Evaluation;
with Posix_Tools.Commands.Find_Validation;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Find_Expressions;

package body Posix_Tools.Commands.Find is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   --  Which symbolic links the walk follows (XCU find, -H and -L): none, the
   --  ones named as path operands, or every one it meets.
   type Follow_Mode is (Physical, Command_Line, Logical);

   --  The bytes the environment takes in a new process: each NAME=value, its
   --  NUL and its pointer.
   function Environment_Size
     (Context : Posix_Tools.Commands.Contexts.Context'Class) return Natural;

   function Environment_Size
     (Context : Posix_Tools.Commands.Contexts.Context'Class) return Natural
   is
      Total : Natural := 0;
   begin
      for Pair of Context.Environment_Pairs loop
         Total := Total + Pair'Length + 1 + 8;
      end loop;
      return Total;
   end Environment_Size;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Paths       : Posix_Tools.Arguments.Vector;
      Expression  : Posix_Tools.Arguments.Vector;
      Evaluation  : Posix_Tools.Commands.Find_Evaluation.Evaluation_State;
      Has_Print   : Boolean := False;
      Ok          : Boolean := True;
      Mode        : Follow_Mode := Physical;

      --  The resolved names of the directories being walked, outermost first,
      --  kept where links are followed so a link back to one is a loop.
      Ancestors   : Posix_Tools.Arguments.Vector;

      function Forms_Loop (Path : String) return Boolean;
      function Parse_Follow_Options (Text : String) return Boolean;
      procedure Visit
        (Path                  : String;
         Is_Operand            : Boolean;
         Root_Device           : Long_Long_Integer;
         Root_Device_Available : Boolean);
      procedure Visit_Operand (Path : String);

      --  Is Path, a directory reached by following links, one of the
      --  directories it is inside (XCU find: loops shall be detected)?
      function Forms_Loop (Path : String) return Boolean is
         Resolved : constant String := FS.Real_Path (Path);
      begin
         for Ancestor of Ancestors loop
            if (Resolved /= "" and then Resolved = Ancestor)
              or else FS.Same_File (Path, Ancestor)
            then
               return True;
            end if;
         end loop;
         return False;
      end Forms_Loop;

      --  Is Text a group of the options -H, -L and -P? The last one named
      --  wins; -P, the default, follows no link.
      function Parse_Follow_Options (Text : String) return Boolean is
      begin
         if Text'Length < 2
           or else Text (Text'First) /= '-'
           or else (for some C of Text (Text'First + 1 .. Text'Last) => C not in 'H' | 'L' | 'P')
         then
            return False;
         end if;

         for C of Text (Text'First + 1 .. Text'Last) loop
            Mode :=
              (case C is
                 when 'H' => Command_Line,
                 when 'L' => Logical,
                 when others => Physical);
         end loop;
         return True;
      end Parse_Follow_Options;

      procedure Visit
        (Path                  : String;
         Is_Operand            : Boolean;
         Root_Device           : Long_Long_Integer;
         Root_Device_Available : Boolean)
      is
         Follow  : constant Boolean :=
           Mode = Logical or else (Mode = Command_Line and then Is_Operand);
         Is_Link : constant Boolean := FS.Is_Link (Path);
         --  Kind follows a link; a link whose target is missing is Missing_File.
         Resolved_Kind : constant FS.File_Kind := FS.Kind (Path);
         --  A link is examined as itself unless it is followed to a file that
         --  exists (XCU find: a followed link to nothing is the link).
         View : constant Posix_Tools.Commands.Find_Evaluation.Entry_View :=
           (if Is_Link and then not (Follow and then Resolved_Kind /= FS.Missing_File)
            then (Is_Link => True, Kind => FS.Missing_File)
            else (Is_Link => False, Kind => Resolved_Kind));
         Current_Device_Available : Boolean := False;
         Current_Device : constant Long_Long_Integer := FS.Device_Id (Path, Current_Device_Available);
         Crosses_Device : constant Boolean :=
           Posix_Tools.Commands.Find_Evaluation.Has_Xdev (Evaluation)
           and then Root_Device_Available
           and then Current_Device_Available
           and then Current_Device /= Root_Device;
         Path_Result : Posix_Tools.Commands.Find_Evaluation.Path_Result;

         procedure Evaluate_And_Maybe_Print;
         procedure Walk_Children;

         procedure Evaluate_And_Maybe_Print is
         begin
            Posix_Tools.Commands.Find_Evaluation.Evaluate_Path
              (Evaluation, Context, Path, View, Path_Result);
            if not Path_Result.Valid then
               Ok := False;
            elsif not Has_Print and then Path_Result.Matches then
               Context.Put_Line (Path);
            end if;
         end Evaluate_And_Maybe_Print;

         procedure Walk_Children is
            Iteration_Ok : Boolean;
            Tracked      : constant Boolean := Mode = Logical;

            procedure Visit_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

            --  Every entry, a link to nothing included, as the directory
            --  lists it.
            procedure Visit_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
               pragma Unreferenced (Kind, Stop);
            begin
               --  The search's own join is the host's, '\' on Windows; POSIX
               --  forms a child's pathname with '/'.
               Visit (FS.Child_Path (Path, Name), False, Root_Device, Root_Device_Available);
            end Visit_Child;

            procedure For_Each_Child is new FS.For_Each_Listed_Entry (Visit_Child);
         begin
            if Tracked then
               Ancestors.Append (FS.Real_Path (Path));
            end if;
            For_Each_Child (Path, Iteration_Ok);
            if Tracked then
               Ancestors.Delete_Last;
            end if;
            Ok := Ok and Iteration_Ok;
         end Walk_Children;
      begin
         --  A pathname that names nothing, not even a link, cannot be
         --  examined; XCU find diagnoses it and goes on with the rest.
         if not Is_Link and then Resolved_Kind = FS.Missing_File then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.missing", "no such file or directory");
            return;
         end if;

         if View.Kind = FS.Directory and then Mode = Logical and then Forms_Loop (Path) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.find.loop", "file system loop detected");
            return;
         end if;

         if not Posix_Tools.Commands.Find_Evaluation.Has_Depth (Evaluation) then
            Evaluate_And_Maybe_Print;
         end if;

         if View.Kind = FS.Directory
           and then not Path_Result.Pruned
           and then not Crosses_Device
         then
            Walk_Children;
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

      procedure Visit_Operand (Path : String) is
         Available : Boolean := False;
         Device    : constant Long_Long_Integer := FS.Device_Id (Path, Available);
      begin
         Ancestors.Clear;
         Visit (Path, True, Device, Available);
      end Visit_Operand;
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
              and then Paths.Is_Empty
              and then Parse_Follow_Options (Context.Argument (I))
            then
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
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unknown_Option, Context.Argument (I));
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

      Posix_Tools.Commands.Find_Evaluation.Initialize
        (Evaluation, Expression, Environment_Size (Context));

      if Paths.Length = 0 then
         Visit_Operand (".");
      else
         for Path of Paths loop
            Visit_Operand (Path);
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
