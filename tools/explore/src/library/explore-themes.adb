with Ada.Characters.Handling;

package body Explore.Themes is
   function Role_Name (Role : Theme_Role) return String is
      Image  : constant String := Ada.Characters.Handling.To_Lower (Theme_Role'Image (Role));
      Suffix : constant String := "_role";
   begin
      if Image'Length > Suffix'Length and then Image (Image'Last - Suffix'Length + 1 .. Image'Last) = Suffix then
         return Image (Image'First .. Image'Last - Suffix'Length);
      end if;

      return Image;
   end Role_Name;
end Explore.Themes;
