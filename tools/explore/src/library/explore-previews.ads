with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded;
with Explore.Images;
with Explore.String_Vectors;
with Explore.Syntax;
with Explore.Work_Boards;

--  What the preview pane shows of a file: its first lines when it is text,
--  coloured by its language; its members when it is an archive; the image
--  when it is a PNG, JPEG, or GIF, or a thumbnail of a PDF or a video; and a
--  hex dump of its first bytes otherwise. Previews are built away from the
--  screen from a bounded read of the file, so a large or slow file never
--  holds the keyboard up.
package Explore.Previews is

   type Preview_Kind is
     (No_Preview, Text_Preview, Binary_Preview, Archive_Preview, Image_Preview, Unreadable_Preview);

   type Preview is record
      Kind        : Preview_Kind := No_Preview;
      Path        : Ada.Strings.Unbounded.Unbounded_String;
      --  What the file is, as the file command describes it.
      Description : Ada.Strings.Unbounded.Unbounded_String;
      --  Text lines, dump lines, or one line per archive member.
      Lines       : Explore.String_Vectors.Vector;
      --  The language a text preview is coloured as.
      Language    : Explore.Syntax.Language := Explore.Syntax.No_Language;
      --  The coloured runs of each of Lines in that language, worked out
      --  once here so that drawing the preview does not tokenize it again.
      --  Lines past the last of them have none.
      Spans       : Explore.Syntax.Line_Span_Vectors.Vector;
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
      Patterns : Explore.String_Vectors.Vector;
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

   --  Whether Data, the start of a file, is text: what is previewed as text,
   --  and opened in an editor.
   function Is_Text (Data : String) return Boolean;

   --  Text a program printed, with its terminal control sequences taken out
   --  and any other control character but tab and line feed dropped.
   function Without_Controls (Text : String) return String;

   --  Whether Name has the extension of a video ffmpeg can take a frame of.
   function Is_Video (Name : String) return Boolean;

   --  How long a command run for a preview is given, in milliseconds: a
   --  thumbnailer, or a previewer of the user's own.
   Preview_Command_Timeout_Ms : constant := 10_000;

   --  The hex dump line for Data, at Offset into the file: the offset, up to
   --  sixteen bytes in hex, and those bytes as text.
   function Hex_Line (Data : String; Offset : Natural) return String;

   --  The board has one slot: the preview being shown.
   type Slot is (Only);

   --  The preview of Path, with the previewers and whether thumbnails are
   --  made.
   type Request is record
      Path       : Ada.Strings.Unbounded.Unbounded_String;
      Rules      : Rule_Vectors.Vector;
      Thumbnails : Boolean := True;
      Generation : Natural := 0;
   end record;

   function Request_Generation (Work : Request) return Natural is (Work.Generation);
   function Result_Generation (Outcome : Preview) return Natural is (Outcome.Generation);
   procedure Replace (Held : in out Preview; Outcome : Preview);

   package Boards is new Explore.Work_Boards
     (Slot               => Slot,
      Request            => Request,
      Result             => Preview,
      Request_Generation => Request_Generation,
      Result_Generation  => Result_Generation,
      Merge              => Replace,
      Stopper            => Boolean,
      No_Stopper         => False);

   subtype Board is Boards.Board;

   task type Worker (Jobs : not null access Board);
end Explore.Previews;
