package Posix_Tools.Localization is
   function Text
     (Locale  : String;
      Key     : String;
      Default : String) return String;

   function Text_1
     (Locale  : String;
      Key     : String;
      Name    : String;
      Value   : String;
      Default : String) return String;
end Posix_Tools.Localization;
