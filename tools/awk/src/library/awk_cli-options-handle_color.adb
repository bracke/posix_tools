separate (Awk_CLI.Options)
function Handle_Color
  (Result  : in out Parsed_Options;
   Current : String) return Handler_Result
is
   Value : constant String := Current (Current'First + 8 .. Current'Last);
begin
   if Value = "auto" then
      Result.Color := Color_Auto;
   elsif Value = "always" then
      Result.Color := Color_Always;
   elsif Value = "never" then
      Result.Color := Color_Never;
   else
      return (Ok => False, Failure => Invalid_Color (Result.Color, Value));
   end if;

   return (Ok => True);
end Handle_Color;
