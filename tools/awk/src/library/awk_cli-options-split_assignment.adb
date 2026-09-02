with Ada.Strings.Fixed;

separate (Awk_CLI.Options)
procedure Split_Assignment (Text : String; Name, Value : out U.Unbounded_String) is
   Equal : constant Natural := Ada.Strings.Fixed.Index (Text, "=");
begin
   Name := U.To_Unbounded_String (Text (Text'First .. Equal - 1));
   if Equal < Text'Last then
      Value := U.To_Unbounded_String (Text (Equal + 1 .. Text'Last));
   else
      Value := U.Null_Unbounded_String;
   end if;
end Split_Assignment;
