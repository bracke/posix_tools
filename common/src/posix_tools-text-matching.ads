package Posix_Tools.Text.Matching
  with SPARK_Mode => On
is
   function Contains (Text : String; Ch : Character) return Boolean is
     (for some I in Text'Range => Text (I) = Ch)
     with
       Post =>
         Contains'Result =
           (for some I in Text'Range => Text (I) = Ch);

   function Contains (Text, Pattern : String) return Boolean
     with
       Post =>
         (if Pattern = "" then Contains'Result)
         and then
           (if Pattern'Length > Text'Length then not Contains'Result);

   function Ends_With (Text, Suffix : String) return Boolean
     with
       Post =>
         (if Suffix = "" then Ends_With'Result)
         and then
           (if Suffix'Length > Text'Length then not Ends_With'Result);

   function Starts_With (Text, Prefix : String) return Boolean
     with
       Post =>
         (if Prefix = "" then Starts_With'Result)
         and then
           (if Prefix'Length > Text'Length then not Starts_With'Result);

   function Starts_With_At
     (Text    : String;
      Pattern : String;
      Index   : Positive) return Boolean
     with
       Post =>
         (if Pattern = "" then not Starts_With_At'Result)
         and then
           (if Index not in Text'Range then not Starts_With_At'Result)
         and then
           (if Pattern'Length > Text'Length then not Starts_With_At'Result);

end Posix_Tools.Text.Matching;
