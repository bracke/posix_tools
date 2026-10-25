with Ada.Containers;
with Ada.Unchecked_Deallocation;
with Posix_Tools.Commands.Sort_Keys.Comparison;
with Posix_Tools.Commands.Text_Helpers;

package body Posix_Tools.Commands.Sort_Keys is
   use Ada.Strings.Unbounded;
   use type Ada.Containers.Count_Type;

   package Segment_Vectors renames Posix_Tools.Streams.Lines.Segment_Vectors;

   type Rules_Array is array (Positive range <>) of Ordering_Rules;

   type Index_Array is array (Positive range <>) of Positive;
   type Index_Array_Access is access Index_Array;

   --  Every line's comparison keys, built once. Key K of line L is
   --  Keys ((L - 1) * Key_Count + K).
   type Prepared_Lines (Key_Count : Positive) is record
      Rules        : Rules_Array (1 .. Key_Count);
      Keys         : Segment_Vectors.Vector;
      Whole        : Segment_Vectors.Vector;
      Use_Whole    : Boolean := False;
      Last_Resort  : Boolean := True;
      Reverse_Last : Boolean := False;
   end record;

   function Compare_Keys (Data : Prepared_Lines; Left, Right : Positive) return Integer;

   function Compare_Lines
     (Data        : Prepared_Lines;
      Lines       : Posix_Tools.Streams.Lines.Segment_Vector;
      Left, Right : Positive) return Integer;

   procedure Free is new Ada.Unchecked_Deallocation (Index_Array, Index_Array_Access);

   function Prepare
     (Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options) return Prepared_Lines;

   function Compare_Keys (Data : Prepared_Lines; Left, Right : Positive) return Integer is
      Left_Base  : constant Natural := (Left - 1) * Data.Key_Count;
      Right_Base : constant Natural := (Right - 1) * Data.Key_Count;
      Compared   : Integer;
   begin
      for K in 1 .. Data.Key_Count loop
         Compared :=
           Posix_Tools.Commands.Sort_Keys.Comparison.Compare_Key_Texts
             (Data.Keys (Left_Base + K), Data.Keys (Right_Base + K), Data.Rules (K));
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
      Compared : Integer := Compare_Keys (Data, Left, Right);
   begin
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

   function Lines_Are_Sorted
     (Lines   : Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options) return Boolean
   is
   begin
      if Lines.Length < 2 then
         return True;
      end if;

      declare
         Data : constant Prepared_Lines := Prepare (Lines, Options);
      begin
         for I in 1 .. Natural (Lines.Length) - 1 loop
            declare
               Compared : constant Integer := Compare_Lines (Data, Lines, I, I + 1);
            begin
               if Compared > 0 or else (Options.Unique and then Compared = 0) then
                  return False;
               end if;
            end;
         end loop;
      end;
      return True;
   end Lines_Are_Sorted;

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
         end loop;

         Data.Last_Resort := not (Options.Stable_Sort or else Options.Unique);
         Data.Reverse_Last := Options.Global.Reverse_Order;
         --  The last resort compares whole lines in the locale's collation
         --  first; without -k and ordering options the key already did.
         Data.Use_Whole :=
           Data.Last_Resort
           and then not Posix_Tools.Commands.Text_Helpers.Is_Byte_Collation_Locale (Locale)
           and then not (Whole_Line and then Options.Global = Plain);

         Data.Keys.Reserve_Capacity (Lines.Length * Ada.Containers.Count_Type (Key_Count));
         for Line of Lines loop
            for K in 1 .. Key_Count loop
               Data.Keys.Append
                 (Posix_Tools.Commands.Sort_Keys.Comparison.Key_Text
                    (Line,
                     (if Whole_Line then (others => <>) else Options.Keys.Element (K)),
                     Data.Rules (K),
                     Options,
                     Whole_Line));
            end loop;
            if Data.Use_Whole then
               Data.Whole.Append (Posix_Tools.Commands.Text_Helpers.Locale_Sort_Text (Locale, Line));
            end if;
         end loop;
      end return;
   end Prepare;

   procedure Sort_Lines
     (Lines   : in out Posix_Tools.Streams.Lines.Segment_Vector;
      Options : Sort_Options)
   is
      Count : constant Natural := Natural (Lines.Length);
   begin
      if Count < 2 then
         return;
      end if;

      declare
         Data    : constant Prepared_Lines := Prepare (Lines, Options);
         Order   : Index_Array_Access := new Index_Array (1 .. Count);
         Scratch : Index_Array_Access := new Index_Array (1 .. Count);
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
         for I in Order'Range loop
            Order (I) := I;
         end loop;
         Merge_Sort (1, Count);

         Sorted.Reserve_Capacity (Lines.Length);
         for I in Order'Range loop
            if not Options.Unique
              or else Kept = 0
              or else Compare_Keys (Data, Kept, Order (I)) /= 0
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
