with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.Host;

package body Posix_Tools.Commands.Id is
   use Ada.Strings.Unbounded;

   package Host renames Posix_Tools.Host_Adapters.Host;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Show_User       : Boolean := False;
      Show_Group      : Boolean := False;
      Show_All_Groups : Boolean := False;
      Show_Name       : Boolean := False;
      User_Id         : Natural := 0;
      Group_Id        : Natural := 0;
      Groups          : Host.Group_Id_List (1 .. 256);
      Group_Last      : Natural := 0;

      procedure Append_Group (Id : Natural);
      function Group_List (Named : Boolean; Decorated : Boolean) return String;

      procedure Append_Group (Id : Natural) is
      begin
         for Index in 1 .. Group_Last loop
            if Groups (Index) = Id then
               return;
            end if;
         end loop;
         if Group_Last < Groups'Length then
            Group_Last := Group_Last + 1;
            Groups (Group_Last) := Id;
         end if;
      end Append_Group;

      function Group_List (Named : Boolean; Decorated : Boolean) return String is
         Output : Unbounded_String;
      begin
         for Index in 1 .. Group_Last loop
            if Index > 1 then
               Append (Output, (if Decorated then "," else " "));
            end if;
            if Decorated then
               Append (Output, Posix_Tools.Commands.Helpers.Decorated_Group_Id_Text (Context, Groups (Index)));
            elsif Named then
               Append (Output, Posix_Tools.Commands.Helpers.Group_Id_Text (Context, Groups (Index), Show_Name));
            else
               Append (Output, Posix_Tools.Commands.Helpers.Group_Id_Text (Context, Groups (Index), False));
            end if;
         end loop;
         return To_String (Output);
      end Group_List;

   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      for I in 1 .. Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (I);
         begin
            if Arg = "--" then
               if I < Context.Argument_Count then
                  Posix_Tools.Commands.Helpers.Usage_Error
                    (Context, Result, "extra operand '" & Context.Argument (I + 1) & "'");
                  return;
               end if;
            elsif Arg'Length > 1 and then Arg (Arg'First) = '-' then
               for Ch of Arg (Arg'First + 1 .. Arg'Last) loop
                  case Ch is
                     when 'u' =>
                        Show_User := True;
                     when 'g' =>
                        Show_Group := True;
                     when 'G' =>
                        Show_All_Groups := True;
                     when 'n' =>
                        Show_Name := True;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                        return;
                  end case;
               end loop;
            else
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "extra operand '" & Arg & "'");
               return;
            end if;
         end;
      end loop;

      if not Context.Current_User_Id (User_Id) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      if not Context.Current_Group_Id (Group_Id) then
         Posix_Tools.Commands.Helpers.Operational_Error
           (Context, "posix_tools.diagnostic.unsupported", "unsupported platform capability");
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
         return;
      end if;

      Append_Group (Group_Id);
      declare
         Raw_Groups : Host.Group_Id_List (1 .. 256);
         Raw_Last   : Natural := 0;
      begin
         if Context.Current_Supplementary_Group_Ids (Raw_Groups, Raw_Last) then
            for Index in 1 .. Raw_Last loop
               Append_Group (Raw_Groups (Index));
            end loop;
         end if;
      end;

      if Show_User then
         Context.Put_Line (Posix_Tools.Commands.Helpers.User_Id_Text (Context, User_Id, Show_Name));
      elsif Show_Group then
         Context.Put_Line (Posix_Tools.Commands.Helpers.Group_Id_Text (Context, Group_Id, Show_Name));
      elsif Show_All_Groups then
         Context.Put_Line (Group_List (Show_Name, False));
      else
         Context.Put_Line
           ("uid=" & Posix_Tools.Commands.Helpers.Decorated_User_Id_Text (Context, User_Id)
            & " gid=" & Posix_Tools.Commands.Helpers.Decorated_Group_Id_Text (Context, Group_Id)
            & " groups=" & Group_List (False, True));
      end if;
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Id;
