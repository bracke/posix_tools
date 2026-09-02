package body Awk_CLI.Environment is
   use type U.Unbounded_String;

   function Normalize (Entries : Entry_Vectors.Vector) return Entry_Vectors.Vector is
      Result : Entry_Vectors.Vector;
   begin
      for Item of Entries loop
         if U.Length (Item.Name) > 0 then
            declare
               Found : Natural := 0;
            begin
               if not Result.Is_Empty then
                  for Index in Result.First_Index .. Result.Last_Index loop
                     if Result.Element (Index).Name = Item.Name then
                        Found := Index;
                        exit;
                     end if;
                  end loop;
               end if;

               if Found = 0 then
                  Result.Append (Item);
               else
                  Result.Replace_Element (Found, Item);
               end if;
            end;
         end if;
      end loop;
      return Result;
   end Normalize;
end Awk_CLI.Environment;
