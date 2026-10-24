with Ada.Streams;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Descriptions;

package body Explore.Previews is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ada.Streams.Stream_Element_Offset;

   Tab_Width : constant := 4;

   --  At most Limit bytes from the start of the file at Path.
   procedure Read_Head (Path : String; Limit : Positive; Data : out Unbounded.Unbounded_String; Ok : out Boolean);

   --  Text split into lines without their terminators, tabs expanded, at
   --  most Max_Lines of them.
   procedure Split_Lines (Text : String; Lines : out Line_Vectors.Vector);

   protected body Board is
      function Busy return Boolean is (Waiting or else Running or else Ready);

      procedure Collect (Result : out Preview; Found : out Boolean) is
      begin
         Found := Ready;
         Result := (if Ready then Done else (others => <>));
         Ready := False;
         Done := (others => <>);
      end Collect;

      procedure Finish (Result : Preview) is
      begin
         Running := False;

         if Result.Generation = Wanted then
            Done := Result;
            Ready := True;
         end if;
      end Finish;

      function Is_Wanted (Generation : Natural) return Boolean is (not Closed and then Generation = Wanted);

      procedure Shut_Down is
      begin
         Closed := True;
      end Shut_Down;

      procedure Submit (Path : String; Generation : Natural) is
      begin
         Wanted_Path := Unbounded.To_Unbounded_String (Path);
         Wanted := Generation;
         Waiting := True;
         Ready := False;
      end Submit;

      entry Take (Path : out Unbounded.Unbounded_String; Generation : out Natural; Closed : out Boolean)
        when Board.Closed or else Waiting
      is
      begin
         Closed := Board.Closed;
         Path := Wanted_Path;
         Generation := Wanted;
         Waiting := False;
         Running := not Closed;
      end Take;
   end Board;

   function Build (Path : String) return Preview is
      Result : Preview := (Path => Unbounded.To_Unbounded_String (Path), others => <>);
      Head   : Unbounded.Unbounded_String;
      Ok     : Boolean;
   begin
      Read_Head (Path, Head_Bytes, Head, Ok);

      if not Ok then
         Result.Kind := Unreadable_Preview;
         return Result;
      end if;

      declare
         Data   : constant String := Unbounded.To_String (Head);
         Status : constant FS.Entry_Status := FS.Entry_Status_Of (Path);
         Sized  : Boolean := False;
      begin
         Result.Modified := Status.Modified_Seconds;
         Result.File_Size := Status.Size;
         Result.Description :=
           Unbounded.To_Unbounded_String
             (if Explore.Images.Is_JPEG (Data) then "JPEG image data"
              else Posix_Tools.Text.File_Descriptions.Content_Description (Data, False, "", False));

         if Explore.Images.Is_PNG (Data) then
            Result.Format := Explore.Images.PNG_Format;
            Sized := Explore.Images.PNG_Size (Data, Result.Width, Result.Height);
         elsif Explore.Images.Is_JPEG (Data) then
            Result.Format := Explore.Images.JPEG_Format;
            Sized := Explore.Images.JPEG_Size (Data, Result.Width, Result.Height);
         elsif Explore.Images.Is_GIF (Data) then
            Result.Format := Explore.Images.GIF_Format;
            Sized := Explore.Images.GIF_Size (Data, Result.Width, Result.Height);
         end if;

         if Sized and then FS.Size (Path) <= Image_Bytes then
            Read_Head (Path, Image_Bytes, Result.Image, Ok);

            if Ok then
               Result.Kind := Image_Preview;
               return Result;
            end if;

            Result.Image := Unbounded.Null_Unbounded_String;
         end if;

         if Posix_Tools.Text.File_Descriptions.Content_Description (Data, True, "", False) in
           "text/plain" | "text/x-script" | "inode/x-empty"
         then
            Result.Kind := Text_Preview;
            Split_Lines (Data, Result.Lines);
         else
            Result.Kind := Binary_Preview;

            for Offset in 0 .. Natural'Min (Max_Lines, (Data'Length + 15) / 16) - 1 loop
               Result.Lines.Append
                 (Hex_Line
                    (Data (Data'First + Offset * 16 .. Natural'Min (Data'Last, Data'First + Offset * 16 + 15)),
                     Offset * 16));
            end loop;
         end if;
      end;

      return Result;
   end Build;

   function Hex_Line (Data : String; Offset : Natural) return String is
      Digits_Of : constant String := "0123456789abcdef";
      Hex       : String (1 .. 16 * 3) := [others => ' '];
      Shown     : String (1 .. 16) := [others => ' '];
      Position  : String (1 .. 8);
      Value     : Natural := Offset;
   begin
      for I in reverse Position'Range loop
         Position (I) := Digits_Of (Value mod 16 + 1);
         Value := Value / 16;
      end loop;

      for I in Data'Range loop
         declare
            K    : constant Natural := I - Data'First;
            Byte : constant Natural := Character'Pos (Data (I));
         begin
            Hex (K * 3 + 1) := Digits_Of (Byte / 16 + 1);
            Hex (K * 3 + 2) := Digits_Of (Byte mod 16 + 1);
            Shown (K + 1) := (if Byte in 32 .. 126 then Data (I) else '.');
         end;
      end loop;

      return Position & "  " & Hex & " " & Shown (1 .. Data'Length);
   end Hex_Line;

   procedure Read_Head (Path : String; Limit : Positive; Data : out Unbounded.Unbounded_String; Ok : out Boolean) is
      procedure Take
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean);

      procedure Take
        (Buffer : Ada.Streams.Stream_Element_Array;
         Last   : Ada.Streams.Stream_Element_Offset;
         Stop   : in out Boolean)
      is
         Room  : constant Natural := Limit - Unbounded.Length (Data);
         Count : constant Natural := Natural'Min (Room, Natural (Last - Buffer'First + 1));
         Chunk : String (1 .. Count);
      begin
         for I in Chunk'Range loop
            Chunk (I) := Character'Val (Buffer (Buffer'First + Ada.Streams.Stream_Element_Offset (I - 1)));
         end loop;

         Unbounded.Append (Data, Chunk);
         Stop := Unbounded.Length (Data) >= Limit;
      end Take;

      procedure Each is new FS.For_Each_File_Chunk (Take);
   begin
      Data := Unbounded.Null_Unbounded_String;
      Each (Path, Ok);
   exception
      when others =>
         Ok := False;
   end Read_Head;

   procedure Split_Lines (Text : String; Lines : out Line_Vectors.Vector) is
      Line : Unbounded.Unbounded_String;
      Column : Natural := 0;
   begin
      Lines.Clear;

      for C of Text loop
         exit when Natural (Lines.Length) >= Max_Lines;

         case C is
            when Character'Val (10) =>
               Lines.Append (Unbounded.To_String (Line));
               Line := Unbounded.Null_Unbounded_String;
               Column := 0;
            when Character'Val (13) =>
               null;
            when Character'Val (9) =>
               loop
                  Unbounded.Append (Line, ' ');
                  Column := Column + 1;
                  exit when Column mod Tab_Width = 0;
               end loop;
            when others =>
               Unbounded.Append (Line, C);

               if Character'Pos (C) not in 16#80# .. 16#BF# then
                  Column := Column + 1;
               end if;
         end case;
      end loop;

      if Unbounded.Length (Line) > 0 and then Natural (Lines.Length) < Max_Lines then
         Lines.Append (Unbounded.To_String (Line));
      end if;
   end Split_Lines;

   task body Worker is
      Path       : Unbounded.Unbounded_String;
      Generation : Natural;
      Closed     : Boolean;
   begin
      loop
         Jobs.Take (Path, Generation, Closed);
         exit when Closed;

         declare
            Result : Preview;
         begin
            begin
               Result := Build (Unbounded.To_String (Path));
            exception
               when others =>
                  Result := (Kind => Unreadable_Preview, Path => Path, others => <>);
            end;

            Result.Generation := Generation;
            Jobs.Finish (Result);
         end;
      end loop;
   end Worker;
end Explore.Previews;
