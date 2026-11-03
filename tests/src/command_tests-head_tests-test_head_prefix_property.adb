separate (Command_Tests.Head_Tests)

   procedure Test_Head_Prefix_Property (T : in out Fixture) is
      pragma Unreferenced (T);
      subtype Word_32 is Test_Support.Word_32;
      use type Word_32;
      type Count_Array is array (Positive range <>) of Natural;
      type Length_Array is array (Positive range <>) of Natural;

      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
      Path    : constant String := Fixture_Path ("property-head-prefix.bin");
      LF      : constant Character := Character'Val (10);
      Initial_Seed : constant Word_32 := 16#4845_4144#;
      Seed    : Word_32 := Initial_Seed;
      Counts  : constant Count_Array := [0, 1, 2, 5, 11, 32];
      Lengths : constant Length_Array := [0, 1, 16, 17, 63, 256, 1025];

      function Decimal_Image (Value : Natural) return String is
         Raw : constant String := Natural'Image (Value);
      begin
         return Raw (Raw'First + 1 .. Raw'Last);
      end Decimal_Image;

      function Expected_Prefix (Data : String; Count : Natural) return String is
         Lines : Natural := 0;
      begin
         if Count = 0 then
            return "";
         end if;

         for I in Data'Range loop
            if Data (I) = LF then
               Lines := Lines + 1;
               if Lines = Count then
                  return Data (Data'First .. I);
               end if;
            end if;
         end loop;

         return Data;
      end Expected_Prefix;

      function Next_Byte return Character is
      begin
         Test_Support.Advance (Seed);
         return Character'Val (Natural ((Seed / 16#0100_0000#) mod 256));
      end Next_Byte;

      function Generated (Length : Natural) return String is
         Result : String (1 .. Length);
      begin
         if Length = 0 then
            return "";
         end if;

         for I in Result'Range loop
            if I mod 17 = 0 then
               Result (I) := LF;
            else
               Result (I) := Next_Byte;
            end if;
         end loop;

         return Result;
      end Generated;
   begin
      for Length of Lengths loop
         declare
            Data : constant String := Generated (Length);
         begin
            Write_File (Path, Data);

            for Count of Counts loop
               Context.Initialize ("head", Three_Args ("-n", Decimal_Image (Count), Path));
               Posix_Tools.Commands.Head.Run (Context, Result);
               AUnit.Assertions.Assert
                 (Test_Contexts.Output (Context) = Expected_Prefix (Data, Count),
                  "head prefix property " & Test_Support.Seed_Label (Initial_Seed) & " length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
               AUnit.Assertions.Assert
                 (Result.Status = Posix_Tools.Exit_Status.Success,
                  "head prefix property status " & Test_Support.Seed_Label (Initial_Seed) & " length"
                  & Natural'Image (Length) & " count" & Natural'Image (Count));
            end loop;
         end;
      end loop;

      Ada.Directories.Delete_File (Path);
   end Test_Head_Prefix_Property;
