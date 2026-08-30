package Posix_Tools.Text.Xargs_Fields
  with SPARK_Mode => On
is
   function Size_With_Item (Total, Item_Length : Natural) return Natural
     with
       Post =>
         Size_With_Item'Result >= Total
         and then
           (if Size_With_Item'Result /= Natural'Last then
              Size_With_Item'Result = Total + Item_Length + 1);
end Posix_Tools.Text.Xargs_Fields;
