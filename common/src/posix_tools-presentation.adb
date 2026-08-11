with Terminal_Styles;

package body Posix_Tools.Presentation is
   procedure Set_Style_Mode (Mode : Style_Mode) is
   begin
      case Mode is
         when Automatic =>
            Terminal_Styles.Set_Color_Policy (Terminal_Styles.Color_Auto);
         when Always =>
            Terminal_Styles.Set_Color_Policy (Terminal_Styles.Color_Always);
         when Never =>
            Terminal_Styles.Set_Color_Policy (Terminal_Styles.Color_Never);
      end case;
   end Set_Style_Mode;

   function Header
     (Text                    : String;
      Destination_Is_Terminal : Boolean) return String
   is
   begin
      return Terminal_Styles.Decorate
        (Text, Terminal_Styles.Role_Header, Destination_Is_Terminal);
   end Header;

   function Diagnostic
     (Text                    : String;
      Destination_Is_Terminal : Boolean) return String
   is
   begin
      return Terminal_Styles.Decorate
        (Text, Terminal_Styles.Role_Error, Destination_Is_Terminal);
   end Diagnostic;
end Posix_Tools.Presentation;
