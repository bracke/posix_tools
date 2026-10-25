--  The configuration and bookmarks files: reading them, and writing the
--  bookmarks, with what they hold read and written by Explore.Settings.
package Explore.Settings.Storage is
   --  Read the configuration file at Path. A file that does not exist is
   --  no configuration, and no problem.
   procedure Load (Path : String; Into : out Settings; Problems : out Problem_Vectors.Vector);

   --  Read and write the bookmarks file, making its directory if needed.
   function Read_Bookmarks (Path : String) return Bookmark_Maps.Map;
   procedure Write_Bookmarks (Path : String; Marks : Bookmark_Maps.Map; Ok : out Boolean);
end Explore.Settings.Storage;
