--  The English text of each message, for when the catalogue cannot give it.
private package Sed.Localization.Defaults is

   --  @param Key Stable message key.
   --  @return The message's English template, its arguments left as
   --    "{name}"; empty for a key the catalogue does not define.
   function Template (Key : String) return String;

end Sed.Localization.Defaults;
