with Ada.Strings.Unbounded;
with Posix_Tools.Commands.File_Helpers;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Text_Helpers;
with Posix_Tools.Exit_Status;

package body Posix_Tools.Commands.Tr is
   use Ada.Strings.Unbounded;

   procedure Set_Success
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result) is
   begin
      Result.Status :=
        (if Context.Output_Failed then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Set_Success;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      Delete_Mode : Boolean := False;
      Complement  : Boolean := False;
      Squeeze     : Boolean := False;
      First       : Positive := 1;
      Data        : Unbounded_String;
      Output      : Unbounded_String;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count
        and then Context.Argument (First)'Length > 1
        and then Context.Argument (First) (Context.Argument (First)'First) = '-'
      loop
         if Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         end if;

         for Ch of Context.Argument (First) (Context.Argument (First)'First + 1 .. Context.Argument (First)'Last) loop
            case Ch is
               when 'c' | 'C' => Complement := True;
               when 'd' => Delete_Mode := True;
               when 's' => Squeeze := True;
               when others =>
                  Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "unknown option '-" & Ch & "'");
                  return;
            end case;
         end loop;
         First := First + 1;
      end loop;
      if (Delete_Mode and then Squeeze and then Context.Argument_Count /= First + 1)
        or else (Delete_Mode and then (not Squeeze) and then Context.Argument_Count /= First)
        or else ((not Delete_Mode) and then Squeeze and then Context.Argument_Count not in First | First + 1)
        or else ((not Delete_Mode) and then (not Squeeze) and then Context.Argument_Count /= First + 1)
      then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      Data := To_Unbounded_String
        (Posix_Tools.Commands.File_Helpers.Read_Standard_Input (Context));

      declare
         Locale : constant String := Context.Effective_Locale;
         Set1   : constant String :=
           Posix_Tools.Commands.Text_Helpers.Translation_Set_From_Spec
             (Context.Argument (First), Locale);
         Set2 : constant String :=
           (if (Delete_Mode and then Squeeze) or else ((not Delete_Mode) and then Context.Argument_Count = First + 1)
            then Posix_Tools.Commands.Text_Helpers.Translation_Set_From_Spec
              (Context.Argument (First + 1), Locale)
            else "");
         Squeeze_Set : constant String :=
           (if Squeeze and then Set2 /= "" then Set2 elsif Squeeze then Set1 else "");
         Complement_Order : constant String :=
           Posix_Tools.Commands.Text_Helpers.Locale_Collation_Order (Locale, Set1);
         Previous : Character := Character'Val (0);
         Have_Previous : Boolean := False;

         function In_Set (Set : String; Ch : Character) return Boolean is
         begin
            return (for some Item of Set => Item = Ch);
         end In_Set;

         function Complement_Position (Ch : Character) return Natural is
         begin
            for I in Complement_Order'Range loop
               if Complement_Order (I) = Ch then
                  return I - Complement_Order'First + 1;
               end if;
            end loop;
            return 0;
         end Complement_Position;

         procedure Append_Translated (Ch : Character) is
         begin
            if Squeeze
              and then Have_Previous
              and then Ch = Previous
              and then In_Set (Squeeze_Set, Ch)
            then
               return;
            end if;

            Append (Output, Ch);
            Previous := Ch;
            Have_Previous := True;
         end Append_Translated;
      begin
         for Ch of To_String (Data) loop
            declare
               Index : Natural := 0;
               In_Original_Set : Boolean := False;
               Effective_Match : Boolean;
            begin
               for I in Set1'Range loop
                  if Set1 (I) = Ch then
                     Index := I - Set1'First + 1;
                     In_Original_Set := True;
                  end if;
               end loop;
               if Complement and then not In_Original_Set then
                  Index := Complement_Position (Ch);
               end if;
               Effective_Match := (if Complement then not In_Original_Set else In_Original_Set);
               if Delete_Mode then
                  if not Effective_Match then
                     Append_Translated (Ch);
                  end if;
               elsif Effective_Match and then Set2 /= "" then
                  declare
                     Pos : constant Natural := Natural'Min (Index, Set2'Length);
                  begin
                     Append_Translated (Set2 (Set2'First + Pos - 1));
                  end;
               else
                  Append_Translated (Ch);
               end if;
            end;
         end loop;
      end;
      Context.Put (To_String (Output));
      Set_Success (Context, Result);
      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;

end Posix_Tools.Commands.Tr;
