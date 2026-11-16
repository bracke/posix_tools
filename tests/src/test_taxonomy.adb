with Project_Tools.Text;

package body Test_Taxonomy is
   type Category_Kind is
     (Unit_Category,
      Integration_Category,
      Regression_Category,
      Locale_Category,
      Presentation_Category);

   type String_Access is access constant String;

   Empty        : aliased constant String := "";
   Basic        : aliased constant String := "basic:";
   Streams      : aliased constant String := "streams:";
   Text         : aliased constant String := "text:";
   Regression   : aliased constant String := "regression:";
   Locale       : aliased constant String := "locale:";
   Presentation : aliased constant String := "presentation:";
   Property     : aliased constant String := "property:";
   Command      : aliased constant String := "command:";

   Basic_Group        : aliased constant String := "basic";
   Common_Group       : aliased constant String := "common";
   Streams_Group      : aliased constant String := "streams";
   Text_Group         : aliased constant String := "text";
   Regression_Group   : aliased constant String := "regression";
   Locale_Group       : aliased constant String := "locale";
   Presentation_Group : aliased constant String := "presentation";
   Property_Group     : aliased constant String := "property";
   Command_Group      : aliased constant String := "command";
   Commands_Group     : aliased constant String := "commands";

   type Descriptor is record
      Prefix      : String_Access;
      Group       : String_Access;
      Group_Alias : String_Access;
      Category    : Category_Kind;
   end record;

   Descriptors : constant array (Positive range <>) of Descriptor :=
     [(Basic'Access, Basic_Group'Access, Common_Group'Access, Unit_Category),
      (Streams'Access, Streams_Group'Access, Empty'Access, Unit_Category),
      (Text'Access, Text_Group'Access, Empty'Access, Unit_Category),
      (Regression'Access,
       Regression_Group'Access,
       Empty'Access,
       Regression_Category),
      (Locale'Access, Locale_Group'Access, Empty'Access, Locale_Category),
      (Presentation'Access,
       Presentation_Group'Access,
       Empty'Access,
       Presentation_Category),
      (Property'Access, Property_Group'Access, Empty'Access, Unit_Category),
      (Command'Access,
       Command_Group'Access,
       Commands_Group'Access,
       Integration_Category)];

   function Category_Name (Category : Category_Kind) return String is
     (case Category is
         when Unit_Category         => "unit",
         when Integration_Category  => "integration",
         when Regression_Category   => "regression",
         when Locale_Category       => "locale",
         when Presentation_Category => "presentation");

   function Selects (Prefix, Name : String) return Boolean is
     (Project_Tools.Text.Starts_With (Name, Prefix));

   function Is_AUnit_Name (Name : String) return Boolean is
     (for some Item of Descriptors => Selects (Item.Prefix.all, Name));

   function Is_Aliasable_AUnit_Name (Name : String) return Boolean is
     (for some Item of Descriptors =>
        Item.Category /= Regression_Category
        and then Selects (Item.Prefix.all, Name));

   function Is_Group (Name : String) return Boolean is
     (for some Item of Descriptors =>
        Name = Item.Group.all
        or else
          (Item.Group_Alias.all /= "" and then Name = Item.Group_Alias.all));

   function Is_Category (Name : String) return Boolean is
     (for some Item of Descriptors => Name = Category_Name (Item.Category));

   procedure For_Each_Group_Prefix
     (Name  : String;
      Visit : not null access procedure (Prefix : String)) is
   begin
      for Item of Descriptors loop
         if Name = Item.Group.all
           or else
             (Item.Group_Alias.all /= "" and then Name = Item.Group_Alias.all)
         then
            Visit (Item.Prefix.all);
         end if;
      end loop;
   end For_Each_Group_Prefix;

   procedure For_Each_Category_Prefix
     (Name  : String;
      Visit : not null access procedure (Prefix : String)) is
   begin
      for Item of Descriptors loop
         if Name = Category_Name (Item.Category) then
            Visit (Item.Prefix.all);
         end if;
      end loop;
   end For_Each_Category_Prefix;

   function Canonical_Category_Match_Count
     (Test_Name : String) return Natural
   is
      Seen : array (Category_Kind) of Boolean := [others => False];
      Count : Natural := 0;
   begin
      for Item of Descriptors loop
         if Selects (Item.Prefix.all, Test_Name) then
            Seen (Item.Category) := True;
         end if;
      end loop;
      for Present of Seen loop
         if Present then
            Count := Count + 1;
         end if;
      end loop;
      return Count;
   end Canonical_Category_Match_Count;
end Test_Taxonomy;
