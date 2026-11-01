package body Tooling_Steps is
   function Lookup (Text : String) return Subcommand is
   begin
      for Item in Subcommand loop
         if Name (Item) = Text then
            return Item;
         end if;
      end loop;

      raise Constraint_Error with "no subcommand " & Text;
   end Lookup;

   function Position (List : Step_List; Item : Step) return Natural is
   begin
      for Index in List'Range loop
         if List (Index) = Item then
            return Index;
         end if;
      end loop;

      return 0;
   end Position;
end Tooling_Steps;
