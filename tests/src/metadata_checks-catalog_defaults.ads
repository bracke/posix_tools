package Metadata_Checks.Catalog_Defaults is
   procedure Require_Matching_Defaults
     (Catalog_Path  : String;
      Defaults_Path : String);
private
   procedure Self_Test;
end Metadata_Checks.Catalog_Defaults;
