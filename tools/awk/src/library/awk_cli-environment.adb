with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;

package body Awk_CLI.Environment is

   package Name_Indexes is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Positive,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   function Normalize (Entries : Entry_Vectors.Vector) return Entry_Vectors.Vector is
      Result : Entry_Vectors.Vector;
      Indexes : Name_Indexes.Map;
   begin
      for Item of Entries loop
         if U.Length (Item.Name) > 0 then
            declare
               Name : constant String := U.To_String (Item.Name);
            begin
               if Indexes.Contains (Name) then
                  Result.Replace_Element (Indexes.Element (Name), Item);
               else
                  Result.Append (Item);
                  Indexes.Insert (Name, Result.Last_Index);
               end if;
            end;
         end if;
      end loop;
      return Result;
   end Normalize;
end Awk_CLI.Environment;
