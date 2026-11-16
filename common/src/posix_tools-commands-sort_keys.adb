with Ada.Containers;
with Ada.Unchecked_Deallocation;
with Posix_Tools.Commands.Sort_Keys.Comparison;
with Posix_Tools.Commands.Text_Helpers.Collation;

package body Posix_Tools.Commands.Sort_Keys is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;
   use type Posix_Tools.Numbers.Count;

   package Segment_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;

   type Rules_Array is array (Positive range <>) of Ordering_Rules;

   type Index_Array is array (Positive range <>) of Positive;
   type Index_Array_Access is access Index_Array;

   --  Every line's comparison keys, built once. Key K of line L is
   --  Keys ((L - 1) * Key_Count + K).
   type Prepared_Lines (Key_Count : Positive) is record
      Rules        : Rules_Array (1 .. Key_Count);
      Keys         : Segment_Vectors.Vector;
      Range_Keys   : Boolean_Vectors.Vector;
      Ranges       : Range_Vectors.Vector;
      Whole        : Segment_Vectors.Vector;
      Direct_Text_Key : Boolean := False;
      Use_Whole    : Boolean := False;
      Last_Resort  : Boolean := True;
      Reverse_Last : Boolean := False;
   end record;

   function Compare_Keys
     (Data        : Prepared_Lines;
      Lines       : Posix_Tools.Streams.Lines.Segment_Vector;
      Left, Right : Positive) return Integer;

   function Compare_Ranges
     (Left        : String;
      Left_Range  : Posix_Tools.Commands.Sort_Key_Text.Key_Range;
      Right       : String;
      Right_Range : Posix_Tools.Commands.Sort_Key_Text.Key_Range) return Integer;

   function Compare_Ranges
     (Left        : Unbounded_String;
      Left_Range  : Posix_Tools.Commands.Sort_Key_Text.Key_Range;
      Right       : Unbounded_String;
      Right_Range : Posix_Tools.Commands.Sort_Key_Text.Key_Range) return Integer;

   function Compare_Lines
     (Data        : Prepared_Lines;
      Lines       : Posix_Tools.Streams.Lines.Segment_Vector;
      Left, Right : Positive) return Integer;

   procedure Free is new Ada.Unchecked_Deallocation (Index_Array, Index_Array_Access);

   function Prepare
     (Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options) return Prepared_Lines;

   function Compare_Ranges
     (Left        : String;
      Left_Range  : Posix_Tools.Commands.Sort_Key_Text.Key_Range;
      Right       : String;
      Right_Range : Posix_Tools.Commands.Sort_Key_Text.Key_Range) return Integer
   is
      Left_Index  : Natural := Left_Range.First;
      Right_Index : Natural := Right_Range.First;
   begin
      while Left_Index <= Left_Range.Last
        and then Right_Index <= Right_Range.Last
      loop
         if Left (Left_Index) < Right (Right_Index) then
            return -1;
         elsif Left (Left_Index) > Right (Right_Index) then
            return 1;
         end if;
         Left_Index := Left_Index + 1;
         Right_Index := Right_Index + 1;
      end loop;
      if Left_Index <= Left_Range.Last then
         return 1;
      elsif Right_Index <= Right_Range.Last then
         return -1;
      else
         return 0;
      end if;
   end Compare_Ranges;

   function Compare_Ranges
     (Left        : Unbounded_String;
      Left_Range  : Posix_Tools.Commands.Sort_Key_Text.Key_Range;
      Right       : Unbounded_String;
      Right_Range : Posix_Tools.Commands.Sort_Key_Text.Key_Range) return Integer
   is
      Left_Index  : Natural := Left_Range.First;
      Right_Index : Natural := Right_Range.First;
   begin
      while Left_Index <= Left_Range.Last
        and then Right_Index <= Right_Range.Last
      loop
         if Element (Left, Left_Index) < Element (Right, Right_Index) then
            return -1;
         elsif Element (Left, Left_Index) > Element (Right, Right_Index) then
            return 1;
         end if;
         Left_Index := Left_Index + 1;
         Right_Index := Right_Index + 1;
      end loop;
      if Left_Index <= Left_Range.Last then
         return 1;
      elsif Right_Index <= Right_Range.Last then
         return -1;
      else
         return 0;
      end if;
   end Compare_Ranges;

   function Compare
     (Self : Comparator; Left, Right : Prepared_Line) return Integer
   is
      Compared : Integer;
   begin
      if Self.Direct_Text_Key then
         if Left.Text < Right.Text then
            Compared := -1;
         elsif Left.Text > Right.Text then
            Compared := 1;
         else
            Compared := 0;
         end if;
         return (if Self.Reverse_Last then -Compared else Compared);
      end if;
      for K in 1 .. Natural (Self.Rules.Length) loop
         if Self.Range_Keys.Element (K) then
            Compared := Compare_Ranges
              (Left.Text, Left.Ranges.Element (K),
               Right.Text, Right.Ranges.Element (K));
            if Self.Rules.Element (K).Reverse_Order then
               Compared := -Compared;
            end if;
         else
            Compared := Posix_Tools.Commands.Sort_Keys.Comparison.Compare_Key_Texts
              (Left.Keys.Element (K), Right.Keys.Element (K),
               Self.Rules.Element (K));
         end if;
         if Compared /= 0 then
            return Compared;
         end if;
      end loop;
      if not Self.Last_Resort then
         return 0;
      end if;
      if Self.Use_Whole then
         Compared :=
           (if Left.Whole < Right.Whole then -1
            elsif Left.Whole > Right.Whole then 1
            else 0);
         if Compared /= 0 then
            return (if Self.Reverse_Last then -Compared else Compared);
         end if;
      end if;
      Compared :=
        (if Left.Text < Right.Text then -1
         elsif Left.Text > Right.Text then 1
         else 0);
      return (if Self.Reverse_Last then -Compared else Compared);
   end Compare;

   procedure Initialize (Self : out Comparator; Options : Sort_Options) is
      Plain  : constant Ordering_Rules :=
        (Reverse_Order => Options.Global.Reverse_Order, others => False);
      Locale : constant String := To_String (Options.Locale);
   begin
      Self := (Options => Options, others => <>);
      Self.Whole_Line := Options.Keys.Is_Empty;
      if Self.Whole_Line then
         Self.Rules.Append (Options.Global);
         Self.Range_Keys.Append
           (Posix_Tools.Commands.Sort_Keys.Comparison.Uses_Key_Range
              (Options.Global, Options));
      else
         for Key of Options.Keys loop
            declare
               Rules : constant Ordering_Rules :=
                 Posix_Tools.Commands.Sort_Keys.Comparison.Effective_Rules
                   (Key, Options.Global);
            begin
               Self.Rules.Append (Rules);
               Self.Range_Keys.Append
                 (Posix_Tools.Commands.Sort_Keys.Comparison.Uses_Key_Range
                    (Rules, Options));
            end;
         end loop;
      end if;
      Self.Last_Resort := not (Options.Stable_Sort or else Options.Unique);
      Self.Reverse_Last := Options.Global.Reverse_Order;
      Self.Direct_Text_Key :=
        Self.Whole_Line
        and then Options.Global = Plain
        and then Posix_Tools.Commands.Text_Helpers.Collation.Is_Byte_Collation_Locale (Locale);
      Self.Use_Whole :=
        Self.Last_Resort
        and then not Posix_Tools.Commands.Text_Helpers.Collation.Is_Byte_Collation_Locale (Locale)
        and then not (Self.Whole_Line and then Options.Global = Plain);
   end Initialize;

   function Uses_Direct_Text_Key (Self : Comparator) return Boolean is
     (Self.Direct_Text_Key);

   function Keys_Equal
     (Self : Comparator; Left, Right : Prepared_Line) return Boolean is
   begin
      if Self.Direct_Text_Key then
         return Left.Text = Right.Text;
      end if;
      for K in 1 .. Natural (Self.Rules.Length) loop
         if Self.Range_Keys.Element (K) then
            if Compare_Ranges
              (Left.Text, Left.Ranges.Element (K),
               Right.Text, Right.Ranges.Element (K)) /= 0
            then
               return False;
            end if;
         elsif Posix_Tools.Commands.Sort_Keys.Comparison.Compare_Key_Texts
           (Left.Keys.Element (K), Right.Keys.Element (K),
            Self.Rules.Element (K)) /= 0
         then
            return False;
         end if;
      end loop;
      return True;
   end Keys_Equal;

   function Original (Line : Prepared_Line) return String is
     (To_String (Line.Text));

   function Original_Length (Line : Prepared_Line) return Natural is
     (Length (Line.Text));

   function Original_Slice
     (Line : Prepared_Line;
      Low  : Positive;
      High : Natural) return String is
     (Slice (Line.Text, Low, High));

   function Prepare_Line (Self : Comparator; Line : String) return Prepared_Line is
      Locale : constant String := To_String (Self.Options.Locale);
   begin
      return Item : Prepared_Line do
         Item.Text := To_Unbounded_String (Line);
         if not Self.Direct_Text_Key then
            for K in 1 .. Natural (Self.Rules.Length) loop
               if Self.Range_Keys.Element (K) then
                  Item.Keys.Append ("");
                  Item.Ranges.Append
                    (Posix_Tools.Commands.Sort_Keys.Comparison.Key_Range
                       (Line,
                        (if Self.Whole_Line then (others => <>)
                         else Self.Options.Keys.Element (K)),
                        Self.Rules.Element (K), Self.Options,
                        Self.Whole_Line));
               else
                  Item.Keys.Append
                    (Posix_Tools.Commands.Sort_Keys.Comparison.Key_Text
                       (Line,
                        (if Self.Whole_Line then (others => <>)
                         else Self.Options.Keys.Element (K)),
                        Self.Rules.Element (K), Self.Options,
                        Self.Whole_Line));
                  Item.Ranges.Append
                    (Posix_Tools.Commands.Sort_Key_Text.Key_Range'
                       (First => 1, Last => 0));
               end if;
            end loop;
            if Self.Use_Whole then
               Item.Whole := To_Unbounded_String
                 (Posix_Tools.Commands.Text_Helpers.Collation.Locale_Sort_Text (Locale, Line));
            end if;
         end if;
      end return;
   end Prepare_Line;

   function Prepare_Line
     (Self : Comparator;
      Line : Unbounded_String) return Prepared_Line
   is
   begin
      if not Self.Direct_Text_Key then
         return Prepare_Line (Self, To_String (Line));
      end if;
      return Item : Prepared_Line do
         Item.Text := Line;
      end return;
   end Prepare_Line;

   function Estimated_Storage_Size
     (Self : Comparator;
      Line : String) return Posix_Tools.Numbers.Count
   is
      Total : Posix_Tools.Numbers.Count :=
        Posix_Tools.Numbers.Count (Line'Length) + 64;

      procedure Add_Saturated (Amount : Posix_Tools.Numbers.Count) is
      begin
         if Amount > Posix_Tools.Numbers.Count'Last - Total then
            Total := Posix_Tools.Numbers.Count'Last;
         else
            Total := Total + Amount;
         end if;
      end Add_Saturated;

      --  Key preparation can be expensive (notably for locale and numeric
      --  keys), so the spill accounting deliberately estimates its peak
      --  storage without constructing a second, immediately discarded key.
      Expanded_Key : constant Posix_Tools.Numbers.Count :=
        Posix_Tools.Numbers.Count (Line'Length) * 16 + 128;
   begin
      if not Self.Direct_Text_Key then
         for K in 1 .. Natural (Self.Rules.Length) loop
            Add_Saturated
              (if Self.Range_Keys.Element (K) then 32 else Expanded_Key);
         end loop;
         if Self.Use_Whole then
            Add_Saturated (Expanded_Key);
         end if;
      end if;
      return Total;
   end Estimated_Storage_Size;

   function Compare_Keys
     (Data        : Prepared_Lines;
      Lines       : Posix_Tools.Streams.Lines.Segment_Vector;
      Left, Right : Positive) return Integer
   is
      Left_Base  : constant Natural := (Left - 1) * Data.Key_Count;
      Right_Base : constant Natural := (Right - 1) * Data.Key_Count;
      Compared   : Integer;
   begin
      for K in 1 .. Data.Key_Count loop
         if Data.Range_Keys.Element (K) then
            Compared := Compare_Ranges
              (Lines (Left), Data.Ranges.Element (Left_Base + K),
               Lines (Right), Data.Ranges.Element (Right_Base + K));
            if Data.Rules (K).Reverse_Order then
               Compared := -Compared;
            end if;
         else
            Compared :=
              Posix_Tools.Commands.Sort_Keys.Comparison.Compare_Key_Texts
                (Data.Keys (Left_Base + K), Data.Keys (Right_Base + K),
                 Data.Rules (K));
         end if;
         if Compared /= 0 then
            return Compared;
         end if;
      end loop;
      return 0;
   end Compare_Keys;

   --  POSIX sort: "Except when the -u option is specified, lines that
   --  otherwise compare equal shall be ordered as if none of the options -d,
   --  -f, -i, -n, or -k were present (but with -r still in effect, if it was
   --  specified) and with all bytes in the lines significant to the
   --  comparison." -s (an extension) leaves equal lines in input order.
   function Compare_Lines
     (Data        : Prepared_Lines;
      Lines       : Posix_Tools.Streams.Lines.Segment_Vector;
      Left, Right : Positive) return Integer
   is
      Compared : Integer;
   begin
      if Data.Direct_Text_Key then
         if Lines (Left) < Lines (Right) then
            Compared := -1;
         elsif Lines (Left) > Lines (Right) then
            Compared := 1;
         else
            Compared := 0;
         end if;
         return (if Data.Reverse_Last then -Compared else Compared);
      end if;
      Compared := Compare_Keys (Data, Lines, Left, Right);
      if Compared /= 0 or else not Data.Last_Resort then
         return Compared;
      end if;

      if Data.Use_Whole then
         Compared :=
           Posix_Tools.Commands.Sort_Keys.Comparison.Compare_Bytes (Data.Whole (Left), Data.Whole (Right));
      end if;
      if Compared = 0 then
         Compared := Posix_Tools.Commands.Sort_Keys.Comparison.Compare_Bytes (Lines (Left), Lines (Right));
      end if;
      return (if Data.Reverse_Last then -Compared else Compared);
   end Compare_Lines;

   function First_Disorder
     (Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options) return Natural
   is
   begin
      if Lines.Length < 2 then
         return 0;
      end if;

      declare
         Data : constant Prepared_Lines := Prepare (Lines, Options);
      begin
         for I in 1 .. Natural (Lines.Length) - 1 loop
            declare
               Compared : constant Integer := Compare_Lines (Data, Lines, I, I + 1);
            begin
               if Compared > 0 or else (Options.Unique and then Compared = 0) then
                  return I + 1;
               end if;
            end;
         end loop;
      end;
      return 0;
   end First_Disorder;

   function Prepare
     (Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options) return Prepared_Lines
   is
      Whole_Line : constant Boolean := Options.Keys.Is_Empty;
      Key_Count  : constant Positive := (if Whole_Line then 1 else Natural (Options.Keys.Length));
      Plain      : constant Ordering_Rules := (Reverse_Order => Options.Global.Reverse_Order, others => False);
      Locale     : constant String := To_String (Options.Locale);
   begin
      return Data : Prepared_Lines (Key_Count) do
         for K in 1 .. Key_Count loop
            Data.Rules (K) :=
              (if Whole_Line then Options.Global
               else Posix_Tools.Commands.Sort_Keys.Comparison.Effective_Rules
                 (Options.Keys.Element (K), Options.Global));
            Data.Range_Keys.Append
              (Posix_Tools.Commands.Sort_Keys.Comparison.Uses_Key_Range
                 (Data.Rules (K), Options));
         end loop;

         Data.Last_Resort := not (Options.Stable_Sort or else Options.Unique);
         Data.Reverse_Last := Options.Global.Reverse_Order;
         Data.Direct_Text_Key :=
           Whole_Line
           and then Options.Global = Plain
           and then Posix_Tools.Commands.Text_Helpers.Collation.Is_Byte_Collation_Locale (Locale);
         --  The last resort compares whole lines in the locale's collation
         --  first; without -k and ordering options the key already did.
         Data.Use_Whole :=
           Data.Last_Resort
           and then not Posix_Tools.Commands.Text_Helpers.Collation.Is_Byte_Collation_Locale (Locale)
           and then not (Whole_Line and then Options.Global = Plain);

         if not Data.Direct_Text_Key then
            Data.Keys.Reserve_Capacity (Lines.Length * Ada.Containers.Count_Type (Key_Count));
            Data.Ranges.Reserve_Capacity
              (Lines.Length * Ada.Containers.Count_Type (Key_Count));
            for Line of Lines loop
               for K in 1 .. Key_Count loop
                  if Data.Range_Keys.Element (K) then
                     Data.Keys.Append ("");
                     Data.Ranges.Append
                       (Posix_Tools.Commands.Sort_Keys.Comparison.Key_Range
                          (Line,
                           (if Whole_Line then (others => <>)
                            else Options.Keys.Element (K)),
                           Data.Rules (K), Options, Whole_Line));
                  else
                     Data.Keys.Append
                       (Posix_Tools.Commands.Sort_Keys.Comparison.Key_Text
                          (Line,
                           (if Whole_Line then (others => <>)
                            else Options.Keys.Element (K)),
                           Data.Rules (K), Options, Whole_Line));
                     Data.Ranges.Append
                       (Posix_Tools.Commands.Sort_Key_Text.Key_Range'
                          (First => 1, Last => 0));
                  end if;
               end loop;
               if Data.Use_Whole then
                  Data.Whole.Append
                    (Posix_Tools.Commands.Text_Helpers.Collation.Locale_Sort_Text (Locale, Line));
               end if;
            end loop;
         end if;
      end return;
   end Prepare;

   procedure Sort_Lines
     (Lines   : in out Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options)
   is
      Count : constant Natural := Natural (Lines.Length);

      function Direct_Before (Left, Right : String) return Boolean is
        (if Options.Global.Reverse_Order then Left > Right else Left < Right);

      package Direct_Sorting is new Segment_Vectors.Generic_Sorting (Direct_Before);
   begin
      if Count < 2 then
         return;
      end if;

      declare
         Data    : constant Prepared_Lines := Prepare (Lines, Options);
         Order   : Index_Array_Access := null;
         Scratch : Index_Array_Access := null;
         Sorted  : Posix_Tools.Streams.Lines.Segment_Vector;
         Kept    : Natural := 0;

         --  Top-down merge sort. Taking the left item on ties keeps it stable.
         procedure Merge_Sort (First, Last : Positive);

         procedure Merge_Sort (First, Last : Positive) is
            Middle : Positive;
            Left   : Positive;
            Right  : Positive;
            Target : Positive := First;
         begin
            if First >= Last then
               return;
            end if;

            Middle := First + (Last - First) / 2;
            Merge_Sort (First, Middle);
            Merge_Sort (Middle + 1, Last);
            if Compare_Lines (Data, Lines, Order (Middle), Order (Middle + 1)) <= 0 then
               return;
            end if;

            Scratch (First .. Last) := Order (First .. Last);
            Left := First;
            Right := Middle + 1;
            while Left <= Middle and then Right <= Last loop
               if Compare_Lines (Data, Lines, Scratch (Right), Scratch (Left)) < 0 then
                  Order (Target) := Scratch (Right);
                  Right := Right + 1;
               else
                  Order (Target) := Scratch (Left);
                  Left := Left + 1;
               end if;
               Target := Target + 1;
            end loop;
            if Left <= Middle then
               Order (Target .. Last) := Scratch (Left .. Middle);
            elsif Right <= Last then
               Order (Target .. Last) := Scratch (Right .. Last);
            end if;
         end Merge_Sort;
      begin
         if Data.Direct_Text_Key then
            Direct_Sorting.Sort (Lines);
            if Options.Unique then
               declare
                  Kept : Positive := 1;
               begin
                  for I in 2 .. Count loop
                     if Lines (I) /= Lines (Kept) then
                        Kept := Kept + 1;
                        if Kept /= I then
                           declare
                              Item : constant String := Lines (I);
                           begin
                              Lines.Replace_Element (Kept, Item);
                           end;
                        end if;
                     end if;
                  end loop;
                  Lines.Set_Length (Ada.Containers.Count_Type (Kept));
               end;
            end if;
            return;
         end if;

         Order := new Index_Array (1 .. Count);
         Scratch := new Index_Array (1 .. Count);
         for I in Order'Range loop
            Order (I) := I;
         end loop;
         Merge_Sort (1, Count);

         Sorted.Reserve_Capacity (Lines.Length);
         for I in Order'Range loop
            if not Options.Unique
              or else Kept = 0
              or else
                (if Data.Direct_Text_Key
                 then Lines (Kept) /= Lines (Order (I))
                 else Compare_Keys (Data, Lines, Kept, Order (I)) /= 0)
            then
               Sorted.Append (Lines (Order (I)));
               Kept := Order (I);
            end if;
         end loop;
         Free (Order);
         Free (Scratch);
         Lines.Move (Sorted);
      exception
         when others =>
            Free (Order);
            Free (Scratch);
            raise;
      end;
   end Sort_Lines;
end Posix_Tools.Commands.Sort_Keys;
