with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Numeric_Images;
with Posix_Tools.Text.Stat_Formats;

package body Posix_Tools.Commands.Stat is
   use Ada.Strings.Unbounded;
   use type Ada.Calendar.Time;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First      : Positive := 1;
      Ok         : Boolean := True;
      Has_Format : Boolean := False;
      Format_Text : Unbounded_String;

      function Time_Image (Value : Ada.Calendar.Time) return String is
         Year       : Ada.Calendar.Year_Number;
         Month      : Ada.Calendar.Month_Number;
         Day        : Ada.Calendar.Day_Number;
         Hour       : Ada.Calendar.Formatting.Hour_Number;
         Minute     : Ada.Calendar.Formatting.Minute_Number;
         Second     : Ada.Calendar.Formatting.Second_Number;
         Sub_Second : Ada.Calendar.Formatting.Second_Duration;
      begin
         Ada.Calendar.Formatting.Split (Value, Year, Month, Day, Hour, Minute, Second, Sub_Second, Time_Zone => 0);
         return Posix_Tools.Text.Numeric_Images.Four_Digit_Image (Natural (Year)) & "-"
           & Posix_Tools.Text.Numeric_Images.Two_Digit_Image (Natural (Month)) & "-"
           & Posix_Tools.Text.Numeric_Images.Two_Digit_Image (Natural (Day)) & " "
           & Posix_Tools.Text.Numeric_Images.Two_Digit_Image (Natural (Hour)) & ":"
           & Posix_Tools.Text.Numeric_Images.Two_Digit_Image (Natural (Minute)) & ":"
           & Posix_Tools.Text.Numeric_Images.Two_Digit_Image (Natural (Second)) & " +0000";
      end Time_Image;

      function Epoch_Image (Value : Ada.Calendar.Time) return String is
         Epoch : constant Ada.Calendar.Time := Ada.Calendar.Time_Of (1970, 1, 1, 0.0);
      begin
         return Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
           (Long_Long_Integer (Value - Epoch));
      exception
         when others =>
            return "unknown";
      end Epoch_Image;

      function Kind_Name (Path : String) return String is
      begin
         case FS.Kind (Path) is
            when FS.Missing_File =>
               return "missing";
            when FS.Directory =>
               return "directory";
            when FS.Ordinary_File =>
               return "regular file";
            when FS.Special_File =>
               declare
                  Info : constant FS.Special_File_Info := FS.Special_File_Info_Of (Path);
               begin
                  case Info.Kind is
                     when FS.FIFO =>
                        return "fifo";
                     when FS.Character_Device =>
                        return "character device";
                     when FS.Block_Device =>
                        return "block device";
                     when FS.Socket =>
                        return "socket";
                     when FS.Not_Special | FS.Other_Special =>
                        return "special file";
                  end case;
               end;
         end case;
      end Kind_Name;

      procedure Write_One (Path : String) is
         Mode_Available  : Boolean := False;
         Owner_Available : Boolean := False;
         User_Id         : Natural := 0;
         Group_Id        : Natural := 0;
         Mode            : constant Natural := FS.File_Permission_Bits (Path, Mode_Available);
         Access_Available   : Boolean := False;
         Creation_Available : Boolean := False;
         Modify_Available   : Boolean := False;
         Access_Time        : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
         Creation_Time      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
         Modify_Time        : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      begin
         if not FS.Exists (Path) then
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            return;
         end if;

         FS.File_Ownership (Path, User_Id, Group_Id, Owner_Available);
         Access_Available := FS.Access_Time (Path, Access_Time);
         Creation_Available := FS.Creation_Time (Path, Creation_Time);
         Modify_Available := FS.Modification_Time (Path, Modify_Time);

         if Has_Format then
            Context.Put_Line
              (Posix_Tools.Text.Stat_Formats.Render_Format
                 (Format               => To_String (Format_Text),
                  Path                 => Path,
                  Mode_Image           =>
                    (if Mode_Available
                     then Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (Mode)
                     else "unknown"),
                  Kind_Name            => Kind_Name (Path),
                  Group_Id_Image       =>
                    (if Owner_Available
                     then Posix_Tools.Text.Numeric_Images.Natural_Image (Group_Id)
                     else "unknown"),
                  Size_Image           => Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (FS.Size (Path)),
                  Creation_Time_Image  =>
                    (if Creation_Available then Time_Image (Creation_Time) else "unknown"),
                  Creation_Epoch_Image =>
                    (if Creation_Available then Epoch_Image (Creation_Time) else "0"),
                  Access_Time_Image    =>
                    (if Access_Available then Time_Image (Access_Time) else "unknown"),
                  Access_Epoch_Image   =>
                    (if Access_Available then Epoch_Image (Access_Time) else "0"),
                  Modify_Time_Image    =>
                    (if Modify_Available then Time_Image (Modify_Time) else "unknown"),
                  Modify_Epoch_Image   =>
                    (if Modify_Available then Epoch_Image (Modify_Time) else "0"),
                  User_Id_Image        =>
                    (if Owner_Available
                     then Posix_Tools.Text.Numeric_Images.Natural_Image (User_Id)
                     else "unknown")));
         else
            Context.Put_Line ("File: " & Path);
            Context.Put_Line
              ("Size: " & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (FS.Size (Path)));
            Context.Put_Line ("Type: " & Kind_Name (Path));
            Context.Put_Line
              ("Mode: "
               & (if Mode_Available
                  then Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (Mode)
                  else "unknown"));
            if Owner_Available then
               Context.Put_Line
                 ("Uid: " & Posix_Tools.Text.Numeric_Images.Natural_Image (User_Id));
               Context.Put_Line
                 ("Gid: " & Posix_Tools.Text.Numeric_Images.Natural_Image (Group_Id));
            else
               Context.Put_Line ("Uid: unknown");
               Context.Put_Line ("Gid: unknown");
            end if;
         end if;
      exception
         when others =>
            Ok := False;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
      end Write_One;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         if Context.Argument (First) = "-c" then
            if First = Context.Argument_Count then
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing option argument '-c'");
               return;
            end if;
            Has_Format := True;
            Format_Text := To_Unbounded_String (Context.Argument (First + 1));
            First := First + 2;
         elsif Context.Argument (First)'Length > 2
           and then Context.Argument (First) (Context.Argument (First)'First .. Context.Argument (First)'First + 1) =
                    "-c"
         then
            Has_Format := True;
            Format_Text :=
              To_Unbounded_String
                (Context.Argument (First) (Context.Argument (First)'First + 2 .. Context.Argument (First)'Last));
            First := First + 1;
         elsif Context.Argument (First) = "--" then
            First := First + 1;
            exit;
         else
            exit;
         end if;
      end loop;

      if Context.Argument_Count < First then
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, "missing operand");
         return;
      end if;

      for I in First .. Context.Argument_Count loop
         if I > First and then not Has_Format then
            Context.Put_Line ("");
         end if;
         Write_One (Context.Argument (I));
      end loop;

      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      elsif Ok then
         Result.Status := Posix_Tools.Exit_Status.Success;
      else
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;

end Posix_Tools.Commands.Stat;
