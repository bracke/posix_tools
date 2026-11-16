with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.IO_Exceptions;
with Posix_Tools.Arguments;
with Posix_Tools.Commands.Find_Evaluation;
with Posix_Tools.Commands.Find_Validation;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Find_Expressions;

package body Posix_Tools.Commands.Find is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.Host_Adapters.File_System.Entry_Kind;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;
   use type FS.Entry_Identity;

   package Entry_Identity_Vectors is new Ada.Containers.Vectors
     (Positive, FS.Entry_Identity, FS."=");

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
      Ancestors          : Posix_Tools.Arguments.Vector;
      Ancestor_Identities : Entry_Identity_Vectors.Vector;

      function Forms_Loop (Path : String) return Boolean;
      function Parse_Follow_Options (Text : String) return Boolean;
      procedure Visit
        (Path                  : String;
         Is_Operand            : Boolean;
         Root_Device           : Long_Long_Integer;
         Root_Device_Available : Boolean;
         Listed_As             : FS.Listed_Kind := FS.Listed_Unknown);
      procedure Visit_Operand (Path : String);

      --  Is Path, a directory reached by following links, one of the
      --  directories it is inside (XCU find: loops shall be detected)?
      function Forms_Loop (Path : String) return Boolean is
         Resolved : constant String := FS.Real_Path (Path);
         Current_Identity : constant FS.Entry_Identity :=
           FS.Entry_Identity_Of
             ((if Resolved = "" then Path else Resolved));
      begin
         for I in 1 .. Natural (Ancestors.Length) loop
            declare
               Ancestor          : constant String := Ancestors.Element (I);
               Ancestor_Identity : constant FS.Entry_Identity :=
                 Ancestor_Identities.Element (I);
            begin
               if (Resolved /= "" and then Resolved = Ancestor)
                 or else (Current_Identity.Available
                          and then Ancestor_Identity.Available
                          and then Current_Identity = Ancestor_Identity)
                 or else ((not Current_Identity.Available
                           or else not Ancestor_Identity.Available)
                          and then FS.Same_File (Path, Ancestor))
               then
                  return True;
               end if;
            end;
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
         Root_Device_Available : Boolean;
         Listed_As             : FS.Listed_Kind := FS.Listed_Unknown)
      is
         Follow  : constant Boolean :=
           Mode = Logical or else (Mode = Command_Line and then Is_Operand);
         --  Directory enumeration already obtained the child's own kind.
         --  Preserve that information instead of issuing another metadata
         --  query for every visited pathname. Operands and filesystems that
         --  do not expose a directory-entry type retain the full lookup.
         Entry_Type : constant FS.Entry_Kind :=
           (case Listed_As is
              when FS.Listed_Regular   => FS.Entry_Regular,
              when FS.Listed_Directory => FS.Entry_Directory,
              when FS.Listed_Link      => FS.Entry_Link,
              when FS.Listed_Other     => FS.Entry_Special,
              when FS.Listed_Unknown   => FS.Entry_Kind_Of (Path));
         Is_Link    : constant Boolean := Entry_Type = FS.Entry_Link;
         --  Kind follows a link; a link whose target is missing is Missing_File.
         Resolved_Kind : constant FS.File_Kind :=
           (case Entry_Type is
              when FS.Entry_Missing   => FS.Missing_File,
              when FS.Entry_Error     => FS.Missing_File,
              when FS.Entry_Directory => FS.Directory,
              when FS.Entry_Regular   => FS.Ordinary_File,
              when FS.Entry_Special   => FS.Special_File,
              when FS.Entry_Link      =>
                (if Follow then FS.Kind (Path) else FS.Missing_File));
         --  A link is examined as itself unless it is followed to a file that
         --  exists (XCU find: a followed link to nothing is the link).
         View : constant Posix_Tools.Commands.Find_Evaluation.Entry_View :=
           (if Is_Link and then not (Follow and then Resolved_Kind /= FS.Missing_File)
            then (Is_Link => True, Followed_Link => False, Kind => FS.Missing_File)
            else (Is_Link => False, Followed_Link => Is_Link, Kind => Resolved_Kind));
         Crosses_Device : Boolean := False;
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
               Posix_Tools.Commands.Find_Evaluation.Print_Path
                 (Evaluation, Context, Path);
            end if;
         end Evaluate_And_Maybe_Print;

         procedure Walk_Children is
            Iteration_Ok : Boolean;
            Tracked      : constant Boolean := Mode = Logical;

            procedure Visit_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean);

            --  Every entry, a link to nothing included, as the directory
            --  lists it.
            procedure Visit_Child (Name : String; Kind : FS.Listed_Kind; Stop : in out Boolean) is
            begin
               --  The search's own join is the host's, '\' on Windows; POSIX
               --  forms a child's pathname with '/'.
               Visit
                 (FS.Child_Path (Path, Name), False,
                  Root_Device, Root_Device_Available, Kind);
               Stop := Context.Output_Failed;
            end Visit_Child;

            procedure For_Each_Child is new FS.For_Each_Listed_Entry (Visit_Child);
         begin
            if Tracked then
               declare
                  Resolved      : constant String := FS.Real_Path (Path);
                  Identity_Path : constant String :=
                    (if Resolved = "" then Path else Resolved);
               begin
                  Ancestors.Append (Resolved);
                  Ancestor_Identities.Append
                    (FS.Entry_Identity_Of (Identity_Path));
               end;
            end if;
            For_Each_Child (Path, Iteration_Ok);
            if Tracked then
               Ancestors.Delete_Last;
               Ancestor_Identities.Delete_Last;
            end if;
            Ok := Ok and Iteration_Ok;
         end Walk_Children;
      begin
         if Entry_Type = FS.Entry_Error then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path,
               "posix_tools.diagnostic.file.read_failed", "cannot read file");
            return;
         end if;

         --  Device lookup is an extra metadata query on every visited path.
         --  It is needed only when -xdev can use its result.
         if Posix_Tools.Commands.Find_Evaluation.Has_Xdev (Evaluation)
           and then Root_Device_Available
         then
            declare
               Current_Available : Boolean := False;
               Current_Device    : constant Long_Long_Integer :=
                 FS.Device_Id (Path, Current_Available);
            begin
               Crosses_Device := Current_Available and then Current_Device /= Root_Device;
            end;
         end if;

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
         when Ada.IO_Exceptions.Name_Error | Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Device_Error =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.read_failed", "cannot read file");
      end Visit;

      procedure Visit_Operand (Path : String) is
         Available : Boolean := False;
         Device    : Long_Long_Integer := 0;
      begin
         Ancestors.Clear;
         Ancestor_Identities.Clear;
         if Posix_Tools.Commands.Find_Evaluation.Has_Xdev (Evaluation) then
            Device := FS.Device_Id (Path, Available);
         end if;
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
               Posix_Tools.Commands.Helpers.Usage_Error
                 (Context, Result, Unknown_Option,
                  Posix_Tools.Commands.Helpers.Unknown_Option_Subject (Context.Argument (I), "HL"));
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
        (Evaluation, Context, Expression, Environment_Size (Context));

      if Paths.Length = 0 then
         Visit_Operand (".");
      else
         for Path of Paths loop
            Visit_Operand (Path);
         end loop;
      end if;

      Posix_Tools.Commands.Find_Evaluation.Flush_Exec_Batches
        (Evaluation, Context, Ok);
      Posix_Tools.Commands.Find_Evaluation.Flush_Output
        (Evaluation, Context);

      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;

end Posix_Tools.Commands.Find;
