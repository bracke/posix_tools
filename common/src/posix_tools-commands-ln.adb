with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Paths;

package body Posix_Tools.Commands.Ln is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;
   use type FS.Entry_Kind;

   --  Remove what Path names to make way for a link, unless it is a
   --  directory: a link itself, not what it points to, or a file. True when
   --  nothing is left in the way.
   function Remove_Non_Directory_Target
     (Path : String;
      Kind : FS.Entry_Kind) return Boolean;

   function Remove_Non_Directory_Target
     (Path : String;
      Kind : FS.Entry_Kind) return Boolean
   is
   begin
      case Kind is
         when FS.Entry_Missing =>
            return True;
         when FS.Entry_Error =>
            return False;
         when FS.Entry_Link =>
            return FS.Delete_Link (Path);
         when FS.Entry_Directory =>
            return False;
         when FS.Entry_Regular | FS.Entry_Special =>
            return FS.Delete_File (Path);
      end case;
   end Remove_Non_Directory_Target;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First    : Positive;
      Valid    : Boolean;
      Force    : Boolean := False;
      --  -L: a hard link to a symbolic link links to the file it leads
      --  to; -P, the default: to the symbolic link itself.
      Follow   : Boolean := False;
      Symbolic : Boolean := False;
      Verbose  : Boolean := False;
      Output   : Posix_Tools.Commands.Helpers.Output_Buffer;

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
         Target_Kind : constant FS.Entry_Kind := FS.Entry_Kind_Of (Target);
         Present     : constant Boolean := Target_Kind /= FS.Entry_Missing;
         Source_Kind : FS.Entry_Kind := FS.Entry_Missing;
         Followed_Source_Kind : FS.File_Kind := FS.Missing_File;
         --  A hard link made to a symbolic link itself, under -P.
         Link_Itself : Boolean := False;
         Created     : Boolean;

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
            if not Present or else Target_Kind = FS.Entry_Link then
               return False;
            end if;

            declare
               Linked_Kind : constant FS.Entry_Kind :=
                 (if Symbolic then FS.Entry_Kind_Of (Linked) else Source_Kind);
            begin
               return Linked_Kind /= FS.Entry_Missing
                 and then FS.Same_File (Linked, Target)
                 and then (Linked_Kind = FS.Entry_Link
                           or else (Posix_Tools.Paths.Basename (Linked) = Posix_Tools.Paths.Basename (Target)
                                    and then FS.Real_Path (Posix_Tools.Paths.Dirname (Linked))
                                      = FS.Real_Path (Posix_Tools.Paths.Dirname (Target))));
            end;
         end Is_Source_Itself;
      begin
         Created_One := False;

         if Target_Kind = FS.Entry_Error then
            Fail
              ("posix_tools.diagnostic.file.read_failed",
               "cannot read file");
            return;
         end if;

         if not Symbolic then
            Source_Kind := FS.Entry_Kind_Of (Source);
            Link_Itself := not Follow and then Source_Kind = FS.Entry_Link;
            if Follow and then Source_Kind = FS.Entry_Link then
               Followed_Source_Kind := FS.Kind (Source);
            end if;
         end if;

         if Source_Kind = FS.Entry_Error then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source,
               "posix_tools.diagnostic.file.read_failed", "cannot read file");
            return;
         elsif Is_Source_Itself then
            Fail ("posix_tools.diagnostic.file.same_file", "source and destination are the same file");
            return;
         elsif not Symbolic
           and then not Link_Itself
           and then
             (Source_Kind = FS.Entry_Missing
              or else (Source_Kind = FS.Entry_Link and then Followed_Source_Kind = FS.Missing_File))
         then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source, "posix_tools.diagnostic.file.missing", "no such file or directory");
            return;
         elsif not Symbolic
           and then not Link_Itself
           and then
             (Source_Kind = FS.Entry_Directory
              or else (Source_Kind = FS.Entry_Link and then Followed_Source_Kind = FS.Directory))
         then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Source, "posix_tools.diagnostic.file.is_directory", "is a directory");
            return;
         elsif Present and then not Force then
            Fail ("posix_tools.diagnostic.file.exists", "file exists");
            return;
         elsif Present
           and then not Remove_Non_Directory_Target (Target, FS.Entry_Kind_Of (Target))
         then
            if FS.Entry_Kind_Of (Target) = FS.Entry_Directory then
               Fail ("posix_tools.diagnostic.file.is_directory", "is a directory");
            else
               Fail ("posix_tools.diagnostic.file.remove_failed", "cannot remove");
            end if;
            return;
         end if;

         Created :=
           (if Symbolic
            then FS.Create_Link (Source, Target)
            elsif Follow and then Source_Kind = FS.Entry_Link
            then FS.Create_Hard_Link (FS.Real_Path (Source), Target)
            else FS.Create_Hard_Link (Source, Target));
         if Created then
            Created_One := True;
         else
            Fail ("posix_tools.diagnostic.file.link_failed", "cannot create link");
         end if;
      end Create_Link;

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
         case Name is
            when 'f' => Force := True;
            when 'L' => Follow := True;
            when 'P' => Follow := False;
            when 's' => Symbolic := True;
            when others => Verbose := True;
         end case;
         Valid := True;
      end Handle;

      procedure Parse is new Posix_Tools.Commands.Helpers.Parse_Options (Handle);
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      Parse (Context, Result, "fLPsv", "", First, Valid);
      if not Valid then
         return;
      end if;
      if First > Context.Argument_Count or else Context.Argument_Count - First + 1 < 2 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      declare
         Operand_Count : constant Natural := Context.Argument_Count - First + 1;
         Target        : constant String := Context.Argument (Context.Argument_Count);
         Target_Is_Dir : constant Boolean := FS.Kind (Target) = FS.Directory;
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
                 (if Target_Is_Dir
                  then FS.Child_Path (Target, Posix_Tools.Paths.Basename (Context.Argument (I)))
                  else Target);
               Created_One : Boolean;
            begin
               Create_Link (Context.Argument (I), Destination, Ok, Created_One);
               if Verbose and then Created_One then
                  Posix_Tools.Commands.Helpers.Buffered_Put_Line
                    (Output, Context,
                     "'" & Context.Argument (I) & "' -> '" & Destination & "'");
               end if;
            end;
         end loop;

         Posix_Tools.Commands.Helpers.Flush_Output (Output, Context);
         Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
      end;
   end Run;
end Posix_Tools.Commands.Ln;
