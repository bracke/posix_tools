package body Posix_Tools.Text.Locale_Fields
  with SPARK_Mode => On
is
   function Catalog_Path
     (Here        : Boolean;
      Parent      : Boolean;
      Grandparent : Boolean) return String
   is
   begin
      if Here then
         return "common/messages/posix_tools.catalog";
      elsif Parent then
         return "../common/messages/posix_tools.catalog";
      elsif Grandparent then
         return "../../common/messages/posix_tools.catalog";
      end if;

      return "common/messages/posix_tools.catalog";
   end Catalog_Path;

   function Effective_Locale (Locale : String) return String is
   begin
      if Locale = "" then
         return "en";
      end if;

      return Locale;
   end Effective_Locale;
end Posix_Tools.Text.Locale_Fields;
