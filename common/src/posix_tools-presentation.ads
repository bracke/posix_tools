package Posix_Tools.Presentation is
   type Style_Mode is (Automatic, Always, Never);

   type Style_Role is (Info, Success, Error, Warning, Muted, Header);

   procedure Set_Style_Mode (Mode : Style_Mode);

   function Decorate
     (Text                    : String;
      Role                    : Style_Role;
      Destination_Is_Terminal : Boolean) return String;

   function Header
     (Text                    : String;
      Destination_Is_Terminal : Boolean) return String;

   function Diagnostic
     (Text                    : String;
      Destination_Is_Terminal : Boolean) return String;
end Posix_Tools.Presentation;
