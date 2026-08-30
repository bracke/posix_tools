package body Posix_Tools.Text.Owner_Groups
  with SPARK_Mode => On
is
   function Empty_Result return Parsed_Owner_Group is
   begin
      return
        (Has_Separator => False,
         Has_Owner     => False,
         Owner_First   => 1,
         Owner_Last    => 0,
         Has_Group     => False,
         Group_First   => 1,
         Group_Last    => 0);
   end Empty_Result;

   function Parse_Owner_Group (Text : String) return Parsed_Owner_Group is
      Split : Natural := 0;
   begin
      if Text = "" then
         return Empty_Result;
      end if;

      for I in Text'Range loop
         pragma Loop_Invariant (Split = 0 or else Split in Text'Range);

         if Text (I) = ':' then
            Split := I;
            exit;
         end if;
      end loop;

      if Split = 0 then
         return
           (Has_Separator => False,
            Has_Owner     => True,
            Owner_First   => Text'First,
            Owner_Last    => Text'Last,
            Has_Group     => False,
            Group_First   => 1,
            Group_Last    => 0);
      else
         return
           (Has_Separator => True,
            Has_Owner     => Split > Text'First,
            Owner_First   => (if Split > Text'First then Text'First else 1),
            Owner_Last    => (if Split > Text'First then Split - 1 else 0),
            Has_Group     => Split < Text'Last,
            Group_First   => (if Split < Text'Last then Split + 1 else 1),
            Group_Last    => (if Split < Text'Last then Text'Last else 0));
      end if;
   end Parse_Owner_Group;
end Posix_Tools.Text.Owner_Groups;
