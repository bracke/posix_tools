with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.UTF_Encoding.Wide_Wide_Strings;

package body Explore.Keymap is
   package Input renames Explore.Input;
   package Listing renames Posix_Tools.File_Operations.Listing;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Input.Event_Kind;
   use type Input.Key_Kind;

   --  The default bindings of single keys, one line each. Keys that start a
   --  default prefix -- b, c, g, ', and the comma -- are in Prefix_Of, and the
   --  digits, which switch to the tab they number, in Plain.

   --  A character typed on its own.
   function Character_Action (Code : Wide_Wide_Character) return Action is
     (case Code is
        when 'q' => Quit,
        when 'j' => Move_Down,
        when 'k' => Move_Up,
        when 'h' => Leave_Directory,
        when 'l' => Enter_Directory,
        when 'G' => Move_Bottom,
        when '.' => Toggle_Hidden,
        when 'f' => Start_Filter,
        when '~' => Go_Home,
        when ' ' => Toggle_Mark,
        when 'y' => Yank,
        when 'x' => Cut,
        when 'p' => Paste,
        when '-' => Paste_Links,
        when 'd' => Delete_Entries,
        when 'r' => Rename_Entry,
        when 'a' => Create_Entry,
        when 'm' => Change_Mode,
        when 'w' => Show_Jobs,
        when 't' => New_Tab,
        when 'T' => Close_Tab,
        when '[' => Previous_Tab,
        when ']' => Next_Tab,
        when 'H' => Go_Back,
        when 'L' => Go_Forward,
        when ':' => Jump_To_Path,
        when 'v' => Visual_Mode,
        when '/' => Search_Names,
        when '?' => Search_Contents,
        when '!' => Shell_Command,
        when 'S' => Spawn_Shell,
        when 'o' => Open_Entries,
        when others => No_Action);

   --  A letter typed with Control, and not Alt.
   function Control_Action (Code : Wide_Wide_Character) return Action is
     (case Code is
        when 'd' => Half_Page_Down,
        when 'u' => Half_Page_Up,
        when 'f' => Page_Down,
        when 'b' => Page_Up,
        when 'c' => Cancel_Job,
        when others => No_Action);

   --  A named key, with whatever modifiers.
   function Named_Key_Action (Key : Input.Key_Kind) return Action is
     (case Key is
        when Input.Up => Move_Up,
        when Input.Down => Move_Down,
        when Input.Left => Leave_Directory,
        when Input.Right | Input.Enter => Enter_Directory,
        when Input.Home => Move_Top,
        when Input.End_Key => Move_Bottom,
        when Input.Page_Up => Page_Up,
        when Input.Page_Down => Page_Down,
        when Input.Escape => Clear_Filter,
        when Input.Character_Key | Input.Tab | Input.Backspace | Input.Insert | Input.Delete
           | Input.Function_Key => No_Action);

   --  Whether Item is the key Spec describes.
   function Matches (Spec : Key_Spec; Item : Input.Event) return Boolean;

   --  One key of a binding, as Parse_Keys reads it.
   procedure Parse_Key (Text : String; Spec : out Key_Spec; Ok : out Boolean);

   --  The meaning of a key with no prefix pending; none for a key that
   --  starts a default prefix.
   function Plain (Item : Input.Event) return Command;

   --  The default prefix Item starts, or No_Prefix.
   function Prefix_Of (Item : Input.Event) return Prefix;

   --  The meaning of a key under a default prefix.
   function Prefixed (Was : Prefix; Item : Input.Event) return Command;

   --  The meaning of the key after the sort prefix.
   function Sort_Command (Code : Wide_Wide_Character) return Command;

   procedure Bind (Self : in out State; Keys, Action_Name : String; Ok : out Boolean) is
      Item : Binding;
   begin
      Parse_Keys (Keys, Item.First, Item.Second, Item.Has_Second, Ok);

      if Ok then
         Parse_Command (Action_Name, Item.Result, Ok);
      end if;

      if Ok then
         declare
            Space : constant Natural := Ada.Strings.Fixed.Index (Keys, " ");
         begin
            Item.Shown := Unbounded.To_Unbounded_String (if Space = 0 then Keys else Keys (Keys'First .. Space - 1));
         end;

         --  A later binding of the same keys replaces an earlier one.
         for I in reverse 1 .. Self.Bindings.Last_Index loop
            declare
               Old : constant Binding := Self.Bindings (I);
            begin
               if Old.First = Item.First and then Old.Has_Second = Item.Has_Second
                 and then (not Item.Has_Second or else Old.Second = Item.Second)
               then
                  Self.Bindings.Delete (I);
               end if;
            end;
         end loop;

         Self.Bindings.Append (Item);
      end if;
   end Bind;

   function Matches (Spec : Key_Spec; Item : Input.Event) return Boolean is
   begin
      if Item.Kind /= Input.Key_Event or else Item.Key /= Spec.Key
        or else Item.Mods.Control /= Spec.Control or else Item.Mods.Alt /= Spec.Alt
      then
         return False;
      end if;

      --  A character carries its own Shift: see Key_Spec.
      case Item.Key is
         when Input.Character_Key =>
            return Item.Code = Spec.Code;
         when Input.Function_Key =>
            return Item.Number = Spec.Number and then Item.Mods.Shift = Spec.Shift;
         when others =>
            return Item.Mods.Shift = Spec.Shift;
      end case;
   end Matches;

   procedure Parse_Command (Text : String; Result : out Command; Ok : out Boolean) is
      Colon    : constant Natural := Ada.Strings.Fixed.Index (Text, ":");
      Name     : constant String := (if Colon = 0 then Text else Text (Text'First .. Colon - 1));
      Argument : constant String := (if Colon = 0 then "" else Text (Colon + 1 .. Text'Last));
      Kind     : Action;
   begin
      Result := (others => <>);
      Ok := False;

      if Name = "none" then
         Ok := Colon = 0;
         return;
      end if;

      --  Only the lower-case names are accepted, with words joined by "_".
      if Name'Length = 0 or else Name /= Ada.Characters.Handling.To_Lower (Name) or else Name = "no_action" then
         return;
      end if;

      begin
         Kind := Action'Value (Name);
      exception
         when Constraint_Error =>
            return;
      end;

      Result.Kind := Kind;

      case Kind is
         when Sort_Entries =>
            declare
               Suffix : constant String := "_descending";
               Down   : constant Boolean :=
                 Argument'Length > Suffix'Length
                 and then Argument (Argument'Last - Suffix'Length + 1 .. Argument'Last) = Suffix;
            begin
               Result.Descending := Down;
               Parse_Sort_Key
                 ((if Down then Argument (Argument'First .. Argument'Last - Suffix'Length) else Argument),
                  Result.Key, Ok);
            end;
         when Switch_Tab =>
            Ok := Argument'Length = 1 and then Argument (Argument'First) in '1' .. '9';

            if Ok then
               Result.Number := Character'Pos (Argument (Argument'First)) - Character'Pos ('0');
            end if;
         when Set_Bookmark | Go_Bookmark =>
            Ok := Argument'Length = 1 and then Argument (Argument'First) in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9';

            if Ok then
               Result.Letter := Argument (Argument'First);
            end if;
         when others =>
            Ok := Colon = 0;
      end case;
   end Parse_Command;

   procedure Parse_Key (Text : String; Spec : out Key_Spec; Ok : out Boolean) is
      Rest : Natural := Text'First;
   begin
      Spec := (others => <>);
      Ok := False;

      loop
         if Text'Last - Rest >= 5 and then Ada.Characters.Handling.To_Lower (Text (Rest .. Rest + 4)) = "ctrl-" then
            Spec.Control := True;
            Rest := Rest + 5;
         elsif Text'Last - Rest >= 4 and then Ada.Characters.Handling.To_Lower (Text (Rest .. Rest + 3)) = "alt-" then
            Spec.Alt := True;
            Rest := Rest + 4;
         elsif Text'Last - Rest >= 6 and then Ada.Characters.Handling.To_Lower (Text (Rest .. Rest + 5)) = "shift-"
         then
            Spec.Shift := True;
            Rest := Rest + 6;
         else
            exit;
         end if;
      end loop;

      if Rest > Text'Last then
         return;
      end if;

      declare
         Name  : constant String := Text (Rest .. Text'Last);
         Lower : constant String := Ada.Characters.Handling.To_Lower (Name);

         procedure Named (Kind : Input.Key_Kind);

         procedure Named (Kind : Input.Key_Kind) is
         begin
            Spec.Key := Kind;
            Ok := True;
         end Named;
      begin
         if Lower = "space" then
            Spec.Code := ' ';
            Ok := True;
         elsif Lower = "enter" then
            Named (Input.Enter);
         elsif Lower = "tab" then
            Named (Input.Tab);
         elsif Lower = "backspace" then
            Named (Input.Backspace);
         elsif Lower = "esc" then
            Named (Input.Escape);
         elsif Lower = "up" then
            Named (Input.Up);
         elsif Lower = "down" then
            Named (Input.Down);
         elsif Lower = "left" then
            Named (Input.Left);
         elsif Lower = "right" then
            Named (Input.Right);
         elsif Lower = "home" then
            Named (Input.Home);
         elsif Lower = "end" then
            Named (Input.End_Key);
         elsif Lower = "pageup" then
            Named (Input.Page_Up);
         elsif Lower = "pagedown" then
            Named (Input.Page_Down);
         elsif Lower = "insert" then
            Named (Input.Insert);
         elsif Lower = "delete" then
            Named (Input.Delete);
         elsif Lower'Length in 2 .. 3 and then Lower (Lower'First) = 'f'
           and then (for all C of Lower (Lower'First + 1 .. Lower'Last) => C in '0' .. '9')
           and then Natural'Value (Lower (Lower'First + 1 .. Lower'Last)) in 1 .. 12
         then
            Named (Input.Function_Key);
            Spec.Number := Natural'Value (Lower (Lower'First + 1 .. Lower'Last));
         else
            declare
               Decoded : constant Wide_Wide_String := Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Decode (Name);
            begin
               if Decoded'Length = 1 and then Wide_Wide_Character'Pos (Decoded (Decoded'First)) > 32 then
                  --  A control key comes as its unshifted letter.
                  Spec.Code :=
                    (if Spec.Control and then Decoded (Decoded'First) in 'A' .. 'Z'
                     then Wide_Wide_Character'Val (Wide_Wide_Character'Pos (Decoded (Decoded'First)) + 32)
                     else Decoded (Decoded'First));
                  Ok := True;
               end if;
            exception
               when Ada.Strings.UTF_Encoding.Encoding_Error =>
                  null;
            end;
         end if;

         --  Shift is written into a character itself, as "G", never before it.
         if Spec.Shift and then Spec.Key = Input.Character_Key then
            Ok := False;
         end if;
      end;
   end Parse_Key;

   procedure Parse_Keys (Text : String; First, Second : out Key_Spec; Has_Second : out Boolean; Ok : out Boolean) is
      Space : constant Natural := Ada.Strings.Fixed.Index (Text, " ");
   begin
      Second := (others => <>);
      Has_Second := Space > 0;

      if Space = 0 then
         Parse_Key (Text, First, Ok);
      else
         Parse_Key (Text (Text'First .. Space - 1), First, Ok);

         if Ok then
            Parse_Key (Text (Space + 1 .. Text'Last), Second, Ok);
         end if;
      end if;
   end Parse_Keys;

   procedure Parse_Sort_Key (Text : String; Key : out Listing.Sort_Key; Ok : out Boolean) is
   begin
      Ok := True;

      if Text = "natural" then
         Key := Listing.By_Natural_Name;
      elsif Text = "name" then
         Key := Listing.By_Name;
      elsif Text = "extension" then
         Key := Listing.By_Extension;
      elsif Text = "size" then
         Key := Listing.By_Size;
      elsif Text = "modified" then
         Key := Listing.By_Modified;
      elsif Text = "kind" then
         Key := Listing.By_Kind;
      else
         Key := Listing.By_Natural_Name;
         Ok := False;
      end if;
   end Parse_Sort_Key;

   function Pending (Self : State) return String is
     (case Self.Waiting is
        when No_Prefix => "",
        when Go_Prefix => "g",
        when Sort_Prefix => ",",
        when Bookmark_Prefix => "b",
        when Jump_Prefix => "'",
        when Copy_Prefix => "c",
        when Bound_Prefix => Unbounded.To_String (Self.Held_Shown));

   function Plain (Item : Input.Event) return Command is
   begin
      if Item.Kind /= Input.Key_Event then
         return (others => <>);
      elsif Item.Key /= Input.Character_Key then
         --  A named key means the same whatever modifiers are held with it.
         return (Kind => Named_Key_Action (Item.Key), others => <>);
      elsif Item.Mods.Control or else Item.Mods.Alt then
         return (Kind => (if Item.Mods.Alt then No_Action else Control_Action (Item.Code)), others => <>);
      elsif Item.Code in '1' .. '9' then
         return (Kind => Switch_Tab, Number => Wide_Wide_Character'Pos (Item.Code) - Character'Pos ('0'), others => <>);
      else
         return (Kind => Character_Action (Item.Code), others => <>);
      end if;
   end Plain;

   function Prefix_Of (Item : Input.Event) return Prefix is
   begin
      if Item.Kind /= Input.Key_Event or else Item.Key /= Input.Character_Key
        or else Item.Mods.Control or else Item.Mods.Alt
      then
         return No_Prefix;
      end if;

      case Item.Code is
         when 'c' =>
            return Copy_Prefix;
         when 'b' =>
            return Bookmark_Prefix;
         when ''' =>
            return Jump_Prefix;
         when 'g' =>
            return Go_Prefix;
         when ',' =>
            return Sort_Prefix;
         when others =>
            return No_Prefix;
      end case;
   end Prefix_Of;

   function Prefixed (Was : Prefix; Item : Input.Event) return Command is
   begin
      case Was is
         when No_Prefix | Bound_Prefix =>
            null;
         when Go_Prefix =>
            if Input.Is_Character (Item, 'g') then
               return (Kind => Move_Top, others => <>);
            end if;
         when Sort_Prefix =>
            if Item.Key = Input.Character_Key and then not Item.Mods.Control and then not Item.Mods.Alt then
               return Sort_Command (Item.Code);
            end if;
         when Copy_Prefix =>
            if Input.Is_Character (Item, 'c') then
               return (Kind => Copy_Path, others => <>);
            elsif Input.Is_Character (Item, 'd') then
               return (Kind => Copy_Directory, others => <>);
            elsif Input.Is_Character (Item, 'f') then
               return (Kind => Copy_Name, others => <>);
            end if;
         when Bookmark_Prefix | Jump_Prefix =>
            --  A bookmark is named by a letter or a digit.
            if Item.Key = Input.Character_Key and then not Item.Mods.Control and then not Item.Mods.Alt
              and then Item.Code in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9'
            then
               return
                 (Kind   => (if Was = Bookmark_Prefix then Set_Bookmark else Go_Bookmark),
                  Letter => Character'Val (Wide_Wide_Character'Pos (Item.Code)),
                  others => <>);
            end if;
      end case;

      return (others => <>);
   end Prefixed;

   function Sort_Command (Code : Wide_Wide_Character) return Command is
      Descending : constant Boolean := Code in 'A' .. 'Z';
   begin
      case Code is
         when 'n' | 'N' =>
            return (Kind => Sort_Entries, Key => Listing.By_Natural_Name, Descending => Descending, others => <>);
         when 'a' | 'A' =>
            return (Kind => Sort_Entries, Key => Listing.By_Name, Descending => Descending, others => <>);
         when 'e' | 'E' =>
            return (Kind => Sort_Entries, Key => Listing.By_Extension, Descending => Descending, others => <>);
         when 's' | 'S' =>
            return (Kind => Sort_Entries, Key => Listing.By_Size, Descending => Descending, others => <>);
         when 'm' | 'M' =>
            return (Kind => Sort_Entries, Key => Listing.By_Modified, Descending => Descending, others => <>);
         when 't' | 'T' =>
            return (Kind => Sort_Entries, Key => Listing.By_Kind, Descending => Descending, others => <>);
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
            for Bound of Self.Bindings loop
               if not Bound.Has_Second and then Matches (Bound.First, Item) then
                  Result := Bound.Result;
                  return;
               end if;
            end loop;

            for Bound of Self.Bindings loop
               if Bound.Has_Second and then Matches (Bound.First, Item) then
                  Self.Waiting := Bound_Prefix;
                  Self.Held := Item;
                  Self.Held_Shown := Bound.Shown;
                  return;
               end if;
            end loop;

            Result := Plain (Item);
            Self.Waiting := Prefix_Of (Item);
         when Bound_Prefix =>
            for Bound of Self.Bindings loop
               if Bound.Has_Second and then Matches (Bound.First, Self.Held) and then Matches (Bound.Second, Item) then
                  Result := Bound.Result;
                  return;
               end if;
            end loop;

            --  A sequence not bound there means what it means by default,
            --  when the first key is a default prefix.
            declare
               Default : constant Prefix := Prefix_Of (Self.Held);
            begin
               if Default /= No_Prefix then
                  Result := Prefixed (Default, Item);
               end if;
            end;
         when others =>
            Result := Prefixed (Was, Item);
      end case;
   end Translate;
end Explore.Keymap;
