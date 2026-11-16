--  The single descriptor-driven source of AUnit prefixes, suite groups and
--  categories shared by selection and regression metadata.
package Test_Taxonomy is
   function Is_AUnit_Name (Name : String) return Boolean;
   function Is_Aliasable_AUnit_Name (Name : String) return Boolean;

   function Is_Group (Name : String) return Boolean;
   function Is_Category (Name : String) return Boolean;

   procedure For_Each_Group_Prefix
     (Name  : String;
      Visit : not null access procedure (Prefix : String));

   procedure For_Each_Category_Prefix
     (Name  : String;
      Visit : not null access procedure (Prefix : String));

   function Canonical_Category_Match_Count
     (Test_Name : String) return Natural;
end Test_Taxonomy;
