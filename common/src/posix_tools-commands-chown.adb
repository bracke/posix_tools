with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Owner_Groups;

package body Posix_Tools.Commands.Chown is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First     : Positive := 1;
      Recursive : Boolean := False;
      Owner     : Natural := 0;
      Group     : Natural := 0;
      Owner_Set : Boolean := False;
      Group_Set : Boolean := False;
      Ok        : Boolean := True;

      procedure Apply_One (Path : String);
      procedure Parse_Owner_Group (Spec : String; Valid : out Boolean);

      procedure Apply_Children is new Posix_Tools.Commands.Helpers.For_Each_Directory_Child
        (Action => Apply_One);

      procedure Apply_One (Path : String) is
         Current_User  : Natural;
         Current_Group : Natural;
         Available     : Boolean;
      begin
         if Recursive then
            declare
               Listed : Boolean;
            begin
               Apply_Children (Path, Listed);
               Ok := Ok and Listed;
            end;
         end if;
         FS.File_Ownership (Path, Current_User, Current_Group, Available);
         if not Available then
            Current_User := Owner;
            Current_Group := Group;
         end if;
         if not FS.Set_Ownership
           (Path,
            (if Owner_Set then Owner else Current_User),
            (if Group_Set then Group else Current_Group))
         then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Apply_One;

      procedure Parse_Owner_Group (Spec : String; Valid : out Boolean) is
         Parsed : constant Posix_Tools.Text.Owner_Groups.Parsed_Owner_Group :=
           Posix_Tools.Text.Owner_Groups.Parse_Owner_Group (Spec);
      begin
         Owner_Set := False;
         Group_Set := False;
         if Parsed.Has_Owner then
            Valid :=
              Posix_Tools.Commands.Helpers.Resolve_User_Id
                (Spec (Parsed.Owner_First .. Parsed.Owner_Last), Owner);
            Owner_Set := Valid;
         elsif not Parsed.Has_Separator then
            Valid := False;
         else
            Valid := True;
         end if;
         if Valid and then Parsed.Has_Group then
            Valid :=
              Posix_Tools.Commands.Helpers.Resolve_Group_Id
                (Spec (Parsed.Group_First .. Parsed.Group_Last), Group);
            Group_Set := Valid;
         end if;
      end Parse_Owner_Group;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         elsif Context.Argument (First) = "-R" then
            Recursive := True;
            First := First + 1;
         else
            exit;
         end if;
      end loop;

      if Context.Argument_Count < First + 1 then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      declare
         Valid : Boolean;
      begin
         Parse_Owner_Group (Context.Argument (First), Valid);
         if not Valid or else not (Owner_Set or else Group_Set) then
            Posix_Tools.Commands.Helpers.Usage_Error
              (Context, Result, "invalid operand '" & Context.Argument (First) & "'");
            return;
         end if;
      end;

      for I in First + 1 .. Context.Argument_Count loop
         Apply_One (Context.Argument (I));
      end loop;

      Result.Status :=
        (if Ok and then not Context.Output_Failed
         then Posix_Tools.Exit_Status.Success
         else Posix_Tools.Exit_Status.Operational_Failure);
   end Run;
end Posix_Tools.Commands.Chown;
