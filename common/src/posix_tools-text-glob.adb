with Posix_Tools.Text.Glob_Fields;

package body Posix_Tools.Text.Glob is
   function Matches (Pattern, Text : String) return Boolean is
      P : Positive := Pattern'First;
      T : Positive := Text'First;

      --  The last star seen, and the text it was last let take up to: on a
      --  mismatch it takes one more character. Moving back only to the last
      --  star is enough, and keeps the match from trying every split of the
      --  text between the stars.
      Star_P : Natural := 0;
      Star_T : Positive := Text'First;

      --  Whether the pattern element at P matches the character at T, and
      --  where the pattern goes on after it.
      procedure Step (Matched : out Boolean; Next : out Positive);

      procedure Step (Matched : out Boolean; Next : out Positive) is
         Closing : constant Natural :=
           (if Pattern (P) = '[' and then P < Pattern'Last
            then Posix_Tools.Text.Glob_Fields.Closing_Bracket_From (Pattern, P)
            else 0);
      begin
         if Pattern (P) = '?' then
            Matched := True;
            Next := P + 1;
         elsif Closing > 0 then
            Matched := Posix_Tools.Text.Glob_Fields.Bracket_Class_Matches (Pattern, P, Closing, Text (T));
            Next := Closing + 1;
         elsif Pattern (P) = '\' and then P < Pattern'Last then
            --  The next character for itself, a star or a bracket too.
            Matched := Pattern (P + 1) = Text (T);
            Next := P + 2;
         else
            --  A '[' that no ']' closes is a character like any other.
            Matched := Pattern (P) = Text (T);
            Next := P + 1;
         end if;
      end Step;
   begin
      while T <= Text'Last loop
         if P <= Pattern'Last and then Pattern (P) = '*' then
            Star_P := P;
            Star_T := T;
            P := P + 1;
         else
            declare
               Matched : Boolean := False;
               Next    : Positive := P;
            begin
               if P <= Pattern'Last then
                  Step (Matched, Next);
               end if;

               if Matched then
                  P := Next;
                  T := T + 1;
               elsif Star_P /= 0 then
                  Star_T := Star_T + 1;
                  T := Star_T;
                  P := Star_P + 1;
               else
                  return False;
               end if;
            end;
         end if;
      end loop;

      while P <= Pattern'Last and then Pattern (P) = '*' loop
         P := P + 1;
      end loop;

      return P > Pattern'Last;
   end Matches;
end Posix_Tools.Text.Glob;
