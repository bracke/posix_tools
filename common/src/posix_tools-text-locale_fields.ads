package Posix_Tools.Text.Locale_Fields
  with SPARK_Mode => On
is
   function Catalog_Path
     (Here        : Boolean;
      Parent      : Boolean;
      Grandparent : Boolean) return String
     with Post =>
       (if Here then
          Catalog_Path'Result = "common/messages/posix_tools.catalog"
        elsif Parent then
          Catalog_Path'Result = "../common/messages/posix_tools.catalog"
        elsif Grandparent then
          Catalog_Path'Result = "../../common/messages/posix_tools.catalog"
        else
          Catalog_Path'Result = "common/messages/posix_tools.catalog");

   function Effective_Locale (Locale : String) return String
     with Post =>
       (if Locale = "" then
          Effective_Locale'Result = "en"
        else
          Effective_Locale'Result = Locale);
end Posix_Tools.Text.Locale_Fields;
