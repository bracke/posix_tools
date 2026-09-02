with Ada.Strings.Fixed;

separate (Awk_CLI.Options)
function Is_Assignment_Text (Text : String) return Boolean is
   function Is_Name_Start (C : Character) return Boolean is
     ((C in 'A' .. 'Z') or else (C in 'a' .. 'z') or else C = '_');

   function Is_Name_Char (C : Character) return Boolean is
     (Is_Name_Start (C) or else (C in '0' .. '9'));

   Equal : constant Natural := Ada.Strings.Fixed.Index (Text, "=");
begin
   if Equal = 0 or else Equal = Text'First then
      return False;
   end if;

   if not Is_Name_Start (Text (Text'First)) then
      return False;
   end if;

   for Index in Text'First + 1 .. Equal - 1 loop
      if not Is_Name_Char (Text (Index)) then
         return False;
      end if;
   end loop;

   return True;
end Is_Assignment_Text;
