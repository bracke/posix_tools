with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Unbounded;
with Explore.Image_Cache;
with Explore.Images;
with Posix_Tools.Text.Numeric_Images;

package body Image_Cache_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Cache renames Explore.Image_Cache;
   package Images renames Explore.Images;
   package Unbounded renames Ada.Strings.Unbounded;

   PNG : constant Images.Image_Format := Images.PNG_Format;

   function Key (Name : String; Modified : Long_Long_Integer := 1) return Cache.Image_Key is
     ((Path => Unbounded.To_Unbounded_String ("/pictures/" & Name), Modified => Modified, Size => 4));

   function Data (Text : String) return Unbounded.Unbounded_String renames Unbounded.To_Unbounded_String;

   --  Show the image Name with Text as its data, expecting the image number
   --  Id and the output Expected.
   procedure Expect_Show
     (Self     : in out Cache.Cache;
      Name     : String;
      Text     : String;
      Columns  : Positive;
      Rows     : Positive;
      Id       : Positive;
      Expected : String;
      Label    : String;
      Modified : Long_Long_Integer := 1);

   procedure Expect_Show
     (Self     : in out Cache.Cache;
      Name     : String;
      Text     : String;
      Columns  : Positive;
      Rows     : Positive;
      Id       : Positive;
      Expected : String;
      Label    : String;
      Modified : Long_Long_Integer := 1)
   is
      Given  : Positive;
      Output : constant String :=
        Cache.Show (Self, Key (Name, Modified), PNG, Data (Text), Columns, Rows, In_Tmux => False, Id => Given);
   begin
      AUnit.Assertions.Assert
        (Given = Id, Label & ": image" & Positive'Image (Given) & " instead of" & Positive'Image (Id));
      AUnit.Assertions.Assert (Output = Expected, Label & ": output " & Output);
   end Expect_Show;

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("image cache:reuse", Test_Reuse'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("image cache:resize", Test_Resize'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("image cache:changed file", Test_Changed_File'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("image cache:evict by count", Test_Evict_By_Count'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("image cache:evict by bytes", Test_Evict_By_Bytes'Access));
      AUnit.Test_Suites.Add_Test (Result, Caller.Create ("image cache:clear", Test_Clear'Access));
      return Result;
   end Suite;

   procedure Test_Changed_File (T : in out Fixture) is
      pragma Unreferenced (T);
      Self : Cache.Cache;
   begin
      Expect_Show (Self, "a", "AAAA", 10, 5, 1, Images.Transmit_PNG (1, "AAAA", 10, 5, False), "first");
      Expect_Show
        (Self, "a", "BBBB", 10, 5, 2, Images.Transmit_PNG (2, "BBBB", 10, 5, False), "modified since",
         Modified => 2);
      AUnit.Assertions.Assert (Cache.Count (Self) = 2, "the file as it was is another image");
   end Test_Changed_File;

   procedure Test_Clear (T : in out Fixture) is
      pragma Unreferenced (T);
      Self : Cache.Cache;
   begin
      Expect_Show (Self, "a", "AAAA", 10, 5, 1, Images.Transmit_PNG (1, "AAAA", 10, 5, False), "first");
      Cache.Clear (Self);
      AUnit.Assertions.Assert (Cache.Count (Self) = 0 and then Cache.Bytes (Self) = 0, "nothing is held");
      Expect_Show
        (Self, "a", "AAAA", 10, 5, 1, Images.Transmit_PNG (1, "AAAA", 10, 5, False), "sent again once forgotten");
   end Test_Clear;

   procedure Test_Evict_By_Bytes (T : in out Fixture) is
      pragma Unreferenced (T);
      Self : Cache.Cache (Byte_Limit => 10);
   begin
      Expect_Show (Self, "a", "AAAAAA", 10, 5, 1, Images.Transmit_PNG (1, "AAAAAA", 10, 5, False), "first");
      Expect_Show
        (Self, "b", "BBBBBB", 10, 5, 1,
         Images.Delete (1, False) & Images.Transmit_PNG (1, "BBBBBB", 10, 5, False),
         "the first freed to make room by bytes, and its number used again");
      AUnit.Assertions.Assert (Cache.Count (Self) = 1 and then Cache.Bytes (Self) = 6, "only the second is held");
      Expect_Show
        (Self, "c", "CCCCCCCCCCCC", 10, 5, 1,
         Images.Delete (1, False) & Images.Transmit_PNG (1, "CCCCCCCCCCCC", 10, 5, False),
         "an image larger than the limit is still shown, alone");
   end Test_Evict_By_Bytes;

   procedure Test_Evict_By_Count (T : in out Fixture) is
      pragma Unreferenced (T);
      Self : Cache.Cache;

      function Name (I : Positive) return String is ("p" & Posix_Tools.Text.Numeric_Images.Natural_Image (I));
   begin
      for I in 1 .. Cache.Slots loop
         Expect_Show (Self, Name (I), "DATA", 10, 5, I, Images.Transmit_PNG (I, "DATA", 10, 5, False), Name (I));
      end loop;

      --  Showing the first again makes the second the least recently shown.
      Expect_Show (Self, Name (1), "DATA", 10, 5, 1, "", "shown again");
      Expect_Show
        (Self, "new", "DATA", 10, 5, 2,
         Images.Delete (2, False) & Images.Transmit_PNG (2, "DATA", 10, 5, False),
         "the least recently shown is freed, and its number used again");
      AUnit.Assertions.Assert (Cache.Count (Self) = Cache.Slots, "every slot is full");
      Expect_Show (Self, Name (1), "DATA", 10, 5, 1, "", "the recently shown one is kept");
   end Test_Evict_By_Count;

   procedure Test_Resize (T : in out Fixture) is
      pragma Unreferenced (T);
      Self : Cache.Cache;
   begin
      Expect_Show (Self, "a", "AAAA", 10, 5, 1, Images.Transmit_PNG (1, "AAAA", 10, 5, False), "first");
      Expect_Show (Self, "a", "AAAA", 12, 6, 1, Images.Place (1, 12, 6, False), "placed again at the new size");
      Expect_Show (Self, "a", "AAAA", 12, 6, 1, "", "the new size is kept");
   end Test_Resize;

   procedure Test_Reuse (T : in out Fixture) is
      pragma Unreferenced (T);
      Self : Cache.Cache;
   begin
      Expect_Show (Self, "a", "AAAA", 10, 5, 1, Images.Transmit_PNG (1, "AAAA", 10, 5, False), "first");
      Expect_Show (Self, "b", "BBBB", 10, 5, 2, Images.Transmit_PNG (2, "BBBB", 10, 5, False), "second");
      Expect_Show (Self, "a", "AAAA", 10, 5, 1, "", "held, at the same size: nothing to send");
      AUnit.Assertions.Assert (Cache.Count (Self) = 2 and then Cache.Bytes (Self) = 8, "both are held");
   end Test_Reuse;
end Image_Cache_Tests;
