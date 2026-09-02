with Awk_CLI.Execution;
with Posix_Tools.Presentation;
with Posix_Tools.Version;

package body Awk_CLI.Output is
   package L renames Awk_CLI.Localization;
   package P renames Posix_Tools.Presentation;

   Current_Mode : P.Style_Mode := P.Automatic;

   procedure Set_Color (Mode : Awk_CLI.Options.Color_Mode) is
   begin
      case Mode is
         when Awk_CLI.Options.Color_Auto =>
            Current_Mode := P.Automatic;
         when Awk_CLI.Options.Color_Always =>
            Current_Mode := P.Always;
         when Awk_CLI.Options.Color_Never =>
            Current_Mode := P.Never;
      end case;

      P.Set_Style_Mode (Current_Mode);
   end Set_Color;

   function Styled
     (Text : String;
      Role : P.Style_Role;
      Destination_Is_Terminal : Boolean;
      No_Color_Active        : Boolean) return String
   is
   begin
      case Current_Mode is
         when P.Never =>
            return Text;

         when P.Always =>
            return P.Decorate (Text, Role, Destination_Is_Terminal => True);

         when P.Automatic =>
            if (not Destination_Is_Terminal) or else No_Color_Active then
               return Text;
            end if;

            P.Set_Style_Mode (P.Always);
            declare
               Result : constant String :=
                 P.Decorate (Text, Role, Destination_Is_Terminal => True);
            begin
               P.Set_Style_Mode (Current_Mode);
               return Result;
            exception
               when others =>
                  P.Set_Style_Mode (Current_Mode);
                  raise;
            end;
      end case;
   end Styled;

   function Help
     (Catalog : L.Catalog;
      Destination_Is_Terminal : Boolean;
      No_Color_Active        : Boolean := False) return String is separate;

   function Version (Catalog : L.Catalog) return String is
      LF : constant String := [1 => ASCII.LF];
   begin
      return
        L.Text (Catalog, "awk.version.program",
                "version", Posix_Tools.Version.Version_String) & LF &
        L.Text (Catalog, "awk.version.interpreter",
                "version", Awk_CLI.Execution.Interpreter_Version) & LF &
        L.Text (Catalog, "awk.version.license") & LF;
   end Version;

   function Diagnostic_Text
     (Catalog : L.Catalog;
      Item    : Awk_CLI.Diagnostics.Diagnostic;
      Destination_Is_Terminal : Boolean;
      No_Color_Active        : Boolean := False) return String is separate;

end Awk_CLI.Output;
