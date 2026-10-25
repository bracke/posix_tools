package body Explore.Image_Cache is
   package Unbounded renames Ada.Strings.Unbounded;

   use type Unbounded.Unbounded_String;

   --  Free the least recently shown image, adding to Output what frees it in
   --  the terminal. Nothing when none is held.
   procedure Evict (Self : in out Cache; Output : in out Unbounded.Unbounded_String; In_Tmux : Boolean);

   --  The first slot that holds no image; zero when every one does.
   function First_Free (Self : Cache) return Natural;

   --  The lowest image number no slot uses.
   function Fresh_Id (Self : Cache) return Positive;

   function Bytes (Self : Cache) return Natural is ([for Item of Self.Images => Item.Bytes]'Reduce ("+", 0));

   procedure Clear (Self : in out Cache) is
   begin
      Self.Images := [others => <>];
   end Clear;

   function Count (Self : Cache) return Natural is
     ([for Item of Self.Images => (if Item.Id > 0 then 1 else 0)]'Reduce ("+", 0));

   procedure Evict (Self : in out Cache; Output : in out Unbounded.Unbounded_String; In_Tmux : Boolean) is
      Oldest : Natural := 0;
   begin
      for I in Self.Images'Range loop
         if Self.Images (I).Id > 0
           and then (Oldest = 0 or else Self.Images (I).Used < Self.Images (Oldest).Used)
         then
            Oldest := I;
         end if;
      end loop;

      if Oldest > 0 then
         Unbounded.Append (Output, Explore.Images.Delete (Self.Images (Oldest).Id, In_Tmux));
         Self.Images (Oldest) := (others => <>);
      end if;
   end Evict;

   function First_Free (Self : Cache) return Natural is
   begin
      for I in Self.Images'Range loop
         if Self.Images (I).Id = 0 then
            return I;
         end if;
      end loop;

      return 0;
   end First_Free;

   function Fresh_Id (Self : Cache) return Positive is
   begin
      for Id in 1 .. 255 loop
         if (for all Item of Self.Images => Item.Id /= Id) then
            return Id;
         end if;
      end loop;

      return 1;
   end Fresh_Id;

   function Show
     (Self    : in out Cache;
      Key     : Image_Key;
      Format  : Explore.Images.Image_Format;
      Data    : Unbounded.Unbounded_String;
      Columns : Positive;
      Rows    : Positive;
      In_Tmux : Boolean;
      Id      : out Positive) return String
   is
      Size : constant Natural := Unbounded.Length (Data);
      Slot : Natural := 0;
   begin
      Self.Clock := Self.Clock + 1;

      for I in Self.Images'Range loop
         if Self.Images (I).Id > 0 and then Self.Images (I).Key = Key then
            Slot := I;
         end if;
      end loop;

      if Slot > 0 then
         --  Already there: placed afresh only when the pane changed size.
         declare
            Held    : Cached_Image renames Self.Images (Slot);
            Resized : constant Boolean := Held.Columns /= Columns or else Held.Rows /= Rows;
         begin
            Held.Columns := Columns;
            Held.Rows := Rows;
            Held.Used := Self.Clock;
            Id := Held.Id;
            return (if Resized then Explore.Images.Place (Id, Columns, Rows, In_Tmux) else "");
         end;
      end if;

      declare
         Freed : Unbounded.Unbounded_String;
      begin
         --  Room by count, then by bytes, freeing the least recently shown.
         Slot := First_Free (Self);

         if Slot = 0 then
            Evict (Self, Freed, In_Tmux);
            Slot := First_Free (Self);
         end if;

         while Count (Self) > 0 and then Size + Bytes (Self) > Self.Byte_Limit loop
            Evict (Self, Freed, In_Tmux);
         end loop;

         Id := Fresh_Id (Self);
         Self.Images (Slot) :=
           (Key => Key, Id => Id, Columns => Columns, Rows => Rows, Bytes => Size, Used => Self.Clock);
         return Unbounded.To_String (Freed)
           & Explore.Images.Transmit (Id, Format, Unbounded.To_String (Data), Columns, Rows, In_Tmux);
      end;
   end Show;
end Explore.Image_Cache;
