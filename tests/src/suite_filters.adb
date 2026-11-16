with Ada.Containers.Vectors;
with Ada.Text_IO;
with Ada.Strings.Unbounded;
with AUnit.Simple_Test_Cases;
with AUnit;
with Regression_Registry;

package body Suite_Filters is
   use Ada.Strings.Unbounded;

   type Alias_Entry is record
      Alias_Name     : Unbounded_String;
      Canonical_Name : Unbounded_String;
   end record;

   package Alias_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Alias_Entry);

   Regression_Aliases : Alias_Vectors.Vector;
   Aliases_Loaded     : Boolean := False;

   procedure Add_Regression_Alias
     (Regression_Id : String;
      Canonical     : String) is
   begin
      if not Regression_Registry.Is_Aliasable_AUnit_Reference
        (Canonical)
      then
         return;
      end if;

      declare
         Alias_Name : constant String :=
           "regression:" & Regression_Id & " " & Canonical;
      begin
         if not (for some Item of Regression_Aliases =>
                   To_String (Item.Alias_Name) = Alias_Name
                   and then To_String (Item.Canonical_Name) = Canonical)
         then
            Regression_Aliases.Append
              (Alias_Entry'
                 (Alias_Name     => To_Unbounded_String (Alias_Name),
                  Canonical_Name => To_Unbounded_String (Canonical)));
         end if;
      end;
   end Add_Regression_Alias;

   procedure Load_Regression_Aliases is
      procedure Add_Row
        (Line_Number : Positive;
         Id           : String;
         Command      : String;
         Summary      : String;
         Tests        : String)
      is
         pragma Unreferenced
           (Line_Number, Command, Summary);
         Reference_Count : Natural;
         Has_Empty       : Boolean;

         procedure Add_Reference (Reference : String) is
         begin
            Add_Regression_Alias (Id, Reference);
         end Add_Reference;
      begin
         Regression_Registry.For_Each_Test_Reference
           (Tests,
            Add_Reference'Access,
            Reference_Count,
            Has_Empty);
         pragma Assert (Reference_Count > 0 and then not Has_Empty);
      end Add_Row;
   begin
      if Aliases_Loaded then
         return;
      end if;
      Regression_Registry.For_Each_Row (Add_Row'Access);
      Aliases_Loaded := True;
   end Load_Regression_Aliases;

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
      Alias_Prefix : constant String := "regression:";
      Common       : constant Natural :=
        Natural'Min (Prefix'Length, Alias_Prefix'Length);
   begin
      --  The generated regression registry is an optional dependency for
      --  ordinary AUnit selection.  Do not read it unless Prefix can
      --  actually select a regression alias; this keeps basic and other
      --  canonical suites runnable when registry validation itself fails.
      if Common = 0
        or else Prefix (Prefix'First .. Prefix'First + Common - 1) /=
          Alias_Prefix (Alias_Prefix'First .. Alias_Prefix'First + Common - 1)
      then
         return False;
      end if;
      Load_Regression_Aliases;
      return
        (for some Item of Regression_Aliases =>
           To_String (Item.Canonical_Name) = Test_Name
           and then Selects
             (Prefix, Whole_Name, To_String (Item.Alias_Name)));
   end Selects_Alias;

   function Is_Exact_Alias
     (Alias_Name : String;
      Test_Name  : String) return Boolean
   is
      Alias_Prefix : constant String := "regression:";
   begin
      if Alias_Name'Length < Alias_Prefix'Length
        or else Alias_Name
          (Alias_Name'First .. Alias_Name'First + Alias_Prefix'Length - 1) /=
            Alias_Prefix
      then
         return False;
      end if;
      Load_Regression_Aliases;
      return
        (for some Item of Regression_Aliases =>
           To_String (Item.Alias_Name) = Alias_Name
           and then To_String (Item.Canonical_Name) = Test_Name);
   end Is_Exact_Alias;

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
