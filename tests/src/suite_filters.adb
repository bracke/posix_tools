with Ada.Text_IO;
with AUnit.Simple_Test_Cases;
with AUnit;

package body Suite_Filters is
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
           or else (for some Prefix of Item.Prefixes => Selects (Prefix, Item.Whole_Name, Test_Name));
      begin
         if Item.Listing then
            if Selected then
               Ada.Text_IO.Put_Line (Test_Name);
            end if;
            return False;
         end if;

         return Selected;
      end;
   end Is_Active;
end Suite_Filters;
