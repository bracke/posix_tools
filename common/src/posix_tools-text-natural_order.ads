--  The order people expect file names in: runs of digits compare by the
--  number they spell, so "file9" comes before "file10".
package Posix_Tools.Text.Natural_Order
  with SPARK_Mode => On
is

   --  Whether Left sorts before Right. Outside digit runs characters compare
   --  by byte, with ASCII letters compared regardless of case when Fold_Case.
   --  Names that compare equal that way -- "a01" and "a1", or "A" and "a"
   --  when folding -- are ordered by their bytes, so that only identical
   --  names are equal and the order is total.
   function Less (Left, Right : String; Fold_Case : Boolean := False) return Boolean;

   --  A key for Text under which plain byte comparison is this order: for
   --  texts without NUL bytes, Less (Left, Right, Fold_Case) is
   --  Sort_Key (Left, Fold_Case) < Sort_Key (Right, Fold_Case). Sorting many
   --  names makes each key once and compares keys, which is much cheaper than
   --  comparing names: each digit run becomes '0', its length in four bytes,
   --  and its digits without leading zeros; letters are folded when asked;
   --  and the text itself follows a NUL, to order names that are otherwise
   --  equal by their bytes.
   function Sort_Key (Text : String; Fold_Case : Boolean := False) return String
     with SPARK_Mode => Off;
end Posix_Tools.Text.Natural_Order;
