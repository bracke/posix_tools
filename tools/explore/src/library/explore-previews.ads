with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Explore.Images;

--  What the preview pane shows of a file: its first lines when it is text, a
--  hex dump of its first bytes when it is not, or the image when it is a
--  PNG, JPEG, or GIF. Previews are built away from the screen from a bounded read of the
--  file, so a large or slow file never holds the keyboard up.
package Explore.Previews is
   package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   type Preview_Kind is (No_Preview, Text_Preview, Binary_Preview, Image_Preview, Unreadable_Preview);

   type Preview is record
      Kind        : Preview_Kind := No_Preview;
      Path        : Ada.Strings.Unbounded.Unbounded_String;
      --  What the file is, as the file command describes it.
      Description : Ada.Strings.Unbounded.Unbounded_String;
      Lines       : Line_Vectors.Vector;
      --  The image data, its encoding, and its size in pixels, for an image.
      Image       : Ada.Strings.Unbounded.Unbounded_String;
      Format      : Explore.Images.Image_Format := Explore.Images.PNG_Format;
      Width       : Natural := 0;
      Height      : Natural := 0;
      --  The file's modification time and size when it was read, which
      --  together with its path tell one version of an image from another.
      Modified    : Long_Long_Integer := 0;
      File_Size   : Long_Long_Integer := 0;
      Generation  : Natural := 0;
   end record;

   --  How much of a file a preview reads, and the largest image it sends.
   Head_Bytes  : constant := 64 * 1024;
   Image_Bytes : constant := 16 * 1024 * 1024;
   Max_Lines   : constant := 500;

   --  Build the preview of the file at Path.
   function Build (Path : String) return Preview;

   --  The hex dump line for Data, at Offset into the file: the offset, up to
   --  sixteen bytes in hex, and those bytes as text.
   function Hex_Line (Data : String; Offset : Natural) return String;

   protected type Board is
      --  Ask for the preview of Path, replacing any earlier request.
      procedure Submit (Path : String; Generation : Natural);
      function Is_Wanted (Generation : Natural) return Boolean;
      procedure Collect (Result : out Preview; Found : out Boolean);
      function Busy return Boolean;
      procedure Shut_Down;

      entry Take (Path : out Ada.Strings.Unbounded.Unbounded_String; Generation : out Natural; Closed : out Boolean);
      procedure Finish (Result : Preview);
   private
      Wanted_Path : Ada.Strings.Unbounded.Unbounded_String;
      Wanted      : Natural := 0;
      Waiting     : Boolean := False;
      Running     : Boolean := False;
      Ready       : Boolean := False;
      Done        : Preview;
      Closed      : Boolean := False;
   end Board;

   task type Worker (Jobs : not null access Board);
end Explore.Previews;
