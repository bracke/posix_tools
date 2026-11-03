with Ada.Text_IO;
with Ada.Strings.Unbounded;
with AUnit.Simple_Test_Cases;
with AUnit;

package body Suite_Filters is
   use Ada.Strings.Unbounded;

   type Alias_Entry is record
      Alias_Name     : Unbounded_String;
      Canonical_Name : Unbounded_String;
   end record;

   type Alias_List is array (Positive range <>) of Alias_Entry;

   function "+" (Text : String) return Unbounded_String
     renames To_Unbounded_String;

   --  Regression identifiers are tags on canonical tests. Keeping the tag
   --  beside only the canonical name avoids a second procedure-access table
   --  and ensures every selected scenario executes once.
   Regression_Aliases : constant Alias_List :=
     [(+"regression:REG-CAT-0001 binary fixture", +"streams:file fixture"),
      (+"regression:REG-TAIL-0007 temporary storage long path",
       +"basic:temporary storage long path"),
      (+"regression:REG-RM-0001 rm keeps link targets",
       +"basic:rm keeps link targets"),
      (+"regression:REG-CP-0005 cp keeps broken links",
       +"basic:cp keeps broken links"),
      (+"regression:REG-CAT-0002 missing file continuation",
       +"command:cat continues after missing file"),
      (+"regression:REG-STDIN-0001 standard input operands",
       +"command:cat standard input"),
      (+"regression:REG-CAT-0003 cat output failure",
       +"command:cat output failure"),
      (+"regression:REG-STDOUT-0001 simple output failures",
       +"command:simple output failures"),
      (+"regression:REG-OPTIONS-0002 command option ordering",
       +"command:option operands surface"),
      (+"regression:REG-CP-0001 bounded binary copy",
       +"command:cp bounded binary"),
      (+"regression:REG-CP-0002 localized overwrite prompt",
       +"command:cp localized prompt"),
      (+"regression:REG-CP-0003 fifo recreation",
       +"command:cp FIFO recreation"),
      (+"regression:REG-CP-0004 socket recreation",
       +"command:cp socket recreation"),
      (+"regression:REG-SORT-0001 stable unique sort",
       +"command:sort surface"),
      (+"regression:REG-ENV-0001 utility status",
       +"command:env utility status"),
      (+"regression:REG-VERBOSE-0001 verbose output failures",
       +"command:verbose output failures"),
      (+"regression:REG-STDERR-0001 xargs trace failure",
       +"command:xargs surface"),
      (+"regression:REG-XARGS-0001 status bands",
       +"command:xargs status bands"),
      (+"regression:REG-STDOUT-0002 find output failure",
       +"command:find surface"),
      (+"regression:REG-STDOUT-0003 date output failure",
       +"command:date surface"),
      (+"regression:REG-STDOUT-0004 dd output failure",
       +"command:dd surface"),
      (+"regression:REG-STDOUT-0005 tr output failure",
       +"command:tr surface"),
      (+"regression:REG-HEAD-0001 head counts", +"command:head counts"),
      (+"regression:REG-HEAD-0002 head invalid count",
       +"command:head invalid count"),
      (+"regression:REG-HEAD-0004 head missing count",
       +"command:head missing count"),
      (+"regression:REG-HEAD-0003 head output failure",
       +"command:head output failure"),
      (+"regression:REG-ROOT-0002 root output failure",
       +"command:root output failure"),
      (+"regression:REG-TAIL-0001 tail byte suffix",
       +"command:tail byte mode edges"),
      (+"regression:REG-TAIL-0002 tail compact counts",
       +"command:tail compact counts"),
      (+"regression:REG-TAIL-0006 tail live follow",
       +"command:tail follow live"),
      (+"regression:REG-TAIL-0003 tail invalid count",
       +"command:tail invalid count"),
      (+"regression:REG-TAIL-0005 tail missing count",
       +"command:tail missing count"),
      (+"regression:REG-TAIL-0004 tail output failure",
       +"command:tail output failure"),
      (+"regression:REG-DIAG-0001 diagnostic escaping",
       +"command:usage errors"),
      (+"regression:REG-WC-0002 wc split utf-8",
       +"command:wc invalid UTF-8"),
      (+"regression:REG-WC-0003 wc malformed utf-8",
       +"command:wc malformed UTF-8"),
      (+"regression:REG-WC-0004 wc code point validity",
       +"command:wc code point validity"),
      (+"regression:REG-WC-0005 wc output failure",
       +"command:wc output failure")];

   procedure Set (Item : in out Filter; Prefix : String; Whole_Name : Boolean) is
   begin
      Item.Prefixes := Prefix_Vectors.To_Vector (Prefix, 1);
      Item.Whole_Name := Whole_Name;
   end Set;

   procedure Add (Item : in out Filter; Prefix : String) is
   begin
      Item.Prefixes.Append (Prefix);
   end Add;

   procedure Set_Listing (Item : in out Filter; Listing : Boolean) is
   begin
      Item.Listing := Listing;
   end Set_Listing;

   function Selects (Prefix : String; Whole_Name : Boolean; Test_Name : String) return Boolean is
      After : constant Integer := Test_Name'First + Prefix'Length;
   begin
      if Test_Name'Length < Prefix'Length
        or else Test_Name (Test_Name'First .. After - 1) /= Prefix
      then
         return False;
      end if;

      return not Whole_Name or else After > Test_Name'Last or else Test_Name (After) = ' ';
   end Selects;

   function Selects_Alias
     (Prefix     : String;
      Whole_Name : Boolean;
      Test_Name  : String) return Boolean
   is
     (for some Item of Regression_Aliases =>
        To_String (Item.Canonical_Name) = Test_Name
        and then Selects
          (Prefix, Whole_Name, To_String (Item.Alias_Name)));

   function Is_Exact_Alias
     (Alias_Name : String;
      Test_Name  : String) return Boolean
   is
     (for some Item of Regression_Aliases =>
        To_String (Item.Alias_Name) = Alias_Name
        and then To_String (Item.Canonical_Name) = Test_Name);

   overriding function Is_Active
     (Item : Filter;
      T    : AUnit.Tests.Test'Class) return Boolean
   is
      use AUnit.Simple_Test_Cases;
      use type AUnit.Message_String;
   begin
      if T not in Test_Case'Class or else Name (Test_Case'Class (T)) = null then
         return Item.Prefixes.Is_Empty and then not Item.Listing;
      end if;

      declare
         Test_Name : constant String := Name (Test_Case'Class (T)).all;
         Selected  : constant Boolean :=
           Item.Prefixes.Is_Empty
           or else
             (for some Prefix of Item.Prefixes =>
                Selects (Prefix, Item.Whole_Name, Test_Name)
                or else Selects_Alias
                  (Prefix, Item.Whole_Name, Test_Name));
      begin
         if Item.Listing then
            if Item.Prefixes.Is_Empty then
               Ada.Text_IO.Put_Line (Test_Name);
            else
               for Prefix of Item.Prefixes loop
                  if Selects (Prefix, Item.Whole_Name, Test_Name) then
                     Ada.Text_IO.Put_Line (Test_Name);
                  end if;
                  for Alias_Item of Regression_Aliases loop
                     if To_String (Alias_Item.Canonical_Name) = Test_Name
                       and then Selects
                         (Prefix,
                          Item.Whole_Name,
                          To_String (Alias_Item.Alias_Name))
                     then
                        Ada.Text_IO.Put_Line
                          (To_String (Alias_Item.Alias_Name));
                     end if;
                  end loop;
               end loop;
            end if;
            return False;
         end if;

         return Selected;
      end;
   end Is_Active;
end Suite_Filters;
