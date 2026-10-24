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
end Posix_Tools.Text.Natural_Order;
