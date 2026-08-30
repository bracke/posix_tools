package Posix_Tools.Text.Cut_Fields
  with SPARK_Mode => On
is
   type Range_Item is record
      First : Positive := 1;
      Last  : Natural := 0;
   end record;

   type Parsed_Range is record
      Valid : Boolean := False;
      Item  : Range_Item;
      Next  : Natural := 0;
   end record;

   function Contains_Position (Item : Range_Item; Position : Positive) return Boolean is
     (Position >= Item.First and then (Item.Last = 0 or else Position <= Item.Last))
     with
       Post =>
         Contains_Position'Result =
           (Position >= Item.First and then (Item.Last = 0 or else Position <= Item.Last));

   function Parse_Range_Item (Text : String; First : Positive) return Parsed_Range
     with
       Pre =>
         Text /= ""
         and then First in Text'Range,
       Post =>
         (if not Parse_Range_Item'Result.Valid then Parse_Range_Item'Result.Next = First)
         and then
           (if Parse_Range_Item'Result.Valid then
              Parse_Range_Item'Result.Item.Last = 0
              or else Parse_Range_Item'Result.Item.First <= Parse_Range_Item'Result.Item.Last)
         and then
           (if Parse_Range_Item'Result.Valid then
              Parse_Range_Item'Result.Next = 0
              or else
                (Parse_Range_Item'Result.Next in Text'Range
                 and then Parse_Range_Item'Result.Next > First));

   function Parse_List (Text : String) return Boolean
     with
       Pre =>
         Text'First in Positive
         and then Text'Last < Positive'Last,
       Post =>
         (if Text = "" then not Parse_List'Result);
end Posix_Tools.Text.Cut_Fields;
