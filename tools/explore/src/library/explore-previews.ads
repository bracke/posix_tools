with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Explore.Images;
with Explore.Syntax;

--  What the preview pane shows of a file: its first lines when it is text,
--  coloured by its language; its members when it is an archive; the image
--  when it is a PNG, JPEG, or GIF, or a thumbnail of a PDF or a video; and a
--  hex dump of its first bytes otherwise. Previews are built away from the
--  screen from a bounded read of the file, so a large or slow file never
--  holds the keyboard up.
package Explore.Previews is
   package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   type Preview_Kind is
     (No_Preview, Text_Preview, Binary_Preview, Archive_Preview, Image_Preview, Unreadable_Preview);

   type Preview is record
      Kind        : Preview_Kind := No_Preview;
      Path        : Ada.Strings.Unbounded.Unbounded_String;
      --  What the file is, as the file command describes it.
      Description : Ada.Strings.Unbounded.Unbounded_String;
      --  Text lines, dump lines, or one line per archive member.
      Lines       : Line_Vectors.Vector;
      --  The language a text preview is coloured as.
      Language    : Explore.Syntax.Language := Explore.Syntax.No_Language;
      --  The image is a thumbnail made of the file, not the file itself.
      Thumbnail   : Boolean := False;
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

   --  A previewer of the user's own: a command line for /bin/sh, run with
   --  the file as "$1", whose output is shown as the preview of a file whose
   --  name one of Patterns matches, case ignored.
   type Preview_Rule is record
      Patterns : Line_Vectors.Vector;
      Run      : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   package Rule_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, Preview_Rule);

   --  Build the preview of the file at Path. A file one of Rules matches is
   --  shown as that rule's command prints it, when it prints anything. With
   --  a Thumbnail_Directory, which rules also write their output to, and
   --  Thumbnails, a PDF's first page and a video's first second are made
   --  into a PNG there by pdftoppm and ffmpeg, where they are installed, and
   --  shown as images.
   function Build
     (Path                : String;
      Thumbnail_Directory : String := "";
      Rules               : Rule_Vectors.Vector := Rule_Vectors.Empty_Vector;
      Thumbnails          : Boolean := True) return Preview;

   --  At most Limit bytes from the start of the file at Path.
   procedure Read_Head
     (Path  : String;
      Limit : Positive;
      Data  : out Ada.Strings.Unbounded.Unbounded_String;
      Ok    : out Boolean);

   --  Whether Data, the start of a file, is text: what is previewed as text,
   --  and opened in an editor.
   function Is_Text (Data : String) return Boolean;

   --  Text a program printed, with its terminal control sequences taken out
   --  and any other control character but tab and line feed dropped.
   function Without_Controls (Text : String) return String;

   --  Whether Name has the extension of a video ffmpeg can take a frame of.
   function Is_Video (Name : String) return Boolean;

   --  How long a thumbnailer is given, in milliseconds.
   Thumbnail_Timeout_Ms : constant := 10_000;

   --  The hex dump line for Data, at Offset into the file: the offset, up to
   --  sixteen bytes in hex, and those bytes as text.
   function Hex_Line (Data : String; Offset : Natural) return String;

   protected type Board is
      --  The previewers and whether thumbnails are made, for every preview
      --  from now on.
      procedure Configure (Rules : Rule_Vectors.Vector; Thumbnails : Boolean);
      function Configured_Rules return Rule_Vectors.Vector;
      function Thumbnails_Wanted return Boolean;

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
      Rules       : Rule_Vectors.Vector;
      Thumbnails  : Boolean := True;
   end Board;

   task type Worker (Jobs : not null access Board);
end Explore.Previews;
