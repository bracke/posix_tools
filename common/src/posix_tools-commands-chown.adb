with Ada.Strings.Unbounded;
with Posix_Tools.Accounts;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Owner_Groups;

package body Posix_Tools.Commands.Chown is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use type Posix_Tools.Host_Adapters.File_System.Entry_Kind;
   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First     : Positive := 1;
      Recursive : Boolean := False;
      Owner     : Posix_Tools.Accounts.Id := 0;
      Group     : Posix_Tools.Accounts.Id := 0;
      Owner_Set : Boolean := False;
      Group_Set : Boolean := False;
      Ok        : Boolean := True;
      Root_Operand : Ada.Strings.Unbounded.Unbounded_String;

      procedure Apply_One (Path : String);
      procedure Parse_Owner_Group (Spec : String; Valid : out Boolean);

      procedure Apply_Children is new Posix_Tools.Commands.Helpers.For_Each_Directory_Child
        (Action => Apply_One);

      procedure Apply_One (Path : String) is
      begin
         if Recursive and then FS.Entry_Kind_Of (Path) = FS.Entry_Link then
            return;
         end if;

         if Recursive then
            declare
               Listed : Boolean;
            begin
               Apply_Children (Path, Listed);
               Ok := Ok and Listed;
            end;
         end if;
         if not
           (if Recursive
            then FS.Set_Ownership_No_Follow
              (Path,
               (if Owner_Set
                then Posix_Tools.Accounts.Set_To (Owner)
                else Posix_Tools.Accounts.Keep),
               (if Group_Set
                then Posix_Tools.Accounts.Set_To (Group)
                else Posix_Tools.Accounts.Keep),
               Ada.Strings.Unbounded.To_String (Root_Operand),
               Posix_Tools.Commands.Helpers.Relative_Beneath
                 (Ada.Strings.Unbounded.To_String (Root_Operand), Path))
            else FS.Set_Ownership
              (Path,
               (if Owner_Set
                then Posix_Tools.Accounts.Set_To (Owner)
                else Posix_Tools.Accounts.Keep),
               (if Group_Set
                then Posix_Tools.Accounts.Set_To (Group)
                else Posix_Tools.Accounts.Keep)))
         then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path,
               "posix_tools.diagnostic.file.ownership_failed",
               "cannot change ownership");
         end if;
      exception
         when others =>
            --  intentional terminal exception barrier
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path,
               "posix_tools.diagnostic.file.ownership_failed",
               "cannot change ownership");
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
                (Context,
                 Spec (Parsed.Owner_First .. Parsed.Owner_Last), Owner);
            Valid := Valid and then Posix_Tools.Accounts.Can_Set (Owner);
            Owner_Set := Valid;
         elsif not Parsed.Has_Separator then
            Valid := False;
         else
            Valid := True;
         end if;
         if Valid and then Parsed.Has_Group then
            Valid :=
              Posix_Tools.Commands.Helpers.Resolve_Group_Id
                (Context,
                 Spec (Parsed.Group_First .. Parsed.Group_Last), Group);
            Valid := Valid and then Posix_Tools.Accounts.Can_Set (Group);
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
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      declare
         Valid : Boolean;
      begin
         Parse_Owner_Group (Context.Argument (First), Valid);
         if not Valid or else not (Owner_Set or else Group_Set) then
            Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Invalid_Operand, Context.Argument (First));
            return;
         end if;
      end;

      for I in First + 1 .. Context.Argument_Count loop
         Root_Operand := Ada.Strings.Unbounded.To_Unbounded_String
           (Context.Argument (I));
         Apply_One (Context.Argument (I));
      end loop;

      Posix_Tools.Commands.Helpers.Finish (Context, Result, Ok);
   end Run;
end Posix_Tools.Commands.Chown;
