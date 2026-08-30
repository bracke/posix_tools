package body Posix_Tools.Text.Xargs_Fields
  with SPARK_Mode => On
is
   function Size_With_Item (Total, Item_Length : Natural) return Natural is
   begin
      if Item_Length = Natural'Last then
         return Natural'Last;
      else
         declare
            Cost : constant Natural := Item_Length + 1;
         begin
            if Total > Natural'Last - Cost then
               return Natural'Last;
            else
               return Total + Cost;
            end if;
         end;
      end if;
   end Size_With_Item;
end Posix_Tools.Text.Xargs_Fields;
