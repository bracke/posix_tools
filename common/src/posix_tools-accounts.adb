package body Posix_Tools.Accounts
  with SPARK_Mode => On
is
   function Keep return Update is
     ((Change => False, Value => 0));

   function Set_To (Value : Id) return Update is
     ((Change => True, Value => Value));

   function Value_Or_Keep (Item : Update) return Id is
     (if Item.Change then Item.Value else Id'Last);

   function Image (Value : Id) return String is
      Raw : constant String := Id'Image (Value);
   begin
      return
        (if Raw'Length > 0 and then Raw (Raw'First) = ' '
         then Raw (Raw'First + 1 .. Raw'Last)
         else Raw);
   end Image;

   function Parse (Text : String) return Parse_Result is
      Parsed : Id := 0;
   begin
      if Text'Length = 0 then
         return (Valid => False, Value => 0);
      end if;

      for Ch of Text loop
         if Ch not in '0' .. '9' then
            return (Valid => False, Value => 0);
         end if;

         declare
            Digit : constant Id := Id (Character'Pos (Ch) - Character'Pos ('0'));
         begin
            if Parsed > (Id'Last - Digit) / 10 then
               return (Valid => False, Value => 0);
            end if;
            Parsed := Parsed * 10 + Digit;
         end;
      end loop;

      return (Valid => True, Value => Parsed);
   end Parse;
end Posix_Tools.Accounts;
