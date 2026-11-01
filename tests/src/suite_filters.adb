with AUnit.Simple_Test_Cases;
with AUnit;

package body Suite_Filters is
   use Ada.Strings.Unbounded;

   procedure Set (Item : in out Filter; Prefix : String; Whole_Name : Boolean) is
   begin
      Item.Prefix := To_Unbounded_String (Prefix);
      Item.Whole_Name := Whole_Name;
   end Set;

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
      if Length (Item.Prefix) = 0 then
         return True;
      elsif T not in Test_Case'Class or else Name (Test_Case'Class (T)) = null then
         return False;
      else
         return Selects (To_String (Item.Prefix), Item.Whole_Name, Name (Test_Case'Class (T)).all);
      end if;
   end Is_Active;
end Suite_Filters;
