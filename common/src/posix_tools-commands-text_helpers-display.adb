with Posix_Tools.Text.UTF_8;

package body Posix_Tools.Commands.Text_Helpers.Display is
   use type Posix_Tools.Text.UTF_8.Decode_Status;

   BS : constant Character := Character'Val (8);
   CR : constant Character := Character'Val (13);

   function Display_Width (Code_Point : Long_Long_Integer) return Natural;
   function Is_Combining_Code_Point (Code_Point : Long_Long_Integer) return Boolean;
   function Is_Wide_Code_Point (Code_Point : Long_Long_Integer) return Boolean;

   function Display_Next_Column
     (Text     : String;
      Index    : Positive;
      Column   : Natural;
      Consumed : out Natural) return Natural
   is
      Decoder    : Posix_Tools.Text.UTF_8.Decoder;
      Status     : Posix_Tools.Text.UTF_8.Decode_Status;
      Code_Point : Long_Long_Integer := 0;
   begin
      Consumed := 1;
      if Text (Index) = BS then
         return (if Column = 0 then 0 else Column - 1);
      elsif Text (Index) = CR then
         return 0;
      elsif Character'Pos (Text (Index)) <= 16#7F# then
         return Column + 1;
      end if;

      for I in Index .. Text'Last loop
         Posix_Tools.Text.UTF_8.Decode (Decoder, Character'Pos (Text (I)), Status, Code_Point);
         if Status = Posix_Tools.Text.UTF_8.Complete then
            Consumed := I - Index + 1;
            return Column + Display_Width (Code_Point);
         elsif Status = Posix_Tools.Text.UTF_8.Invalid then
            Consumed := 1;
            return Column + 1;
         end if;
      end loop;

      return Column + 1;
   end Display_Next_Column;

   function Display_Width (Code_Point : Long_Long_Integer) return Natural is
   begin
      if Is_Combining_Code_Point (Code_Point) then
         return 0;
      elsif Is_Wide_Code_Point (Code_Point) then
         return 2;
      else
         return 1;
      end if;
   end Display_Width;

   function Is_Combining_Code_Point (Code_Point : Long_Long_Integer) return Boolean is
   begin
      return Code_Point in 16#0300# .. 16#036F#
        or else Code_Point in 16#1AB0# .. 16#1AFF#
        or else Code_Point in 16#1DC0# .. 16#1DFF#
        or else Code_Point in 16#20D0# .. 16#20FF#
        or else Code_Point in 16#FE00# .. 16#FE0F#
        or else Code_Point in 16#FE20# .. 16#FE2F#
        or else Code_Point = 16#200D#;
   end Is_Combining_Code_Point;

   function Is_Wide_Code_Point (Code_Point : Long_Long_Integer) return Boolean is
   begin
      return Code_Point in 16#1100# .. 16#115F#
        or else Code_Point in 16#2329# .. 16#232A#
        or else Code_Point in 16#2E80# .. 16#A4CF#
        or else Code_Point in 16#AC00# .. 16#D7A3#
        or else Code_Point in 16#F900# .. 16#FAFF#
        or else Code_Point in 16#FE10# .. 16#FE19#
        or else Code_Point in 16#FE30# .. 16#FE6F#
        or else Code_Point in 16#FF00# .. 16#FF60#
        or else Code_Point in 16#FFE0# .. 16#FFE6#
        or else Code_Point in 16#1F300# .. 16#1FAFF#;
   end Is_Wide_Code_Point;
end Posix_Tools.Commands.Text_Helpers.Display;
