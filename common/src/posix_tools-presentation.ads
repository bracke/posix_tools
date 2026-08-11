package Posix_Tools.Presentation is
   type Style_Mode is (Automatic, Always, Never);

   procedure Set_Style_Mode (Mode : Style_Mode);

   function Header
     (Text                    : String;
      Destination_Is_Terminal : Boolean) return String;

   function Diagnostic
     (Text                    : String;
      Destination_Is_Terminal : Boolean) return String;
end Posix_Tools.Presentation;
