with Ada.Strings.Unbounded;
with Explore.Images;

--  The images the terminal holds, kept so that showing one again needs no
--  second transfer. The cache only decides: what it returns is the text that
--  brings the terminal in line with it, for the caller to write.
--
--  It keeps at most Slots images and, as far as freeing others allows, at
--  most Byte_Limit bytes of them, freeing the least recently shown first.
package Explore.Image_Cache is
   Slots : constant := 8;

   Default_Byte_Limit : constant := 32 * 1024 * 1024;

   --  Which file an image is of, as it was when it was read: a file changed
   --  since is another image.
   type Image_Key is record
      Path     : Ada.Strings.Unbounded.Unbounded_String;
      Modified : Long_Long_Integer := 0;
      Size     : Long_Long_Integer := 0;
   end record;

   type Cache (Byte_Limit : Natural := Default_Byte_Limit) is private;

   --  Show the image Key names, Data in Format, across Columns by Rows cells,
   --  as image Id. The text returned frees what had to go to make room and
   --  sends the image; for an image already held it only places it again,
   --  and only when its size changed, and it is empty otherwise.
   function Show
     (Self    : in out Cache;
      Key     : Image_Key;
      Format  : Explore.Images.Image_Format;
      Data    : Ada.Strings.Unbounded.Unbounded_String;
      Columns : Positive;
      Rows    : Positive;
      In_Tmux : Boolean;
      Id      : out Positive) return String;

   --  Forget every image, as once the terminal's screen was someone else's
   --  and its images may be gone.
   procedure Clear (Self : in out Cache);

   --  How many images are held, and their bytes.
   function Count (Self : Cache) return Natural;
   function Bytes (Self : Cache) return Natural;

private
   --  An empty slot has Id zero.
   type Cached_Image is record
      Key     : Image_Key;
      Id      : Natural range 0 .. 255 := 0;
      Columns : Natural := 0;
      Rows    : Natural := 0;
      Bytes   : Natural := 0;
      --  When it was last shown, for freeing the least recently shown.
      Used    : Natural := 0;
   end record;

   type Slot_Array is array (1 .. Slots) of Cached_Image;

   type Cache (Byte_Limit : Natural := Default_Byte_Limit) is record
      Images : Slot_Array;
      Clock  : Natural := 0;
   end record;
end Explore.Image_Cache;
