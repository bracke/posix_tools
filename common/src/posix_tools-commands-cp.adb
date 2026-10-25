with Ada.Containers;
with Ada.Containers.Indefinite_Vectors;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Commands.Operation_Reports;
with Posix_Tools.Exit_Status;
with Posix_Tools.File_Operations.Copying;
with Posix_Tools.Host_Adapters.File_System;

package body Posix_Tools.Commands.Cp is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.File_Operations.Operation_Outcome;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   package String_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      type Link_Choice is (Unchosen, Follow_None, Follow_Operands, Follow_All);

      Operands : String_Vectors.Vector;
      Recursive : Boolean := False;
      Preserve_Mode : Boolean := False;
      --  -P, -H, or -L, the last of them given.
      Links : Link_Choice := Unchosen;
      Verbose : Boolean := False;
      Force : Boolean := False;
      Interactive : Boolean := False;
      Ok       : Boolean := True;
      Parsing_Operands : Boolean := False;

      --  Copy Source to Destination, writing a diagnostic for each entry
      --  that could not be copied, and asking about each existing target
      --  under -i.
      procedure Copy (Source, Destination : String);

      procedure Copy (Source, Destination : String) is
         --  Without -H, -L, or -P, a recursive copy keeps the links in the
         --  tree as links, as -P has it; POSIX leaves the choice to the
         --  implementation, and BSD and GNU cp make this one. A copy that
         --  is not recursive follows its operands' links.
         Chosen  : constant Link_Choice :=
           (if Links /= Unchosen then Links elsif Recursive then Follow_None else Follow_All);
         Reports : Posix_Tools.Commands.Operation_Reports.Context_Observer (Context'Access);
         Outcome : Posix_Tools.File_Operations.Operation_Outcome;
      begin
         if Interactive then
            Reports.Prompt := Posix_Tools.Commands.Operation_Reports.Copy_Overwrite;
         end if;

         Posix_Tools.File_Operations.Copying.Copy_Path
           (Source,
            Destination,
            (Recursive      => Recursive,
             Preserve_Mode  => Preserve_Mode,
             Preserve_Links => Chosen in Follow_None | Follow_Operands),
            Reports,
            Outcome,
            (Follow_Source_Link => Chosen = Follow_Operands,
             Remove_Unwritable  => Force));

         if not Posix_Tools.File_Operations.Succeeded (Outcome) then
            Ok := False;
         elsif Verbose and then Outcome = Posix_Tools.File_Operations.Done then
            Context.Put_Line ("'" & Source & "' -> '" & Destination & "'");
         end if;
      end Copy;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if not Parsing_Operands and then Arg = "--" then
               for J in I + 1 .. Context.Argument_Count loop
                  Operands.Append (Context.Argument (J));
               end loop;
               exit;
            elsif not Parsing_Operands and then Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'f' =>
                        Force := True;
                        Interactive := False;
                     when 'i' =>
                        Force := False;
                        Interactive := True;
                     when 'H' =>
                        Links := Follow_Operands;
                     when 'L' =>
                        Links := Follow_All;
                     when 'P' =>
                        Links := Follow_None;
                     when 'p' => Preserve_Mode := True;
                     when 'R' | 'r' => Recursive := True;
                     when 'v' => Verbose := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unknown_Option, "-" & Ch);
                        return;
                  end case;
               end loop;
            else
               Operands.Append (Arg);
               Parsing_Operands := True;
            end if;
         end;
      end loop;

      if Operands.Length < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      declare
         Count  : constant Natural := Natural (Operands.Length);
         Target : constant String := Operands.Element (Count);
      begin
         if FS.Kind (Target) = FS.Directory then
            for I in 1 .. Count - 1 loop
               Copy
                 (Operands.Element (I),
                  FS.Child_Path
                    (Target, Posix_Tools.Commands.File_Helpers.Simple_Name (Operands.Element (I))));
            end loop;
         elsif Count = 2 then
            Copy (Operands.Element (1), Target);
         else
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.not_directory", "not a directory");
            Ok := False;
         end if;
      end;
      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;

end Posix_Tools.Commands.Cp;
