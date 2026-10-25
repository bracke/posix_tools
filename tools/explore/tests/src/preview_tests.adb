with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Explore.Archives;
with Explore.Images;
with Explore.String_Vectors;
with Explore.Previews;
with Explore.Syntax;
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Host_Adapters.File_System;
with Zlib;

package body Preview_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Images renames Explore.Images;
   package Previews renames Explore.Previews;

   use type Previews.Preview_Kind;
   use type Explore.Syntax.Language;
   use type Explore.Syntax.Token_Kind;

   ESC : constant Character := Character'Val (27);

   --  The start of a PNG: its signature and an IHDR chunk header for an
   --  image of Width by Height pixels.
   function PNG_Header (Width, Height : Natural) return String;

   --  A ustar header for a member called Name of Size bytes and type Kind.
   function Tar_Header (Name : String; Size : Natural; Kind : Character) return String;

   --  A ZIP archive holding Name, stored, with Data as its content.
   function Zip_Of (Name, Data : String) return String;

   --  The members listed of the archive at Path, which holds Data.
   function Lines_Of (Path, Data : String) return Explore.String_Vectors.Vector;

   procedure Write (Name, Text : String);

   --  A JPEG's start: SOI, an APP0 segment, and a baseline frame header.
   function JPEG_Header (Width, Height : Natural) return String is
     (Character'Val (16#FF#) & Character'Val (16#D8#)
      & Character'Val (16#FF#) & Character'Val (16#E0#) & Character'Val (0) & Character'Val (16)
      & "JFIF" & Character'Val (0) & [1 .. 9 => Character'Val (0)]
      & Character'Val (16#FF#) & Character'Val (16#C0#) & Character'Val (0) & Character'Val (17) & Character'Val (8)
      & Character'Val (Height / 256) & Character'Val (Height mod 256)
      & Character'Val (Width / 256) & Character'Val (Width mod 256)
      & Character'Val (3) & [1 .. 9 => Character'Val (0)]);

   function Big_Endian (Value : Natural) return String is
     ([Character'Val (Value / 2 ** 24 mod 256), Character'Val (Value / 2 ** 16 mod 256),
       Character'Val (Value / 2 ** 8 mod 256), Character'Val (Value mod 256)]);

   function Count (Text, Pattern : String) return Natural is (Ada.Strings.Fixed.Count (Text, Pattern));

   function Little_Endian (Value, Bytes : Natural) return String is
     ([for I in 1 .. Bytes => Character'Val (Value / 2 ** (8 * (I - 1)) mod 256)]);

   function Octal (Value, Digits_Wide : Natural) return String is
     ((if Digits_Wide > 1 then Octal (Value / 8, Digits_Wide - 1) else "") & Character'Val (48 + Value mod 8));

   NUL : constant Character := Character'Val (0);

   function PNG_Header (Width, Height : Natural) return String is
     (Character'Val (16#89#) & "PNG" & Character'Val (13) & Character'Val (10) & Character'Val (26) & Character'Val (10)
      & Big_Endian (13) & "IHDR" & Big_Endian (Width) & Big_Endian (Height) & Character'Val (8) & Character'Val (6)
      & Character'Val (0) & Character'Val (0) & Character'Val (0));

   function Lines_Of (Path, Data : String) return Explore.String_Vectors.Vector is
      Lines : Explore.String_Vectors.Vector;
      Ok    : Boolean;
   begin
      Explore.Archives.List (Path, Data, 100, Lines, Ok);
      AUnit.Assertions.Assert (Ok, "listed: " & Path);
      return Lines;
   end Lines_Of;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:base64", Test_Base64'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:placeholders", Test_Placeholders'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:png header", Test_PNG_Header'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:fit", Test_Fit'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:transmit", Test_Transmit'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("previews:build", Test_Build'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("previews:archives", Test_Archives'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("previews:syntax", Test_Syntax'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("previews:thumbnails", Test_Thumbnails'Access));
      return Result;
   end Suite;

   function Tar_Header (Name : String; Size : Natural; Kind : Character) return String is
      Header : String (1 .. 512) := [others => NUL];
      Sum    : Natural := 0;

      procedure Put (At_Offset : Natural; Text : String);

      procedure Put (At_Offset : Natural; Text : String) is
      begin
         Header (At_Offset + 1 .. At_Offset + Text'Length) := Text;
      end Put;
   begin
      Put (0, Name);
      Put (100, Octal (8#644#, 7));
      Put (108, Octal (0, 7));
      Put (116, Octal (0, 7));
      Put (124, Octal (Size, 11));
      Put (136, Octal (0, 11));
      Put (148, "        ");
      Put (156, [Kind]);
      Put (257, "ustar" & NUL & "00");

      for C of Header loop
         Sum := Sum + Character'Pos (C);
      end loop;

      Put (148, Octal (Sum, 6) & NUL & " ");
      return Header;
   end Tar_Header;

   procedure Test_Archives (T : in out Fixture) is
      pragma Unreferenced (T);
      use type Explore.String_Vectors.Vector;

      Root    : constant String := Ada.Directories.Current_Directory & "/obj/archive-fixture";
      Content : constant String := "hello" & Character'Val (10);
      Tar     : constant String :=
        Tar_Header ("docs/", 0, '5') & Tar_Header ("docs/readme", Content'Length, '0') & Content
        & [1 .. 512 - Content'Length => NUL] & [1 .. 1024 => NUL];
      Packed  : Zlib.Byte_Array (0 .. Tar'Length - 1);
      Status  : Zlib.Status_Code;
      Wanted  : Explore.String_Vectors.Vector;
      Item    : Previews.Preview;
   begin
      Ada.Directories.Create_Path (Root);
      Wanted.Append ("        docs/");
      Wanted.Append ("     6  docs/readme");

      Write (Root & "/plain.tar", Tar);
      AUnit.Assertions.Assert (Explore.Archives.Is_Archive (Tar), "tar is told by its ustar magic");
      AUnit.Assertions.Assert (Lines_Of (Root & "/plain.tar", Tar) = Wanted, "tar members, sized, directories marked");

      for I in Packed'Range loop
         Packed (I) := Zlib.Byte (Character'Pos (Tar (Tar'First + I)));
      end loop;

      declare
         Compressed : constant Zlib.Byte_Array := Zlib.GZip (Packed, Status => Status);
         Text       : String (1 .. Compressed'Length);
      begin
         for I in Text'Range loop
            Text (I) := Character'Val (Compressed (Compressed'First + I - 1));
         end loop;

         Write (Root & "/packed.tar.gz", Text);
         AUnit.Assertions.Assert
           (Lines_Of (Root & "/packed.tar.gz", Text) = Wanted, "a gzip compressed tar is inflated");
      end;

      Write (Root & "/stored.zip", Zip_Of ("inner.txt", Content));
      Wanted.Clear;
      Wanted.Append ("     6  inner.txt");
      AUnit.Assertions.Assert (Lines_Of (Root & "/stored.zip", Zip_Of ("inner.txt", Content)) = Wanted, "zip members from its central directory");

      Item := Previews.Build (Root & "/plain.tar");
      AUnit.Assertions.Assert
        (Item.Kind = Previews.Archive_Preview and then Natural (Item.Lines.Length) = 2, "an archive preview");

      AUnit.Assertions.Assert (not Explore.Archives.Is_Archive (Content), "plain text is no archive");
   end Test_Archives;

   procedure Test_Base64 (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Images.Base64 ("") = "", "empty");
      AUnit.Assertions.Assert (Images.Base64 ("f") = "Zg==", "one byte");
      AUnit.Assertions.Assert (Images.Base64 ("fo") = "Zm8=", "two bytes");
      AUnit.Assertions.Assert (Images.Base64 ("foo") = "Zm9v", "three bytes");
      AUnit.Assertions.Assert (Images.Base64 ("foobar") = "Zm9vYmFy", "six bytes");
      AUnit.Assertions.Assert
        (Images.Base64 ([Character'Val (255), Character'Val (0), Character'Val (128)]) = "/wCA", "high bytes");
   end Test_Base64;

   procedure Test_Build (T : in out Fixture) is
      pragma Unreferenced (T);
      Root : constant String := Ada.Directories.Current_Directory & "/obj/preview-fixture";
      Item : Previews.Preview;
   begin
      Ada.Directories.Create_Path (Root);
      Write (Root & "/text", "first" & Character'Val (10) & "a" & Character'Val (9) & "b" & Character'Val (13)
             & Character'Val (10) & "last");
      Write (Root & "/binary", "AB" & Character'Val (0) & Character'Val (255));
      Write (Root & "/image.png", PNG_Header (32, 16));

      Item := Previews.Build (Root & "/text");
      AUnit.Assertions.Assert
        (Item.Kind = Previews.Text_Preview and then Natural (Item.Lines.Length) = 3, "text, three lines");
      AUnit.Assertions.Assert (Item.Lines (2) = "a   b", "tabs expanded and carriage returns dropped");
      AUnit.Assertions.Assert (Item.Lines (3) = "last", "a last line without its newline");

      Item := Previews.Build (Root & "/binary");
      AUnit.Assertions.Assert
        (Item.Kind = Previews.Binary_Preview and then Natural (Item.Lines.Length) = 1, "binary, one dump line");
      AUnit.Assertions.Assert
        (Item.Lines (1) = Previews.Hex_Line ("AB" & Character'Val (0) & Character'Val (255), 0), "dumped");
      AUnit.Assertions.Assert
        (Ada.Strings.Unbounded.To_String (Item.Description) = "data", "described as the file command would");

      Item := Previews.Build (Root & "/image.png");
      AUnit.Assertions.Assert
        (Item.Kind = Previews.Image_Preview and then Item.Width = 32 and then Item.Height = 16
         and then Ada.Strings.Unbounded.Length (Item.Image) = PNG_Header (32, 16)'Length,
         "a PNG with its size and data");

      Write (Root & "/photo.jpg", JPEG_Header (64, 48));
      Item := Previews.Build (Root & "/photo.jpg");
      AUnit.Assertions.Assert
        (Item.Kind = Previews.Image_Preview and then Item.Width = 64 and then Item.Height = 48
         and then Images."=" (Item.Format, Images.JPEG_Format) and then Item.File_Size = JPEG_Header (64, 48)'Length,
         "a JPEG with its size, encoding, and file size");

      Item := Previews.Build (Root & "/missing");
      AUnit.Assertions.Assert (Item.Kind = Previews.Unreadable_Preview, "a missing file");

      AUnit.Assertions.Assert
        (Previews.Hex_Line ("AB", 16) = "00000010  41 42" & [1 .. 44 => ' '] & "AB", "hex line layout");
      AUnit.Assertions.Assert
        (Previews.Hex_Line ([Character'Val (10)], 0) (60 .. 60) = ".", "unprintable bytes show as dots");
   end Test_Build;

   procedure Test_Fit (T : in out Fixture) is
      pragma Unreferenced (T);
      Columns, Rows : Positive;
   begin
      Images.Fit (640, 480, 10, 20, 40, 20, Columns, Rows);
      AUnit.Assertions.Assert (Columns = 40 and then Rows = 15, "wide image: as wide as the pane");
      Images.Fit (480, 960, 10, 20, 40, 20, Columns, Rows);
      AUnit.Assertions.Assert (Columns = 20 and then Rows = 20, "tall image: as tall as the pane");
      Images.Fit (8, 8, 10, 20, 40, 20, Columns, Rows);
      AUnit.Assertions.Assert (Columns = 1 and then Rows = 1, "a small image is not blown up");
   end Test_Fit;

   procedure Test_Placeholders (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert (Images.Diacritic (0) = Wide_Wide_Character'Val (16#0305#), "row and column zero");
      AUnit.Assertions.Assert (Images.Diacritic (1) = Wide_Wide_Character'Val (16#030D#), "one");
      AUnit.Assertions.Assert
        (Images.Diacritic (Images.Diacritic_Count - 1) = Wide_Wide_Character'Val (16#1D244#), "the last");
   end Test_Placeholders;

   procedure Test_PNG_Header (T : in out Fixture) is
      pragma Unreferenced (T);
      Width, Height : Natural;
   begin
      AUnit.Assertions.Assert
        (Images.PNG_Size (PNG_Header (640, 480), Width, Height) and then Width = 640 and then Height = 480, "size");
      AUnit.Assertions.Assert
        (Images.PNG_Size (PNG_Header (70_000, 3_000_000), Width, Height)
         and then Width = 70_000 and then Height = 3_000_000,
         "large sizes");
      AUnit.Assertions.Assert (not Images.PNG_Size ("GIF89a", Width, Height), "not a PNG");
      AUnit.Assertions.Assert
        (not Images.PNG_Size (PNG_Header (1, 1) (1 .. 20), Width, Height), "a truncated header");
      AUnit.Assertions.Assert
        (Images.Is_JPEG ([Character'Val (16#FF#), Character'Val (16#D8#), Character'Val (16#FF#)]), "JPEG");
      AUnit.Assertions.Assert
        (Images.JPEG_Size (JPEG_Header (800, 600), Width, Height) and then Width = 800 and then Height = 600,
         "JPEG size from its frame header, past the segments before it");
      AUnit.Assertions.Assert
        (not Images.JPEG_Size (JPEG_Header (800, 600) (1 .. 10), Width, Height), "a JPEG cut off before its frame");
      AUnit.Assertions.Assert
        (Images.GIF_Size ("GIF89a" & Character'Val (16#2C#) & Character'Val (1) & Character'Val (16#C8#)
                          & Character'Val (0), Width, Height)
         and then Width = 300 and then Height = 200,
         "GIF size, little-endian");
   end Test_PNG_Header;

   procedure Test_Syntax (T : in out Fixture) is
      pragma Unreferenced (T);
      package Syntax renames Explore.Syntax;

      State : Syntax.Line_State;
      Spans : Syntax.Span_Vectors.Vector;

      function Has (Line : String; Text : String; Kind : Syntax.Token_Kind) return Boolean is
        (for some Run of Spans => Run.Kind = Kind and then Line (Run.First .. Run.Last) = Text);
   begin
      AUnit.Assertions.Assert (Syntax.Language_Of ("main.adb", "") = Syntax.Ada_Language, "Ada by extension");
      AUnit.Assertions.Assert (Syntax.Language_Of ("x.C", "") = Syntax.C_Family, "extensions in any case");
      AUnit.Assertions.Assert
        (Syntax.Language_Of ("run", "#!/bin/sh") = Syntax.Hash_Commented, "a script by its #! line");
      AUnit.Assertions.Assert (Syntax.Language_Of ("notes", "text") = Syntax.No_Language, "nothing to go by");

      declare
         Line : constant String := "   procedure Go is  --  start 42";
      begin
         Syntax.Tokenize (Line, Syntax.Ada_Language, State, Spans);
         AUnit.Assertions.Assert
           (Has (Line, "procedure", Syntax.Keyword) and then Has (Line, "is", Syntax.Keyword)
            and then Has (Line, "--  start 42", Syntax.Comment) and then Natural (Spans.Length) = 3,
            "Ada keywords and a comment to the end of the line, the number in it not apart");
      end;

      declare
         Line : constant String := "int n = 0x1F; /* open";
      begin
         Syntax.Tokenize (Line, Syntax.C_Family, State, Spans);
         AUnit.Assertions.Assert
           (Has (Line, "int", Syntax.Keyword) and then Has (Line, "0x1F", Syntax.Number)
            and then Has (Line, "/* open", Syntax.Comment) and then State.In_Block_Comment,
            "a block comment left open");
      end;

      declare
         Line : constant String := "still */ return ""a\""b"";";
      begin
         Syntax.Tokenize (Line, Syntax.C_Family, State, Spans);
         AUnit.Assertions.Assert
           (Has (Line, "still */", Syntax.Comment) and then not State.In_Block_Comment
            and then Has (Line, "return", Syntax.Keyword) and then Has (Line, """a\""b""", Syntax.String_Literal),
            "the comment closes on the next line, and an escaped quote stays in its string");
      end;

      declare
         Line : constant String := "## Title";
      begin
         Syntax.Tokenize (Line, Syntax.Markdown_Language, State, Spans);
         AUnit.Assertions.Assert (Has (Line, Line, Syntax.Heading), "a Markdown heading");
      end;
   end Test_Syntax;

   procedure Test_Thumbnails (T : in out Fixture) is
      pragma Unreferenced (T);
      Root : constant String := Ada.Directories.Current_Directory & "/obj/thumbnail-fixture";
      Item : Previews.Preview;
   begin
      AUnit.Assertions.Assert
        (Previews.Is_Video ("clip.MP4") and then Previews.Is_Video ("a.mkv") and then not Previews.Is_Video ("a.mp3"),
         "videos by extension");

      if Posix_Tools.Host_Adapters.Executables.Locate ("pdftoppm") = "" then
         return;
      end if;

      Ada.Directories.Create_Path (Root & "/out");
      Write
        (Root & "/page.pdf",
         "%PDF-1.1" & Character'Val (10) & "1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj" & Character'Val (10)
         & "2 0 obj<</Type/Pages/Kids[3 0 R]/Count 1>>endobj" & Character'Val (10)
         & "3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 72 36]>>endobj" & Character'Val (10)
         & "trailer<</Root 1 0 R>>" & Character'Val (10) & "%%EOF" & Character'Val (10));

      Item := Previews.Build (Root & "/page.pdf", Root & "/out");
      AUnit.Assertions.Assert
        (Item.Kind = Previews.Image_Preview and then Item.Thumbnail and then Item.Width = 2 * Item.Height,
         "a PDF's first page as a PNG of its shape");
      AUnit.Assertions.Assert
        (not Ada.Directories.Exists (Root & "/out/thumbnail.png"), "the thumbnail file is removed once read");

      Item := Previews.Build (Root & "/page.pdf");
      AUnit.Assertions.Assert (Item.Kind /= Previews.Image_Preview, "no thumbnails without a directory for them");
   end Test_Thumbnails;

   procedure Test_Transmit (T : in out Fixture) is
      pragma Unreferenced (T);
      Data   : constant String := [1 .. 5000 => 'x'];
      Direct : constant String := Images.Transmit_PNG (7, Data, 3, 2, In_Tmux => False);
      Tmux   : constant String := Images.Transmit_PNG (7, Data, 3, 2, In_Tmux => True);
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Direct, ESC & "_Ga=T,f=100,t=d,i=7,p=1,q=2,U=1,c=3,r=2,m=1;") = 1,
         "the first chunk carries the keys and a virtual placement");
      AUnit.Assertions.Assert (Count (Direct, ESC & "_G") = 2, "base64 of 5000 bytes takes two chunks");
      AUnit.Assertions.Assert (Count (Direct, ESC & "_Gm=0;") = 1, "the last chunk ends the transfer");
      AUnit.Assertions.Assert (Count (Tmux, ESC & "Ptmux;") = 2, "inside tmux each chunk is passed through");
      AUnit.Assertions.Assert
        (Images.Delete (7, In_Tmux => False) = ESC & "_Ga=d,d=I,i=7,q=2" & ESC & "\", "delete frees the data");
      AUnit.Assertions.Assert
        (Images.Place (7, 5, 4, In_Tmux => False) = ESC & "_Ga=p,i=7,p=1,q=2,U=1,c=5,r=4" & ESC & "\",
         "an image is placed again without being sent again");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Images.Transmit (9, Images.JPEG_Format, "x", 1, 1, False), "f=1001,") > 0
         and then Ada.Strings.Fixed.Index (Images.Transmit (9, Images.GIF_Format, "x", 1, 1, False), "f=1002,") > 0,
         "JPEG and GIF go by bracke-terminal's private codes");
   end Test_Transmit;

   procedure Write (Name, Text : String) is
      Ok : Boolean;
   begin
      FS.Write_File (Name, Text, Append_Mode => False, Ok => Ok);
      AUnit.Assertions.Assert (Ok, "fixture written: " & Name);
   end Write;

   function Zip_Of (Name, Data : String) return String is
      Common : constant String :=
        Little_Endian (20, 2) & Little_Endian (0, 2) & Little_Endian (0, 2) & Little_Endian (0, 4)
        & Little_Endian (0, 4) & Little_Endian (Data'Length, 4) & Little_Endian (Data'Length, 4)
        & Little_Endian (Name'Length, 2) & Little_Endian (0, 2);
      Local   : constant String := "PK" & Character'Val (3) & Character'Val (4) & Common & Name & Data;
      Central : constant String :=
        "PK" & Character'Val (1) & Character'Val (2) & Little_Endian (20, 2) & Common & Little_Endian (0, 2)
        & Little_Endian (0, 2) & Little_Endian (0, 2) & Little_Endian (0, 4) & Little_Endian (0, 4) & Name;
   begin
      return Local & Central & "PK" & Character'Val (5) & Character'Val (6) & Little_Endian (0, 2)
        & Little_Endian (0, 2) & Little_Endian (1, 2) & Little_Endian (1, 2) & Little_Endian (Central'Length, 4)
        & Little_Endian (Local'Length, 4) & Little_Endian (0, 2);
   end Zip_Of;
end Preview_Tests;
