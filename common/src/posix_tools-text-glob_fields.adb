package body Posix_Tools.Text.Glob_Fields
  with SPARK_Mode => On
is
   function Bracket_Class_Matches
     (Pattern : String;
      Open    : Positive;
      Closing : Positive;
      Ch      : Character) return Boolean
   is
      Negated : constant Boolean := Open + 1 < Closing and then Pattern (Open + 1) in '!' | '^';
      Index   : Positive := (if Negated then Open + 2 else Open + 1);
      Matched : Boolean := False;
   begin
      while Index < Closing loop
         pragma Loop_Invariant (Index in Open + 1 .. Closing);
         pragma Loop_Variant (Increases => Index);

         if Closing > 2
           and then Index <= Closing - 3
           and then Pattern (Index + 1) = '-'
         then
            if Pattern (Index) <= Ch and then Ch <= Pattern (Index + 2) then
               Matched := True;
            end if;
            Index := Index + 3;
         else
            if Pattern (Index) = Ch then
               Matched := True;
            end if;
            Index := Index + 1;
         end if;
      end loop;

      return (if Negated then not Matched else Matched);
   end Bracket_Class_Matches;

   function Closing_Bracket_From (Pattern : String; Open : Positive) return Natural is
      Index : Positive := Open + 1;
   begin
      while Index <= Pattern'Last loop
         pragma Loop_Invariant (Index in Open + 1 .. Pattern'Last);
         pragma Loop_Variant (Increases => Index);

         if Pattern (Index) = ']' then
            return Index;
         end if;

         exit when Index = Pattern'Last;
         Index := Index + 1;
      end loop;

      return 0;
   end Closing_Bracket_From;
end Posix_Tools.Text.Glob_Fields;
