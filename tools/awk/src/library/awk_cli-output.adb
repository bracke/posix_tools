with Awk_CLI.Execution;
with Posix_Tools.Version;
with Terminal_Styles;

package body Awk_CLI.Output is
   package L renames Awk_CLI.Localization;
   package TS renames Terminal_Styles;

   procedure Set_Color (Mode : Awk_CLI.Options.Color_Mode) is
   begin
      case Mode is
         when Awk_CLI.Options.Color_Auto =>
            TS.Set_Color_Policy (TS.Color_Auto);
         when Awk_CLI.Options.Color_Always =>
            TS.Set_Color_Policy (TS.Color_Always);
         when Awk_CLI.Options.Color_Never =>
            TS.Set_Color_Policy (TS.Color_Never);
      end case;
   end Set_Color;

   function Styled
     (Text : String;
      Role : TS.Style_Role;
      Destination_Is_Terminal : Boolean;
      No_Color_Active        : Boolean) return String
   is
      Policy : constant TS.Color_Policy := TS.Current_Color_Policy;
   begin
      case Policy is
         when TS.Color_Never =>
            return Text;

         when TS.Color_Always =>
            return TS.Decorate (Text, Role);

         when TS.Color_Auto =>
            if (not Destination_Is_Terminal) or else No_Color_Active then
               return Text;
            end if;

            TS.Set_Color_Policy (TS.Color_Always);
            declare
               Result : constant String := TS.Decorate (Text, Role);
            begin
               TS.Set_Color_Policy (Policy);
               return Result;
            exception
               when others =>
                  TS.Set_Color_Policy (Policy);
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
