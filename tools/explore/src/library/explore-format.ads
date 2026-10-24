with Posix_Tools.File_Operations.Listing;

--  How explore writes sizes, times, and modes on screen.
package Explore.Format is
   --  A size in bytes, shortened to at most five characters with binary
   --  units: "512", "1.5K", "20M".
   function Size_Image (Bytes : Long_Long_Integer) return String;

   --  A whole number in full, without a sign for positive ones.
   function Count_Image (Value : Long_Long_Integer) return String;

   --  A time in seconds since 1970-01-01 UTC, as local "YYYY-MM-DD HH:MM".
   function Time_Image (Seconds : Long_Long_Integer) return String;

   --  The ten characters ls -l starts a line with: the kind, then the
   --  permissions.
   function Mode_Image (Item : Posix_Tools.File_Operations.Listing.Listed_Entry) return String;
end Explore.Format;
