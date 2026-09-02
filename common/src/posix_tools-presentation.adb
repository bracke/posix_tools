with Terminal_Styles;

package body Posix_Tools.Presentation is
   function Terminal_Role (Role : Style_Role) return Terminal_Styles.Style_Role
     is (case Role is
           when Info    => Terminal_Styles.Role_Info,
           when Success => Terminal_Styles.Role_Success,
           when Error   => Terminal_Styles.Role_Error,
           when Warning => Terminal_Styles.Role_Warning,
           when Muted   => Terminal_Styles.Role_Muted,
           when Header  => Terminal_Styles.Role_Header);

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

   function Decorate
     (Text                    : String;
      Role                    : Style_Role;
      Destination_Is_Terminal : Boolean) return String
   is
   begin
      return Terminal_Styles.Decorate
        (Text, Terminal_Role (Role), Destination_Is_Terminal);
   end Decorate;

   function Header
     (Text                    : String;
      Destination_Is_Terminal : Boolean) return String
   is
   begin
      return Decorate (Text, Header, Destination_Is_Terminal);
   end Header;

   function Diagnostic
     (Text                    : String;
      Destination_Is_Terminal : Boolean) return String
   is
   begin
      return Decorate (Text, Error, Destination_Is_Terminal);
   end Diagnostic;
end Posix_Tools.Presentation;
