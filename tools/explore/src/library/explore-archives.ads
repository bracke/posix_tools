with Explore.Model;

--  What an archive holds, for the preview pane: one line per member, its size
--  and its path inside the archive. ZIP, 7z, ar, cpio, ISO 9660, and RAR are
--  listed through zlib from their own catalogues; tar, plain or gzip
--  compressed, through tarlib.
package Explore.Archives is
   --  Whether Head, the start of a file, is an archive this package lists.
   function Is_Archive (Head : String) return Boolean;

   --  The members of the archive at Path, at most Limit of them; Ok is False
   --  when it cannot be read.
   procedure List
     (Path  : String;
      Head  : String;
      Limit : Positive;
      Lines : out Explore.Model.Path_Vectors.Vector;
      Ok    : out Boolean);

   --  The largest tar, plain or compressed, that is read into memory to be
   --  listed, and the most a compressed one is inflated to: the members at
   --  the start of a larger one are listed.
   Max_Read_Bytes     : constant := 64 * 1024 * 1024;
   Max_Inflated_Bytes : constant := 64 * 1024 * 1024;
end Explore.Archives;
