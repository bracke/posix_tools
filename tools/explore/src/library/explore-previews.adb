with Ada.Task_Attributes;
with Explore.Archives;
with Explore.Files;
with Explore.Paths;
with Posix_Tools.Arguments;
with Posix_Tools.File_Operations;
with Posix_Tools.File_Operations.Removing;
with Posix_Tools.Host_Adapters.Environment;
with Posix_Tools.Host_Adapters.Executables;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Host_Adapters.Host;
with Posix_Tools.Host_Adapters.Processes;
with Posix_Tools.Text.File_Descriptions;
with Posix_Tools.Text.Numeric_Images;

package body Explore.Previews is
   package FS renames Posix_Tools.Host_Adapters.File_System;

   use type FS.File_Kind;
   package Unbounded renames Ada.Strings.Unbounded;

   Tab_Width : constant := 4;

   --  What `file` calls a JPEG. Content_Description has no word of its own
   --  for one, and a preview's description reads as `file` would give it,
   --  so this is data in the form of that output, not text of explore's.
   JPEG_Description : constant String := "JPEG image data";

   --  The thumbnails explore can make of a file that is not an image.
   type Thumbnail_Kind is
     (No_Thumbnail,
      PDF_Page,      --  The first page, by pdftoppm.
      Video_Frame);  --  The frame a second in, by ffmpeg.

   type Board_Access is access all Board;

   --  The preview the worker of this task is building, and for which board:
   --  a command run for it is stopped once it is no longer wanted, so that a
   --  slow previewer holds up neither the next preview nor quitting.
   type Building is record
      Jobs       : Board_Access;
      Generation : Natural := 0;
   end record;

   package Being_Built is new Ada.Task_Attributes (Building, (Jobs => null, Generation => 0));

   --  Whether the preview this task is building is no longer wanted: another
   --  was asked for, or the board was shut down. False outside a worker.
   function Unwanted return Boolean;

   --  Whether Path, just made, is a directory and not a link, owned by this
   --  process's user, and closed to everyone else: made so, if it can be.
   function Made_Private (Path : String) return Boolean;

   --  What Data, the start of a file, is, as Result's description; and when
   --  it is an image explore can show, its format and size into Result, with
   --  Is_Image True.
   procedure Describe (Data : String; Result : in out Preview; Is_Image : out Boolean);

   --  Run Tool with Arguments, which write a PNG to Output, and take it.
   procedure Make_Thumbnail
     (Tool      : String;
      Arguments : Posix_Tools.Arguments.Vector;
      Output    : String;
      Result    : in out Preview;
      Made      : out Boolean);

   --  A directory of this process's own for thumbnails, empty if none could
   --  be made.
   function Make_Thumbnail_Directory return String;

   --  The arguments of pdftoppm that make the first page of the PDF at Path
   --  into Directory's thumbnail.png, and of ffmpeg that make a frame of the
   --  video at Path into Output.
   function PDF_Arguments (Path, Directory : String) return Posix_Tools.Arguments.Vector;
   function Video_Arguments (Path, Output : String) return Posix_Tools.Arguments.Vector;

   --  Remove the thumbnail directory, if one was made.
   procedure Remove_Thumbnails (Directory : String);

   --  Run Rule's command for the file at Path, its output going to Output,
   --  and take what it printed as text. Made is False when it printed
   --  nothing or could not be run.
   procedure Run_Previewer
     (Rule   : Preview_Rule;
      Path   : String;
      Output : String;
      Result : in out Preview;
      Made   : out Boolean);

   --  Run the first of Rules whose patterns match the name of the file at
   --  Path, with its output in Directory. Made is False when none matches,
   --  or the one that does prints nothing; the rules after it are not tried.
   procedure Run_User_Previewer
     (Path      : String;
      Directory : String;
      Rules     : Rule_Vectors.Vector;
      Result    : in out Preview;
      Made      : out Boolean);

   --  Text split into lines without their terminators, tabs expanded, at
   --  most Max_Lines of them.
   procedure Split_Lines (Text : String; Lines : out Explore.String_Vectors.Vector);

   --  The members of the archive at Path, whose start is Data, into Result.
   procedure Take_Archive (Path, Data : String; Result : in out Preview; Made : out Boolean);

   --  Data, the start of the file at Path, as text coloured by its
   --  language, or else as a hex dump.
   procedure Take_Content (Path, Data : String; Result : in out Preview);

   --  The image Describe found the file at Path to be, unless it is larger
   --  than an image explore sends.
   procedure Take_Image (Path : String; Result : in out Preview; Made : out Boolean);

   --  A thumbnail of Kind of the file at Path, made in Directory.
   procedure Take_Thumbnail
     (Path      : String;
      Kind      : Thumbnail_Kind;
      Directory : String;
      Result    : in out Preview;
      Made      : out Boolean);

   --  The thumbnail explore makes of the file at Path, whose start is Data.
   function Thumbnail_Of (Path, Data : String) return Thumbnail_Kind;

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

      Explore.Files.Read_Head (Path, Head_Bytes, Head, Ok);

      if not Ok then
         Result.Kind := Unreadable_Preview;
         return Result;
      end if;

      declare
         Data     : constant String := Unbounded.To_String (Head);
         Status   : constant FS.Entry_Status := FS.Entry_Status_Of (Path);
         Made     : Boolean := False;
         Is_Image : Boolean := False;
      begin
         Result.Modified := Status.Modified_Seconds;
         Result.File_Size := Status.Size;

         --  The user's own previewers come first, and write where thumbnails do.
         if Thumbnail_Directory'Length > 0 then
            Run_User_Previewer (Path, Thumbnail_Directory, Rules, Result, Made);
         end if;

         if not Made then
            Describe (Data, Result, Is_Image);
         end if;

         if Is_Image then
            Take_Image (Path, Result, Made);
         end if;

         if not Made and then Explore.Archives.Is_Archive (Data) then
            Take_Archive (Path, Data, Result, Made);
         end if;

         if not Made and then Thumbnail_Directory'Length > 0 and then Thumbnails then
            Take_Thumbnail (Path, Thumbnail_Of (Path, Data), Thumbnail_Directory, Result, Made);
         end if;

         if not Made then
            Take_Content (Path, Data, Result);
         end if;
      end;

      return Result;
   end Build;

   procedure Describe (Data : String; Result : in out Preview; Is_Image : out Boolean) is
   begin
      Is_Image := False;

      if Explore.Images.Is_JPEG (Data) then
         Result.Description := Unbounded.To_Unbounded_String (JPEG_Description);
         Result.Format := Explore.Images.JPEG_Format;
         Is_Image := Explore.Images.JPEG_Size (Data, Result.Width, Result.Height);
         return;
      end if;

      Result.Description :=
        Unbounded.To_Unbounded_String (Posix_Tools.Text.File_Descriptions.Content_Description (Data, False, "", False));

      if Explore.Images.Is_PNG (Data) then
         Result.Format := Explore.Images.PNG_Format;
         Is_Image := Explore.Images.PNG_Size (Data, Result.Width, Result.Height);
      elsif Explore.Images.Is_GIF (Data) then
         Result.Format := Explore.Images.GIF_Format;
         Is_Image := Explore.Images.GIF_Size (Data, Result.Width, Result.Height);
      end if;
   end Describe;

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
      Lower : constant String := Explore.Paths.Folded (Name);

      function Ends (Suffix : String) return Boolean is
        (Lower'Length > Suffix'Length and then Lower (Lower'Last - Suffix'Length + 1 .. Lower'Last) = Suffix);
   begin
      return Ends (".mp4") or else Ends (".mkv") or else Ends (".webm") or else Ends (".mov") or else Ends (".avi")
        or else Ends (".m4v") or else Ends (".wmv") or else Ends (".flv") or else Ends (".mpg")
        or else Ends (".mpeg") or else Ends (".ogv");
   end Is_Video;

   function Made_Private (Path : String) return Boolean is
      Me, Owner, Group : Natural;
      Known_Owner      : Boolean;
      Known_Mode       : Boolean;
   begin
      if FS.Is_Link (Path) or else FS.Kind (Path) /= FS.Directory or else not FS.Set_Permissions (Path, 8#700#) then
         return False;
      end if;

      FS.File_Ownership (Path, Owner, Group, Known_Owner);
      return Known_Owner
        and then Posix_Tools.Host_Adapters.Host.Current_User_Id (Me)
        and then Owner = Me
        and then FS.File_Permission_Bits (Path, Known_Mode) mod 8#1000# = 8#700#
        and then Known_Mode
        and then not FS.Is_Link (Path);
   exception
      when others =>
         return False;
   end Made_Private;

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
           (Tool, Arguments, Preview_Command_Timeout_Ms, Status, Timed_Out, Unwanted'Access)
        and then Status = 0
        and then not Timed_Out
        and then FS.Exists (Output)
      then
         Explore.Files.Read_Head (Output, Image_Bytes, Result.Image, Read);

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
      --  Making a directory either succeeds or finds the name taken, so the
      --  one made is this process's alone; a name taken, by whoever, is
      --  passed over, never used. The name is easily guessed: the directory
      --  is closed to everyone else before anything is written to it, and
      --  not used at all when it cannot be.
      for N in 1 .. 1_000 loop
         declare
            Candidate : constant String :=
              Base & "/explore-thumbnails-" & Posix_Tools.Text.Numeric_Images.Natural_Image (N);
            Made      : Boolean := False;
         begin
            begin
               FS.Create_Directory (Candidate);
               Made := True;
            exception
               when others =>
                  null;
            end;

            if Made then
               return (if Made_Private (Candidate) then Candidate else "");
            end if;
         end;
      end loop;

      return "";
   end Make_Thumbnail_Directory;

   function PDF_Arguments (Path, Directory : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      --  -singlefile writes the page without a number after its name.
      Result.Append ("-q");
      Result.Append ("-png");
      Result.Append ("-f");
      Result.Append ("1");
      Result.Append ("-l");
      Result.Append ("1");
      Result.Append ("-scale-to");
      Result.Append ("1024");
      Result.Append ("-singlefile");
      Result.Append (Path);
      Result.Append (Directory & "/thumbnail");
      return Result;
   end PDF_Arguments;

   procedure Remove_Thumbnails (Directory : String) is
      type Quiet_Observer is new Posix_Tools.File_Operations.Observer with null record;

      overriding procedure Report_Error
        (Self : in out Quiet_Observer; Path : String; Error : Posix_Tools.File_Operations.Operation_Error) is null;

      Watcher : Quiet_Observer;
      Removed : Posix_Tools.File_Operations.Operation_Outcome;
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
           ("/bin/sh", Arguments, Preview_Command_Timeout_Ms, Status, Timed_Out, Unwanted'Access)
        and then FS.Exists (Output)
      then
         Explore.Files.Read_Head (Output, Head_Bytes, Printed, Read);

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

   procedure Run_User_Previewer
     (Path      : String;
      Directory : String;
      Rules     : Rule_Vectors.Vector;
      Result    : in out Preview;
      Made      : out Boolean)
   is
      Name : constant String := Explore.Paths.Name_Of (Path);
   begin
      Made := False;

      for Rule of Rules loop
         if (for some Pattern of Rule.Patterns => Explore.Paths.Glob_Matches (Pattern, Name)) then
            Run_Previewer (Rule, Path, Directory & "/preview.txt", Result, Made);
            return;
         end if;
      end loop;
   end Run_User_Previewer;

   procedure Split_Lines (Text : String; Lines : out Explore.String_Vectors.Vector) is
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

   procedure Take_Archive (Path, Data : String; Result : in out Preview; Made : out Boolean) is
   begin
      Explore.Archives.List (Path, Data, Max_Lines, Result.Lines, Made);

      if Made then
         Result.Kind := Archive_Preview;
      else
         Result.Lines.Clear;
      end if;
   end Take_Archive;

   procedure Take_Content (Path, Data : String; Result : in out Preview) is
   begin
      if Is_Text (Data) then
         Result.Kind := Text_Preview;
         Split_Lines (Data, Result.Lines);
         Result.Language :=
           Explore.Syntax.Language_Of (Path, (if Result.Lines.Is_Empty then "" else Result.Lines.First_Element));
         Result.Spans := Explore.Syntax.Tokenize_Lines (Result.Lines, Result.Language);
      else
         Result.Kind := Binary_Preview;

         for Offset in 0 .. Natural'Min (Max_Lines, (Data'Length + 15) / 16) - 1 loop
            Result.Lines.Append
              (Hex_Line
                 (Data (Data'First + Offset * 16 .. Natural'Min (Data'Last, Data'First + Offset * 16 + 15)),
                  Offset * 16));
         end loop;
      end if;
   end Take_Content;

   procedure Take_Image (Path : String; Result : in out Preview; Made : out Boolean) is
   begin
      Made := False;

      if FS.Size (Path) <= Image_Bytes then
         Explore.Files.Read_Head (Path, Image_Bytes, Result.Image, Made);

         if Made then
            Result.Kind := Image_Preview;
         else
            Result.Image := Unbounded.Null_Unbounded_String;
         end if;
      end if;
   end Take_Image;

   procedure Take_Thumbnail
     (Path      : String;
      Kind      : Thumbnail_Kind;
      Directory : String;
      Result    : in out Preview;
      Made      : out Boolean)
   is
      Output : constant String := Directory & "/thumbnail.png";
   begin
      Made := False;

      case Kind is
         when No_Thumbnail =>
            null;
         when PDF_Page =>
            declare
               Tool : constant String := Posix_Tools.Host_Adapters.Executables.Locate ("pdftoppm");
            begin
               if Tool'Length > 0 then
                  Make_Thumbnail (Tool, PDF_Arguments (Path, Directory), Output, Result, Made);
               end if;
            end;
         when Video_Frame =>
            declare
               Tool : constant String := Posix_Tools.Host_Adapters.Executables.Locate ("ffmpeg");
            begin
               if Tool'Length > 0 then
                  Make_Thumbnail (Tool, Video_Arguments (Path, Output), Output, Result, Made);
               end if;
            end;
      end case;
   end Take_Thumbnail;

   function Thumbnail_Of (Path, Data : String) return Thumbnail_Kind is
     (if Data'Length >= 5 and then Data (Data'First .. Data'First + 4) = "%PDF-" then PDF_Page
      elsif Is_Video (Path) then Video_Frame
      else No_Thumbnail);

   function Unwanted return Boolean is
      Now : constant Building := Being_Built.Value;
   begin
      return Now.Jobs /= null and then not Now.Jobs.Is_Wanted (Now.Generation);
   end Unwanted;

   function Video_Arguments (Path, Output : String) return Posix_Tools.Arguments.Vector is
      Result : Posix_Tools.Arguments.Vector;
   begin
      --  Quiet, and never reading the keyboard explore reads.
      Result.Append ("-v");
      Result.Append ("quiet");
      Result.Append ("-nostdin");
      Result.Append ("-y");
      Result.Append ("-ss");
      Result.Append ("1");
      Result.Append ("-i");
      Result.Append (Path);
      Result.Append ("-frames:v");
      Result.Append ("1");
      Result.Append ("-vf");
      Result.Append ("scale=1024:-2");
      Result.Append ("-c:v");
      Result.Append ("png");
      Result.Append (Output);
      return Result;
   end Video_Arguments;

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
            Being_Built.Set_Value ((Jobs => Jobs.all'Unchecked_Access, Generation => Generation));

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
