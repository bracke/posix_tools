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

   --  Key's text with each placeholder Names lists, separated by spaces, left
   --  in it as "{name}": for a caller that looks a text up once and fills it
   --  in many times after, without reading the catalog again. Default is
   --  such a text too.
   function Pattern
     (Locale  : String;
      Key     : String;
      Names   : String;
      Default : String) return String;
end Posix_Tools.Localization;
