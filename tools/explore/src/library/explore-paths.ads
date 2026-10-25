--  Taking paths and names apart and putting them together, as text: nothing
--  here touches the filesystem.
package Explore.Paths is
   --  The parent directory of an absolute Path; Path itself for the root.
   function Parent_Of (Path : String) return String;

   --  The last component of Path, any trailing slashes aside; empty for the
   --  root.
   function Name_Of (Path : String) return String;

   --  The path of Name in Directory, with one slash between them.
   function Child_Of (Directory, Name : String) return String;

   --  Text with its ASCII letters in lower case and every other byte as it
   --  is, as the filter and a name search compare names: a byte of a UTF-8
   --  sequence is never mistaken for a letter.
   function Folded (Text : String) return String;

   --  Whether Name matches the glob Pattern, the case of ASCII letters
   --  ignored in both as Folded ignores it: how openers, previewers and a
   --  name search pick the files they are for.
   function Glob_Matches (Pattern, Name : String) return Boolean;
end Explore.Paths;
