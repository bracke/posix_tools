with Posix_Tools.Presentation;

package body Sed.Terminal is
   package P renames Posix_Tools.Presentation;

   --  Map a diagnostic element to a shared presentation role.
   function Role_Of (Part : Element) return P.Style_Role
     is (case Part is
           when Program_Name_Element => P.Muted,
           when Error_Element        => P.Error,
           when Warning_Element      => P.Warning,
           when Information_Element  => P.Info,
           when Location_Element     => P.Muted,
           when Option_Element       => P.Info,
           when Heading_Element      => P.Header);

   -------------
   -- Resolve --
   -------------

   function Resolve
     (Choice : Color_Choice;
      Explicit : Boolean;
      Destination_Is_Terminal : Boolean;
      No_Color : Boolean) return Style_Policy is
   begin
      case Choice is
         when Never =>
            return (Active => False);

         when Always =>
            --  An explicit request outranks NO_COLOR; the same value reached
            --  by default does not.
            return (Active => Explicit or else not No_Color);

         when Automatic =>
            return
              (Active => Destination_Is_Terminal and then not No_Color);
      end case;
   end Resolve;

   -------------
   -- Enabled --
   -------------

   function Enabled (Policy : Style_Policy) return Boolean is
   begin
      return Policy.Active;
   end Enabled;

   -----------
   -- Style --
   -----------

   function Style
     (Policy : Style_Policy;
      Item : String;
      Part : Element) return String is
   begin
      if not Policy.Active or else Item'Length = 0 then
         return Item;
      end if;

      --  The styling backend keeps its emission policy process-wide. This program
      --  has already made the whole decision itself, so the library is told
      --  to emit unconditionally and is asked for the decoration only. The
      --  assignment is idempotent and carries the same value every time.
      P.Set_Style_Mode (P.Always);

      return P.Decorate (Item, Role_Of (Part), Destination_Is_Terminal => True);
   end Style;

end Sed.Terminal;
