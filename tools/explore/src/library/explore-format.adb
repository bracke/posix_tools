with Ada.Calendar.Formatting;
with Ada.Calendar.Time_Zones;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Numeric_Images;

package body Explore.Format is
   package Listing renames Posix_Tools.File_Operations.Listing;

   function Image (Value : Long_Long_Integer) return String
     renames Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image;

   function Mode_Image (Item : Listing.Listed_Entry) return String is
      Kind : constant Character :=
        (if Item.Is_Link then 'l'
         else
           (case Item.Kind is
              when Listing.Directory_Entry => 'd',
              when Listing.Regular_Entry => '-',
              when Listing.FIFO_Entry => 'p',
              when Listing.Character_Device_Entry => 'c',
              when Listing.Block_Device_Entry => 'b',
              when Listing.Socket_Entry => 's',
              when Listing.Other_Entry | Listing.Missing_Entry => '?'));
   begin
      if not Item.Status.Available then
         return Kind & "?????????";
      end if;

      return Kind & Posix_Tools.Text.File_Modes.Permission_Image (Item.Status.Mode mod 8#10000#);
   end Mode_Image;

   function Size_Image (Bytes : Long_Long_Integer) return String is
      Units : constant String := "KMGTPE";
      Value : Long_Long_Integer := Bytes;
      Unit  : Natural := 0;
      Tenths : Long_Long_Integer;
   begin
      if Bytes < 1024 then
         return Image (Bytes);
      end if;

      --  Scale down until the whole part has at most three digits, keeping
      --  the tenths of the last step.
      loop
         Tenths := (Value mod 1024) * 10 / 1024;
         Value := Value / 1024;
         Unit := Unit + 1;
         exit when Value < 1024 or else Unit = Units'Length;
      end loop;

      if Value < 10 then
         return Image (Value) & "." & Image (Tenths) & Units (Unit);
      else
         return Image (Value) & Units (Unit);
      end if;
   end Size_Image;

   function Time_Image (Seconds : Long_Long_Integer) return String is
      use type Ada.Calendar.Time;

      Epoch : constant Ada.Calendar.Time := Ada.Calendar.Formatting.Time_Of (1970, 1, 1, 0.0);
   begin
      declare
         Moment : constant Ada.Calendar.Time := Epoch + Duration (Seconds);
         Text   : constant String :=
           Ada.Calendar.Formatting.Image
             (Moment, Time_Zone => Ada.Calendar.Time_Zones.UTC_Time_Offset (Moment));
      begin
         --  "YYYY-MM-DD HH:MM:SS" without its seconds.
         return Text (Text'First .. Text'First + 15);
      end;
   exception
      when others =>
         return "????-??-?? ??:??";
   end Time_Image;
end Explore.Format;
