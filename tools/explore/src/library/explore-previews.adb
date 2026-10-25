with Ada.Characters.Handling;
with Ada.Streams;
with Ada.Strings.Fixed;
with Explore.Archives;
with Explore.Model;
with Posix_Tools.Arguments;
with Posix_Tools.File_Operations;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.Environment;
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Host_Adapters.Processes;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Descriptions;
with Posix_Tools.Text.Glob;

package body Explore.Previews is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;
   package Unbounded renames Ada.Strings.Unbounded;

   use type Ada.Streams.Stream_Element_Offset;

   Tab_Width : constant := 4;

   --  The last component of Path.
   function Name_Of (Path : String) return String is
     (Path (Ada.Strings.Fixed.Index (Path, "/", Ada.Strings.Backward) + 1 .. Path'Last));

   --  Run Tool with Arguments, which write a PNG to Output, and take it.
   procedure Make_Thumbnail
     (Tool      : String;
      Arguments : Posix_Tools.Arguments.Vector;
      Output    : String;
      Result    : in out Preview;
      Made      : out Boolean);

   --  Run Rule's command for the file at Path, its output going to Output,
   --  and take what it printed as text. Made is False when it printed
   --  nothing or could not be run.
   procedure Run_Previewer
     (Rule   : Preview_Rule;
      Path   : String;
      Output : String;
      Result : in out Preview;
      Made   : out Boolean);

   --  A directory of this process's own for thumbnails, empty if none could
   --  be made.
   function Make_Thumbnail_Directory return String;

   --  Text split into lines without their terminators, tabs expanded, at
   --  most Max_Lines of them.
   procedure Split_Lines (Text : String; Lines : out Line_Vectors.Vector);

   --  Remove the thumbnail directory, if one was made.
   procedure Remove_Thumbnails (Directory : String);

   protected body Board is
      function Busy return Boolean is (Waiting or else Running or else Ready);

      procedure Collect (Result : out Preview; Found : out Boolean) is
      begin
         Found := Ready;
         Result := (if Ready then Done else (others => <>));
         Ready := False;
         Done := (others => <>);
      end Collect;

      procedure Configure (Rules : Rule_Vectors.Vector; Thumbnails : Boolean) is
      begin
         Board.Rules := Rules;
         Board.Thumbnails := Thumbnails;
      end Configure;

      function Configured_Rules return Rule_Vectors.Vector is (Rules);

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

      function Thumbnails_Wanted return Boolean is (Thumbnails);
   end Board;

   function Build
     (Path                : String;
      Thumbnail_Directory : String := "";
      Rules               : Rule_Vectors.Vector := Rule_Vectors.Empty_Vector;
      Thumbnails          : Boolean := True) return Preview
   is
      Result : Preview := (Path => Unbounded.To_Unbounded_String (Path), others => <>);
      Head   : Unbounded.Unbounded_String;
      Ok     : Boolean;
   begin
      --  A pipe or a device is not read: opening one can wait for ever for
      --  the other end, and the worker with it.
      if FS.Kind (Path) = FS.Special_File then
         return Result;
      end if;

      Read_Head (Path, Head_Bytes, Head, Ok);

      if not Ok then
         Result.Kind := Unreadable_Preview;
         return Result;
      end if;

      if Thumbnail_Directory'Length > 0 then
         declare
            Name : constant String := Ada.Characters.Handling.To_Lower (Name_Of (Path));
         begin
            for Rule of Rules loop
               if (for some Pattern of Rule.Patterns =>
                     Posix_Tools.Text.Glob.Matches (Ada.Characters.Handling.To_Lower (Pattern), Name))
               then
                  declare
                     Made : Boolean;
                  begin
                     Run_Previewer (Rule, Path, Thumbnail_Directory & "/preview.txt", Result, Made);

                     if Made then
                        declare
                           Status : constant FS.Entry_Status := FS.Entry_Status_Of (Path);
                        begin
                           Result.Modified := Status.Modified_Seconds;
                           Result.File_Size := Status.Size;
                        end;

                        return Result;
                     end if;
                  end;

                  exit;
               end if;
            end loop;
         end;
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

         if Explore.Archives.Is_Archive (Data) then
            declare
               Members : Explore.Model.Path_Vectors.Vector;
            begin
               Explore.Archives.List (Path, Data, Max_Lines, Members, Ok);

               if Ok then
                  for Member of Members loop
                     Result.Lines.Append (Member);
                  end loop;

                  Result.Kind := Archive_Preview;
                  return Result;
               end if;
            end;
         end if;

         if Thumbnail_Directory'Length > 0 and then Thumbnails then
            declare
               Output : constant String := Thumbnail_Directory & "/thumbnail.png";
               Tool   : constant String :=
                 Posix_Tools.Host_Adapters.Executables.Locate
                   (if Data'Length >= 5 and then Data (Data'First .. Data'First + 4) = "%PDF-" then "pdftoppm"
                    elsif Is_Video (Path) then "ffmpeg"
                    else "");
               Arguments : Posix_Tools.Arguments.Vector;
               Made      : Boolean := False;
            begin
               if Tool'Length > 0 and then Data'Length >= 5 and then Data (Data'First .. Data'First + 4) = "%PDF-" then
                  --  -singlefile writes Output without a page number.
                  Arguments.Append ("-q");
                  Arguments.Append ("-png");
                  Arguments.Append ("-f");
                  Arguments.Append ("1");
                  Arguments.Append ("-l");
                  Arguments.Append ("1");
                  Arguments.Append ("-scale-to");
                  Arguments.Append ("1024");
                  Arguments.Append ("-singlefile");
                  Arguments.Append (Path);
                  Arguments.Append (Thumbnail_Directory & "/thumbnail");

                  Make_Thumbnail (Tool, Arguments, Output, Result, Made);
               elsif Tool'Length > 0 then
                  --  Quiet, and never reading the keyboard explore reads.
                  Arguments.Append ("-v");
                  Arguments.Append ("quiet");
                  Arguments.Append ("-nostdin");
                  Arguments.Append ("-y");
                  Arguments.Append ("-ss");
                  Arguments.Append ("1");
                  Arguments.Append ("-i");
                  Arguments.Append (Path);
                  Arguments.Append ("-frames:v");
                  Arguments.Append ("1");
                  Arguments.Append ("-vf");
                  Arguments.Append ("scale=1024:-2");
                  Arguments.Append ("-c:v");
                  Arguments.Append ("png");
                  Arguments.Append (Output);

                  Make_Thumbnail (Tool, Arguments, Output, Result, Made);
               end if;

               if Made then
                  return Result;
               end if;
            end;
         end if;

         if Is_Text (Data) then
            Result.Kind := Text_Preview;
            Split_Lines (Data, Result.Lines);
            Result.Language :=
              Explore.Syntax.Language_Of
                (Path, (if Result.Lines.Is_Empty then "" else Result.Lines.First_Element));
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

   function Is_Text (Data : String) return Boolean is
     (Posix_Tools.Text.File_Descriptions.Content_Description (Data, True, "", False) in
        "text/plain" | "text/x-script" | "inode/x-empty");

   function Is_Video (Name : String) return Boolean is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);

      function Ends (Suffix : String) return Boolean is
        (Lower'Length > Suffix'Length and then Lower (Lower'Last - Suffix'Length + 1 .. Lower'Last) = Suffix);
   begin
      return Ends (".mp4") or else Ends (".mkv") or else Ends (".webm") or else Ends (".mov") or else Ends (".avi")
        or else Ends (".m4v") or else Ends (".wmv") or else Ends (".flv") or else Ends (".mpg")
        or else Ends (".mpeg") or else Ends (".ogv");
   end Is_Video;

   procedure Make_Thumbnail
     (Tool      : String;
      Arguments : Posix_Tools.Arguments.Vector;
      Output    : String;
      Result    : in out Preview;
      Made      : out Boolean)
   is
      Status    : Integer;
      Timed_Out : Boolean;
      Read      : Boolean;
   begin
      Made := False;

      if FS.Exists (Output) then
         FS.Delete_File (Output);
      end if;

      if Posix_Tools.Host_Adapters.Processes.Run_With_Timeout
           (Tool, Arguments, Thumbnail_Timeout_Ms, Status, Timed_Out)
        and then Status = 0
        and then not Timed_Out
        and then FS.Exists (Output)
      then
         Read_Head (Output, Image_Bytes, Result.Image, Read);

         declare
            Data : constant String := Unbounded.To_String (Result.Image);
         begin
            if Read and then Explore.Images.PNG_Size (Data, Result.Width, Result.Height) then
               Result.Kind := Image_Preview;
               Result.Format := Explore.Images.PNG_Format;
               Result.Thumbnail := True;
               Made := True;
            else
               Result.Image := Unbounded.Null_Unbounded_String;
            end if;
         end;
      end if;

      if FS.Exists (Output) then
         FS.Delete_File (Output);
      end if;
   exception
      when others =>
         Made := False;
         Result.Image := Unbounded.Null_Unbounded_String;
   end Make_Thumbnail;

   function Make_Thumbnail_Directory return String is
      Base : constant String :=
        (if Posix_Tools.Host_Adapters.Environment.Defined ("TMPDIR")
           and then Posix_Tools.Host_Adapters.Environment.Value ("TMPDIR")'Length > 0
         then Posix_Tools.Host_Adapters.Environment.Value ("TMPDIR") else "/tmp");
   begin
      --  Making a directory either succeeds or finds it taken, so the first
      --  free name is this process's alone.
      for N in 1 .. 1_000 loop
         declare
            Image     : constant String := Natural'Image (N);
            Candidate : constant String := Base & "/explore-thumbnails-" & Image (Image'First + 1 .. Image'Last);
         begin
            if not FS.Exists (Candidate) then
               FS.Create_Directory (Candidate);
               return Candidate;
            end if;
         exception
            when others =>
               null;
         end;
      end loop;

      return "";
   end Make_Thumbnail_Directory;

   procedure Read_Head
     (Path  : String;
      Limit : Positive;
      Data  : out Ada.Strings.Unbounded.Unbounded_String;
      Ok    : out Boolean)
   is
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

   procedure Remove_Thumbnails (Directory : String) is
      type Quiet_Observer is new Posix_Tools.File_Operations.Observer with null record;

      overriding procedure Report_Error
        (Self : in out Quiet_Observer; Path : String; Error : Posix_Tools.File_Operations.Operation_Error) is null;

      Watcher : Quiet_Observer;
      Removed : Boolean;
   begin
      if Directory'Length > 0 then
         Posix_Tools.File_Operations.Removing.Remove_Path
           (Directory, (Recursive => True, others => <>), Watcher, Removed);
      end if;
   end Remove_Thumbnails;

   procedure Run_Previewer
     (Rule   : Preview_Rule;
      Path   : String;
      Output : String;
      Result : in out Preview;
      Made   : out Boolean)
   is
      LF        : constant Character := Character'Val (10);
      Arguments : Posix_Tools.Arguments.Vector;
      Status    : Integer;
      Timed_Out : Boolean;
      Printed   : Unbounded.Unbounded_String;
      Read      : Boolean;
   begin
      Made := False;

      --  The output file is $0 and the previewed file $1, so neither is
      --  quoted into the command.
      Arguments.Append ("-c");
      Arguments.Append ("exec >""$0"" 2>/dev/null </dev/null" & LF & Unbounded.To_String (Rule.Run));
      Arguments.Append (Output);
      Arguments.Append (Path);

      if Posix_Tools.Host_Adapters.Processes.Run_With_Timeout
           ("/bin/sh", Arguments, Thumbnail_Timeout_Ms, Status, Timed_Out)
        and then FS.Exists (Output)
      then
         Read_Head (Output, Head_Bytes, Printed, Read);

         if Read and then Unbounded.Length (Printed) > 0 then
            Result.Kind := Text_Preview;
            Result.Description := Rule.Run;
            Split_Lines (Without_Controls (Unbounded.To_String (Printed)), Result.Lines);
            Made := True;
         end if;
      end if;

      if FS.Exists (Output) then
         FS.Delete_File (Output);
      end if;
   exception
      when others =>
         Made := False;
   end Run_Previewer;

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

   function Without_Controls (Text : String) return String is
      ESC    : constant Character := Character'Val (27);
      BEL    : constant Character := Character'Val (7);
      Result : Unbounded.Unbounded_String;
      I      : Natural := Text'First;
   begin
      while I <= Text'Last loop
         if Text (I) = ESC and then I < Text'Last and then Text (I + 1) = '[' then
            --  CSI: parameters and intermediates, then a final byte.
            I := I + 2;

            while I <= Text'Last and then Text (I) not in '@' .. '~' loop
               I := I + 1;
            end loop;
         elsif Text (I) = ESC and then I < Text'Last and then Text (I + 1) in ']' | 'P' | '_' then
            --  OSC, DCS, APC: up to BEL or ST.
            I := I + 2;

            while I <= Text'Last and then Text (I) /= BEL
              and then not (Text (I) = ESC and then I < Text'Last and then Text (I + 1) = '\')
            loop
               I := I + 1;
            end loop;

            if I <= Text'Last and then Text (I) = ESC then
               I := I + 1;
            end if;
         elsif Text (I) = ESC then
            I := I + 1;
         elsif Character'Pos (Text (I)) >= 32 or else Text (I) in Character'Val (9) | Character'Val (10) then
            Unbounded.Append (Result, Text (I));
         end if;

         I := I + 1;
      end loop;

      return Unbounded.To_String (Result);
   end Without_Controls;

   task body Worker is
      Path       : Unbounded.Unbounded_String;
      Generation : Natural;
      Closed     : Boolean;
      Thumbnails : Unbounded.Unbounded_String;
      Made       : Boolean := False;
   begin
      loop
         Jobs.Take (Path, Generation, Closed);
         exit when Closed;

         declare
            Result : Preview;
         begin
            begin
               --  The thumbnail directory is made when a preview first needs one.
               if not Made then
                  Thumbnails := Unbounded.To_Unbounded_String (Make_Thumbnail_Directory);
                  Made := True;
               end if;

               Result :=
                 Build
                   (Unbounded.To_String (Path), Unbounded.To_String (Thumbnails), Jobs.Configured_Rules,
                    Jobs.Thumbnails_Wanted);
            exception
               when others =>
                  Result := (Kind => Unreadable_Preview, Path => Path, others => <>);
            end;

            Result.Generation := Generation;
            Jobs.Finish (Result);
         end;
      end loop;

      Remove_Thumbnails (Unbounded.To_String (Thumbnails));
   end Worker;
end Explore.Previews;
