with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Explore.Images;
with Explore.Previews;
with Posix_Tools.Host_Adapters.File_System;

package body Preview_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Images renames Explore.Images;
   package Previews renames Explore.Previews;

   use type Previews.Preview_Kind;

   ESC : constant Character := Character'Val (27);

   --  The start of a PNG: its signature and an IHDR chunk header for an
   --  image of Width by Height pixels.
   function PNG_Header (Width, Height : Natural) return String;

   procedure Write (Name, Text : String);

   function Big_Endian (Value : Natural) return String is
     ([Character'Val (Value / 2 ** 24 mod 256), Character'Val (Value / 2 ** 16 mod 256),
       Character'Val (Value / 2 ** 8 mod 256), Character'Val (Value mod 256)]);

   function Count (Text, Pattern : String) return Natural is (Ada.Strings.Fixed.Count (Text, Pattern));

   function PNG_Header (Width, Height : Natural) return String is
     (Character'Val (16#89#) & "PNG" & Character'Val (13) & Character'Val (10) & Character'Val (26) & Character'Val (10)
      & Big_Endian (13) & "IHDR" & Big_Endian (Width) & Big_Endian (Height) & Character'Val (8) & Character'Val (6)
      & Character'Val (0) & Character'Val (0) & Character'Val (0));

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:base64", Test_Base64'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:placeholders", Test_Placeholders'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:png header", Test_PNG_Header'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:fit", Test_Fit'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("images:transmit", Test_Transmit'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("previews:build", Test_Build'Access));
      return Result;
   end Suite;

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
   end Test_PNG_Header;

   procedure Test_Transmit (T : in out Fixture) is
      pragma Unreferenced (T);
      Data   : constant String := [1 .. 5000 => 'x'];
      Direct : constant String := Images.Transmit_PNG (7, Data, 3, 2, In_Tmux => False);
      Tmux   : constant String := Images.Transmit_PNG (7, Data, 3, 2, In_Tmux => True);
   begin
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Direct, ESC & "_Ga=T,f=100,t=d,i=7,q=2,U=1,c=3,r=2,m=1;") = 1,
         "the first chunk carries the keys and a virtual placement");
      AUnit.Assertions.Assert (Count (Direct, ESC & "_G") = 2, "base64 of 5000 bytes takes two chunks");
      AUnit.Assertions.Assert (Count (Direct, ESC & "_Gm=0;") = 1, "the last chunk ends the transfer");
      AUnit.Assertions.Assert (Count (Tmux, ESC & "Ptmux;") = 2, "inside tmux each chunk is passed through");
      AUnit.Assertions.Assert
        (Images.Delete (7, In_Tmux => False) = ESC & "_Ga=d,d=I,i=7,q=2" & ESC & "\", "delete frees the data");
   end Test_Transmit;

   procedure Write (Name, Text : String) is
      Ok : Boolean;
   begin
      FS.Write_File (Name, Text, Append_Mode => False, Ok => Ok);
      AUnit.Assertions.Assert (Ok, "fixture written: " & Name);
   end Write;
end Preview_Tests;
