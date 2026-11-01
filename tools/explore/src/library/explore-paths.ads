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

   --  Path with its last name replaced by Name, as renaming it would name
   --  it; Name alone when Path has but one name.
   function Renamed (Path, Name : String) return String;

   --  Path as it is named below Directory, as a search result is; empty when
   --  it does not lie below it.
   function Below (Path, Directory : String) return String;

   --  Whether Name can name an entry of a directory: it is not empty, nor
   --  . or .., and has no slash in it.
   function Is_Plain_Name (Name : String) return Boolean is
     (Name'Length > 0 and then Name /= "." and then Name /= ".." and then (for all C of Name => C /= '/'));

   --  The path Text names, as a path to go to is typed: from Home after a
   --  leading ~, as it is when absolute, and otherwise relative to Current.
   function Resolve (Text, Current, Home : String) return String
     with Pre => Text'Length > 0;

   --  Text with its ASCII letters in lower case and every other byte as it
   --  is, as the filter and a name search compare names: a byte of a UTF-8
   --  sequence is never mistaken for a letter.
   function Folded (Text : String) return String;

   --  Whether Name matches the glob Pattern, the case of ASCII letters
   --  ignored in both as Folded ignores it: how openers, previewers and a
   --  name search pick the files they are for.
   function Glob_Matches (Pattern, Name : String) return Boolean;
end Explore.Paths;
