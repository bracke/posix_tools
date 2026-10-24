package body Explore.Keymap is
   package Input renames Explore.Input;
   package Listing renames Posix_Tools.File_Operations.Listing;

   use type Input.Event_Kind;
   use type Input.Key_Kind;

   function Control (Item : Input.Event; Letter : Wide_Wide_Character) return Boolean is
     (Item.Kind = Input.Key_Event
      and then Item.Key = Input.Character_Key
      and then Item.Code = Letter
      and then Item.Mods.Control
      and then not Item.Mods.Alt);

   --  The meaning of a key with no prefix pending.
   function Plain (Self : in out State; Item : Input.Event) return Command;

   --  The meaning of the key after the sort prefix.
   function Sort_Command (Code : Wide_Wide_Character) return Command;

   function Pending (Self : State) return String is
     (case Self.Waiting is
        when No_Prefix => "",
        when Go_Prefix => "g",
        when Sort_Prefix => ",");

   function Plain (Self : in out State; Item : Input.Event) return Command is
   begin
      if Item.Kind /= Input.Key_Event then
         return (others => <>);
      end if;

      case Item.Key is
         when Input.Up =>
            return (Kind => Move_Up, others => <>);
         when Input.Down =>
            return (Kind => Move_Down, others => <>);
         when Input.Left =>
            return (Kind => Leave_Directory, others => <>);
         when Input.Right | Input.Enter =>
            return (Kind => Enter_Directory, others => <>);
         when Input.Home =>
            return (Kind => Move_Top, others => <>);
         when Input.End_Key =>
            return (Kind => Move_Bottom, others => <>);
         when Input.Page_Up =>
            return (Kind => Page_Up, others => <>);
         when Input.Page_Down =>
            return (Kind => Page_Down, others => <>);
         when Input.Escape =>
            return (Kind => Clear_Filter, others => <>);
         when Input.Character_Key =>
            null;
         when Input.Tab | Input.Backspace | Input.Insert | Input.Delete | Input.Function_Key =>
            return (others => <>);
      end case;

      if Control (Item, 'd') then
         return (Kind => Half_Page_Down, others => <>);
      elsif Control (Item, 'u') then
         return (Kind => Half_Page_Up, others => <>);
      elsif Control (Item, 'f') then
         return (Kind => Page_Down, others => <>);
      elsif Control (Item, 'b') then
         return (Kind => Page_Up, others => <>);
      elsif Control (Item, 'c') then
         return (Kind => Cancel_Job, others => <>);
      elsif Item.Mods.Control or else Item.Mods.Alt then
         return (others => <>);
      end if;

      case Item.Code is
         when 'q' =>
            return (Kind => Quit, others => <>);
         when 'j' =>
            return (Kind => Move_Down, others => <>);
         when 'k' =>
            return (Kind => Move_Up, others => <>);
         when 'h' =>
            return (Kind => Leave_Directory, others => <>);
         when 'l' =>
            return (Kind => Enter_Directory, others => <>);
         when 'G' =>
            return (Kind => Move_Bottom, others => <>);
         when '.' =>
            return (Kind => Toggle_Hidden, others => <>);
         when 'f' =>
            return (Kind => Start_Filter, others => <>);
         when '~' =>
            return (Kind => Go_Home, others => <>);
         when ' ' =>
            return (Kind => Toggle_Mark, others => <>);
         when 'y' =>
            return (Kind => Yank, others => <>);
         when 'x' =>
            return (Kind => Cut, others => <>);
         when 'p' =>
            return (Kind => Paste, others => <>);
         when '-' =>
            return (Kind => Paste_Links, others => <>);
         when 'd' =>
            return (Kind => Delete_Entries, others => <>);
         when 'r' =>
            return (Kind => Rename_Entry, others => <>);
         when 'a' =>
            return (Kind => Create_Entry, others => <>);
         when 'm' =>
            return (Kind => Change_Mode, others => <>);
         when 'w' =>
            return (Kind => Show_Jobs, others => <>);
         when 'g' =>
            Self.Waiting := Go_Prefix;
         when ',' =>
            Self.Waiting := Sort_Prefix;
         when others =>
            null;
      end case;

      return (others => <>);
   end Plain;

   function Sort_Command (Code : Wide_Wide_Character) return Command is
      Descending : constant Boolean := Code in 'A' .. 'Z';
   begin
      case Code is
         when 'n' | 'N' =>
            return (Sort_Entries, Listing.By_Natural_Name, Descending);
         when 'a' | 'A' =>
            return (Sort_Entries, Listing.By_Name, Descending);
         when 'e' | 'E' =>
            return (Sort_Entries, Listing.By_Extension, Descending);
         when 's' | 'S' =>
            return (Sort_Entries, Listing.By_Size, Descending);
         when 'm' | 'M' =>
            return (Sort_Entries, Listing.By_Modified, Descending);
         when 't' | 'T' =>
            return (Sort_Entries, Listing.By_Kind, Descending);
         when others =>
            return (others => <>);
      end case;
   end Sort_Command;

   procedure Translate (Self : in out State; Item : Input.Event; Result : out Command) is
      Was : constant Prefix := Self.Waiting;
   begin
      Result := (others => <>);

      if Item.Kind /= Input.Key_Event then
         return;
      end if;

      Self.Waiting := No_Prefix;

      case Was is
         when No_Prefix =>
            Result := Plain (Self, Item);
         when Go_Prefix =>
            if Input.Is_Character (Item, 'g') then
               Result := (Kind => Move_Top, others => <>);
            end if;
         when Sort_Prefix =>
            if Item.Key = Input.Character_Key and then not Item.Mods.Control and then not Item.Mods.Alt then
               Result := Sort_Command (Item.Code);
            end if;
      end case;
   end Translate;
end Explore.Keymap;
