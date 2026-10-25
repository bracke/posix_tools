with Posix_Tools.Text.Byte_Classes;

package body Posix_Tools.Text.Glob_Fields
  with SPARK_Mode => On
is
   package Classes renames Posix_Tools.Text.Byte_Classes;

   --  Whether Ch is in the character class Name, "alpha" and the others
   --  POSIX names, in the POSIX locale: ASCII alone. An unknown name has
   --  no members.
   function Class_Has (Name : String; Ch : Character) return Boolean;

   --  Where the bracketed item Pattern (Open .. ) opened by "[:", "[.", or
   --  "[=" ends: the index, Limit at most, of the ']' of its closing ":]",
   --  ".]", or "=]", with something between. Zero when there is none, and
   --  the '[' is then an ordinary character.
   function Item_End (Pattern : String; Open : Positive; Limit : Positive) return Natural
     with
       Pre =>
         Open in Pattern'Range
         and then Limit in Pattern'Range
         and then Open < Limit
         and then Open < Pattern'Last
         and then Pattern (Open) = '['
         and then Pattern (Open + 1) in ':' | '.' | '=',
       Post => Item_End'Result = 0 or else Item_End'Result in Open + 4 .. Limit;

   function Bracket_Class_Matches
     (Pattern : String;
      Open    : Positive;
      Closing : Positive;
      Ch      : Character) return Boolean
   is
      Negated : constant Boolean := Open + 1 < Closing and then Pattern (Open + 1) in '!' | '^';
      Index   : Positive := (if Negated then Open + 2 else Open + 1);
      Matched : Boolean := False;

      --  The character the element at Index stands for, a [.c.] or [=c=]
      --  standing for c, and where the next element starts. Valid is False
      --  for a collating element of more than one character, which no one
      --  character matches.
      procedure Element (At_Index : Positive; Value : out Character; Valid : out Boolean; Next : out Positive)
        with
          Pre  =>
            Open in Pattern'Range
            and then Closing in Pattern'Range
            and then Open < Closing
            and then At_Index in Open + 1 .. Closing - 1,
          Post => Next in At_Index + 1 .. Closing;

      procedure Element (At_Index : Positive; Value : out Character; Valid : out Boolean; Next : out Positive) is
      begin
         Value := Pattern (At_Index);
         Valid := True;
         Next := At_Index + 1;

         if Pattern (At_Index) = '['
           and then At_Index < Closing - 1
           and then Pattern (At_Index + 1) in '.' | '='
         then
            declare
               Last : constant Natural := Item_End (Pattern, At_Index, Closing - 1);
            begin
               if Last > 0 then
                  Valid := Last - At_Index = 4;
                  Value := Pattern (At_Index + 2);
                  Next := Last + 1;
               end if;
            end;
         end if;
      end Element;
   begin
      while Index < Closing loop
         pragma Loop_Invariant (Index in Open + 1 .. Closing - 1);
         pragma Loop_Variant (Increases => Index);

         declare
            Class_Last : constant Natural :=
              (if Pattern (Index) = '[' and then Index < Closing - 1 and then Pattern (Index + 1) = ':'
               then Item_End (Pattern, Index, Closing - 1)
               else 0);
         begin
            if Class_Last > 0 then
               if Class_Has (Pattern (Index + 2 .. Class_Last - 2), Ch) then
                  Matched := True;
               end if;
               Index := Class_Last + 1;
            else
               declare
                  Low, High     : Character;
                  Low_Valid     : Boolean;
                  High_Valid    : Boolean;
                  After_Low     : Positive;
                  After_High    : Positive;
               begin
                  Element (Index, Low, Low_Valid, After_Low);

                  --  A '-' between two elements makes a range; one last in
                  --  the expression is itself.
                  if After_Low < Closing - 1 and then Pattern (After_Low) = '-' then
                     Element (After_Low + 1, High, High_Valid, After_High);
                     if Low_Valid and then High_Valid and then Low <= Ch and then Ch <= High then
                        Matched := True;
                     end if;
                     Index := After_High;
                  else
                     if Low_Valid and then Low = Ch then
                        Matched := True;
                     end if;
                     Index := After_Low;
                  end if;
               end;
            end if;
         end;
      end loop;

      return (if Negated then not Matched else Matched);
   end Bracket_Class_Matches;

   function Class_Has (Name : String; Ch : Character) return Boolean is
   begin
      if Name = "alpha" then
         return Classes.Is_ASCII_Alpha (Ch);
      elsif Name = "digit" then
         return Classes.Is_ASCII_Digit (Ch);
      elsif Name = "alnum" then
         return Classes.Is_ASCII_Alphanumeric (Ch);
      elsif Name = "upper" then
         return Classes.Is_ASCII_Upper (Ch);
      elsif Name = "lower" then
         return Classes.Is_ASCII_Lower (Ch);
      elsif Name = "space" then
         return Classes.Is_POSIX_Space (Ch);
      elsif Name = "blank" then
         return Classes.Is_POSIX_Blank (Ch);
      elsif Name = "punct" then
         return Classes.Is_ASCII_Punctuation (Ch);
      elsif Name = "print" then
         return Classes.Is_ASCII_Printable (Ch);
      elsif Name = "graph" then
         return Classes.Is_ASCII_Graph (Ch);
      elsif Name = "cntrl" then
         return Classes.Is_ASCII_Control (Ch);
      elsif Name = "xdigit" then
         return Classes.Is_ASCII_Hex_Digit (Ch);
      else
         return False;
      end if;
   end Class_Has;

   function Closing_Bracket_From (Pattern : String; Open : Positive) return Natural is
      Index : Positive := Open + 1;
   begin
      --  A ']' first in the class, after any negation, is one of its
      --  members rather than its end, as in "[]a]" and "[!]a]"; with
      --  nothing after it to close the class, "[]" and "[!]" are ordinary
      --  characters.
      if Pattern (Index) in '!' | '^' then
         if Index = Pattern'Last then
            return 0;
         end if;
         Index := Index + 1;
      end if;

      if Pattern (Index) = ']' then
         if Index = Pattern'Last then
            return 0;
         end if;
         Index := Index + 1;
      end if;

      loop
         pragma Loop_Invariant (Index in Open + 1 .. Pattern'Last);
         pragma Loop_Variant (Increases => Index);

         if Pattern (Index) = ']' then
            return Index;
         end if;

         --  A ']' inside "[:alpha:]", "[.c.]", or "[=c=]" does not close
         --  the class.
         if Pattern (Index) = '['
           and then Index < Pattern'Last
           and then Pattern (Index + 1) in ':' | '.' | '='
         then
            declare
               Last : constant Natural := Item_End (Pattern, Index, Pattern'Last);
            begin
               if Last > 0 then
                  Index := Last;
               end if;
            end;
         end if;

         exit when Index = Pattern'Last;
         Index := Index + 1;
      end loop;

      return 0;
   end Closing_Bracket_From;

   function Item_End (Pattern : String; Open : Positive; Limit : Positive) return Natural is
      Mark : constant Character := Pattern (Open + 1);
   begin
      for Index in Open + 1 .. Limit - 1 loop
         --  Something between the opening mark and the closing one.
         if Index - Open > 2 and then Pattern (Index) = Mark and then Pattern (Index + 1) = ']' then
            return Index + 1;
         end if;
      end loop;

      return 0;
   end Item_End;
end Posix_Tools.Text.Glob_Fields;
