package Posix_Tools.Text.Owner_Groups
  with SPARK_Mode => On
is
   type Parsed_Owner_Group is record
      Has_Separator : Boolean := False;
      Has_Owner     : Boolean := False;
      Owner_First   : Positive := 1;
      Owner_Last    : Natural := 0;
      Has_Group     : Boolean := False;
      Group_First   : Positive := 1;
      Group_Last    : Natural := 0;
   end record;

   function Parse_Owner_Group (Text : String) return Parsed_Owner_Group
     with
       Pre =>
         Text'First in Positive
         and then Text'Last < Positive'Last,
       Post =>
         (if Parse_Owner_Group'Result.Has_Owner then
            Parse_Owner_Group'Result.Owner_First = Text'First
            and then Parse_Owner_Group'Result.Owner_Last in Text'Range
            and then Parse_Owner_Group'Result.Owner_First
              <= Parse_Owner_Group'Result.Owner_Last
          else
            Parse_Owner_Group'Result.Owner_First = 1
            and then Parse_Owner_Group'Result.Owner_Last = 0)
         and then
           (if Parse_Owner_Group'Result.Has_Group then
              Parse_Owner_Group'Result.Group_First in Text'Range
              and then Parse_Owner_Group'Result.Group_Last = Text'Last
              and then Parse_Owner_Group'Result.Group_First
                <= Parse_Owner_Group'Result.Group_Last
            else
              Parse_Owner_Group'Result.Group_First = 1
              and then Parse_Owner_Group'Result.Group_Last = 0)
         and then
           (if Text = "" then
              not Parse_Owner_Group'Result.Has_Separator
              and then not Parse_Owner_Group'Result.Has_Owner
              and then not Parse_Owner_Group'Result.Has_Group);
end Posix_Tools.Text.Owner_Groups;
