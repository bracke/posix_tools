separate (Metadata_Checks.Continuous_Integration)
procedure Self_Test is
   Components : constant Positive := 65;
   Deep_Dir   : Unbounded_String;
   Expected   : Unbounded_String;
begin
   for Index in 1 .. Components loop
      declare
         Part : constant String := "component" & Positive'Image (Index);
      begin
         Append (Deep_Dir, (if Length (Deep_Dir) = 0 then "" else "/") & Part);
         if Index < Components then
            Append (Expected, (if Length (Expected) = 0 then "" else "/") & Part);
         end if;
      end;
   end loop;

   if Resolve (To_String (Deep_Dir), "../target") /=
     To_String (Expected) & "/target"
   then
      raise Program_Error with
        "CI path resolution truncated a path deeper than 64 components";
   end if;
end Self_Test;
