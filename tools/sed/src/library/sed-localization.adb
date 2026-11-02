with Ada.Directories;
with Posix_Tools.Localization;
with Sed.Localization.Defaults;

package body Sed.Localization is

   --  Template with each "{name}" of Args replaced by its value.
   function Fill (Template : String; Args : Parameters) return String;

   --  The names of Args, separated by spaces.
   function Names (Args : Parameters) return String;

   ----------
   -- Fill --
   ----------

   function Fill (Template : String; Args : Parameters) return String is
      Result : U.Unbounded_String;
      I : Natural := Template'First;
   begin
      while I <= Template'Last loop
         declare
            Replaced : Boolean := False;
         begin
            if Template (I) = '{' then
               for Item of Args.Values loop
                  declare
                     Marker : constant String :=
                       "{" & U.To_String (Item.Name) & "}";
                  begin
                     if I + Marker'Length - 1 <= Template'Last
                       and then Template (I .. I + Marker'Length - 1) = Marker
                     then
                        U.Append (Result, Item.Value);
                        I := I + Marker'Length;
                        Replaced := True;
                        exit;
                     end if;
                  end;
               end loop;
            end if;

            if not Replaced then
               U.Append (Result, Template (I));
               I := I + 1;
            end if;
         end;
      end loop;

      return U.To_String (Result);
   end Fill;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Item : in out Catalog;
      Catalog_Path : String;
      Locale : String) is
   begin
      Item.Locale := U.To_Unbounded_String (Locale);
      Item.Path := U.To_Unbounded_String (Catalog_Path);
      Item.Valid :=
        Catalog_Path'Length > 0 and then Ada.Directories.Exists (Catalog_Path);

   exception
      when others =>
         --  A catalogue the host cannot inspect leaves the adapter on its
         --  English defaults rather than failing program start-up.
         Item.Valid := False;
   end Initialize;

   --------------
   -- Is_Valid --
   --------------

   function Is_Valid (Item : Catalog) return Boolean is
   begin
      return Item.Valid;
   end Is_Valid;

   ------------
   -- Locale --
   ------------

   function Locale (Item : Catalog) return String is
   begin
      return U.To_String (Item.Locale);
   end Locale;

   -----------
   -- Names --
   -----------

   function Names (Args : Parameters) return String is
      Result : U.Unbounded_String;
   begin
      for Item of Args.Values loop
         if U.Length (Result) > 0 then
            U.Append (Result, ' ');
         end if;
         U.Append (Result, Item.Name);
      end loop;

      return U.To_String (Result);
   end Names;

   ---------
   -- Set --
   ---------

   procedure Set
     (Args : in out Parameters;
      Name : String;
      Value : String) is
   begin
      Args.Values.Append
        (Parameter'
           (Name => U.To_Unbounded_String (Name),
            Value => U.To_Unbounded_String (Value)));
   end Set;

   ---------
   -- Set --
   ---------

   procedure Set
     (Args : in out Parameters;
      Name : String;
      Value : Line_Count)
   is
      Image : constant String := Line_Count'Image (Value);
   begin
      --  Source locations are machine-oriented: plain decimals.
      Set (Args, Name, Image (Image'First + 1 .. Image'Last));
   end Set;

   ----------
   -- Text --
   ----------

   function Text (Item : Catalog; Key : String) return String is
      Empty : Parameters;
   begin
      return Text (Item, Key, Empty);
   end Text;

   ----------
   -- Text --
   ----------

   function Text
     (Item : Catalog;
      Key : String;
      Args : Parameters) return String
   is
      Default : constant String := Defaults.Template (Key);
      Template : constant String :=
        (if Item.Valid
         then Posix_Tools.Localization.Catalog_Pattern
                (Catalog_Path => U.To_String (Item.Path),
                 Locale => U.To_String (Item.Locale),
                 Key => Key,
                 Names => Names (Args),
                 Default => Default)
         else Default);
   begin
      if Template = "" then
         --  Not a message of the catalogue, which the tests rule out: show
         --  the key rather than nothing.
         return Key;
      end if;

      return Fill (Template, Args);
   end Text;

   -------------
   -- Has_Key --
   -------------

   function Has_Key (Item : Catalog; Key : String) return Boolean is
      pragma Unreferenced (Item);
   begin
      return Defaults.Template (Key) /= "";
   end Has_Key;

end Sed.Localization;
