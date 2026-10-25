with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Paths;

package body Posix_Tools.Commands.Ln is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First    : Positive := 1;
      Force    : Boolean := False;
      Symbolic : Boolean := False;
      Verbose  : Boolean := False;

      procedure Create_Link
        (Source      : String;
         Target      : String;
         Ok          : in out Boolean;
         Created_One : out Boolean);

      procedure Create_Link
        (Source      : String;
         Target      : String;
         Ok          : in out Boolean;
         Created_One : out Boolean)
      is
         Present : constant Boolean := FS.Exists (Target) or else FS.Is_Link (Target);
         Created : Boolean;

         procedure Fail (Key, Default : String);

         --  Whether Target is, itself, the file the link would lead to, as
         --  the same name or the same file reached through a symbolic link:
         --  then removing it under -f would leave nothing to link to. Another
         --  hard link to the source is not; its name can go. A symbolic
         --  link's text is read from the directory the link goes in.
         function Is_Source_Itself return Boolean;

         procedure Fail (Key, Default : String) is
         begin
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error (Context, Target, Key, Default);
         end Fail;

         function Is_Source_Itself return Boolean is
            Linked : constant String :=
              (if Symbolic and then (Source = "" or else Source (Source'First) /= '/')
               then FS.Child_Path (Posix_Tools.Paths.Dirname (Target), Source)
               else Source);
         begin
            return Present
              and then not FS.Is_Link (Target)
              and then FS.Exists (Linked)
              and then FS.Same_File (Linked, Target)
              and then (FS.Is_Link (Linked)
                        or else (Posix_Tools.Paths.Basename (Linked) = Posix_Tools.Paths.Basename (Target)
                                 and then FS.Real_Path (Posix_Tools.Paths.Dirname (Linked))
                                   = FS.Real_Path (Posix_Tools.Paths.Dirname (Target))));
         end Is_Source_Itself;
      begin
         Created_One := False;

         if Is_Source_Itself then
            Fail ("posix_tools.diagnostic.file.same_file", "source and destination are the same file");
            return;
         elsif not Symbolic and then not FS.Exists (Source) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source, "posix_tools.diagnostic.file.missing", "no such file or directory");
            return;
         elsif not Symbolic and then FS.Kind (Source) = FS.Directory then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source, "posix_tools.diagnostic.file.is_directory", "is a directory");
            return;
         elsif Present and then not Force then
            Fail ("posix_tools.diagnostic.file.exists", "file exists");
            return;
         elsif Present
           and then not Posix_Tools.Commands.File_Helpers.Remove_Non_Directory_Target (Target)
         then
            if not FS.Is_Link (Target) and then FS.Kind (Target) = FS.Directory then
               Fail ("posix_tools.diagnostic.file.is_directory", "is a directory");
            else
               Fail ("posix_tools.diagnostic.file.remove_failed", "cannot remove");
            end if;
            return;
         end if;

         Created :=
           (if Symbolic
            then FS.Create_Link (Source, Target)
            else FS.Create_Hard_Link (Source, Target));
         if Created then
            Created_One := True;
         else
            Fail ("posix_tools.diagnostic.file.link_failed", "cannot create link");
         end if;
      exception
         when others =>
            Created_One := False;
            Fail ("posix_tools.diagnostic.file.link_failed", "cannot create link");
      end Create_Link;

   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (1) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;

         for Ch of Context.Argument (First) (2 .. Context.Argument (First)'Last) loop
            case Ch is
               when 'f' =>
                  Force := True;
               when 's' =>
                  Symbolic := True;
               when 'v' =>
                  Verbose := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Unknown_Option, "-" & Ch);
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if First > Context.Argument_Count or else Context.Argument_Count - First + 1 < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      declare
         Operand_Count : constant Natural := Context.Argument_Count - First + 1;
         Target        : constant String := Context.Argument (Context.Argument_Count);
         Target_Is_Dir : constant Boolean :=
           Posix_Tools.Commands.File_Helpers.Is_Directory (Target);
         Ok            : Boolean := True;
      begin
         if Operand_Count > 2 and then not Target_Is_Dir then
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Target, "posix_tools.diagnostic.file.not_directory", "not a directory");
            Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
            return;
         end if;

         for I in First .. Context.Argument_Count - 1 loop
            declare
               Destination : constant String :=
                 Posix_Tools.Commands.File_Helpers.Target_Path
                   (Context.Argument (I), Target, Target_Is_Dir);
               Created_One : Boolean;
            begin
               Create_Link (Context.Argument (I), Destination, Ok, Created_One);
               if Verbose and then Created_One then
                  Context.Put_Line ("'" & Context.Argument (I) & "' -> '" & Destination & "'");
               end if;
            end;
         end loop;

         Result.Status :=
           (if Ok and then not Context.Output_Failed
            then Posix_Tools.Exit_Status.Success
            else Posix_Tools.Exit_Status.Operational_Failure);
      end;
   exception
      when others =>
         Posix_Tools.Commands.Helpers.Subject_Operational_Error
           (Context, Context.Argument (Context.Argument_Count),
            "posix_tools.diagnostic.file.link_failed", "cannot create link");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
   end Run;
end Posix_Tools.Commands.Ln;
