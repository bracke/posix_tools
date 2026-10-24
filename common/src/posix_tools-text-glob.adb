with Posix_Tools.Text.Glob_Fields;

package body Posix_Tools.Text.Glob is
   function Matches (Pattern, Text : String) return Boolean is
      function Match_From (P, T : Natural) return Boolean is
      begin
         if P > Pattern'Last then
            return T > Text'Last;
         elsif Pattern (P) = '*' then
            for Next in T .. Text'Last + 1 loop
               if Match_From (P + 1, Next) then
                  return True;
               end if;
            end loop;
            return False;
         elsif Pattern (P) = '?' then
            return T <= Text'Last and then Match_From (P + 1, T + 1);
         elsif Pattern (P) = '[' then
            declare
               Closing : constant Natural :=
                 (if P < Pattern'Last then
                    Posix_Tools.Text.Glob_Fields.Closing_Bracket_From (Pattern, P)
                  else
                    0);
            begin
               if Closing = 0 then
                  return T <= Text'Last
                    and then Pattern (P) = Text (T)
                    and then Match_From (P + 1, T + 1);
               elsif T > Text'Last then
                  return False;
               else
                  return Posix_Tools.Text.Glob_Fields.Bracket_Class_Matches
                      (Pattern, P, Closing, Text (T))
                    and then Match_From (Closing + 1, T + 1);
               end if;
            end;
         elsif T <= Text'Last and then Pattern (P) = Text (T) then
            return Match_From (P + 1, T + 1);
         else
            return False;
         end if;
      end Match_From;
   begin
      return Match_From (Pattern'First, Text'First);
   end Matches;
end Posix_Tools.Text.Glob;
