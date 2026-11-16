with Ada.Calendar;
with Ada.Calendar.Formatting;
with Ada.Strings.Unbounded;
with Posix_Tools.Accounts;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Commands.Usage_Messages;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.File_Modes;
with Posix_Tools.Text.Numeric_Images;
with Posix_Tools.Text.Stat_Formats;
with Posix_Tools.Unix_Time;

package body Posix_Tools.Commands.Stat is
   use all type Posix_Tools.Commands.Usage_Messages.Usage_Message;
   use Ada.Strings.Unbounded;
   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   package FS renames Posix_Tools.Host_Adapters.File_System;
   package Modes renames Posix_Tools.Text.File_Modes;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First      : Positive := 1;
      Ok         : Boolean := True;
      Has_Format : Boolean := False;
      Format_Text : Unbounded_String;
      Need_Mode     : Boolean := True;
      Need_Kind     : Boolean := True;
      Need_Group    : Boolean := True;
      Need_Size     : Boolean := True;
      Need_Creation : Boolean := True;
      Need_Access   : Boolean := True;
      Need_Modify   : Boolean := True;
      Need_User     : Boolean := True;
      Output_Buffer : Posix_Tools.Commands.Helpers.Output_Buffer;

      procedure Analyze_Format;
      procedure Emit_Line (Text : String);
      procedure Flush_Output;
      function Kind_Of (Path : String; Status : FS.Entry_Status) return FS.File_Kind;

      procedure Analyze_Format is
         Format : constant String := To_String (Format_Text);
         I      : Positive := Format'First;
      begin
         Need_Mode := False;
         Need_Kind := False;
         Need_Group := False;
         Need_Size := False;
         Need_Creation := False;
         Need_Access := False;
         Need_Modify := False;
         Need_User := False;

         while I <= Format'Last loop
            if Format (I) = '%' and then I < Format'Last then
               case Format (I + 1) is
                  when 'a'       => Need_Mode := True;
                  when 'F'       => Need_Kind := True;
                  when 'g'       => Need_Group := True;
                  when 's'       => Need_Size := True;
                  when 'w' | 'W' => Need_Creation := True;
                  when 'x' | 'X' => Need_Access := True;
                  when 'y' | 'Y' => Need_Modify := True;
                  when 'u'       => Need_User := True;
                  when others    => null;
               end case;
               I := I + 2;
            else
               I := I + 1;
            end if;
         end loop;
      end Analyze_Format;

      procedure Emit_Line (Text : String) is
      begin
         Posix_Tools.Commands.Helpers.Buffered_Put_Line
           (Output_Buffer, Context, Text);
      end Emit_Line;

      procedure Flush_Output is
      begin
         Posix_Tools.Commands.Helpers.Flush_Output
           (Output_Buffer, Context);
      end Flush_Output;

      function Kind_Of (Path : String; Status : FS.Entry_Status) return FS.File_Kind is
         Type_Code : constant Modes.File_Type_Code :=
           (if Status.Available then Modes.File_Type (Status.Mode) else 0);
      begin
         case Type_Code is
            when Modes.Type_Directory =>
               return FS.Directory;
            when Modes.Type_Regular =>
               return FS.Ordinary_File;
            when 0 | Modes.Type_Link =>
               --  File_Status_Of follows a resolving link. A link code can
               --  therefore be an unresolved link, whose missing-target
               --  behavior remains the host adapter's decision.
               return FS.Kind (Path);
            when others =>
               return FS.Special_File;
         end case;
      end Kind_Of;

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
      begin
         return Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image
           (Posix_Tools.Unix_Time.Seconds_Since_Epoch (Value));
      exception
         when Constraint_Error =>
            return "unknown";
      end Epoch_Image;

      function Kind_Name (Path : String; Kind : FS.File_Kind) return String is
      begin
         case Kind is
            when FS.Missing_File | FS.Uninspectable_File =>
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
         Status            : constant FS.Entry_Status := FS.File_Status_Of (Path);
         Kind              : constant FS.File_Kind := Kind_Of (Path, Status);
         Mode_Available    : Boolean := Status.Available;
         Owner_Available   : Boolean := Status.Available;
         User_Id           : Posix_Tools.Accounts.Id := Status.User;
         Group_Id          : Posix_Tools.Accounts.Id := Status.Group;
         Mode              : Natural := Status.Mode mod 8#10000#;
         Size              : Long_Long_Integer := Status.Size;
         Access_Available   : Boolean := False;
         Creation_Available : Boolean := False;
         Modify_Available   : Boolean := Status.Available;
         Access_Time        : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
         Creation_Time      : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
         Modify_Time        : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
      begin
         if Kind in FS.Missing_File | FS.Uninspectable_File then
            Ok := False;
            Flush_Output;
            Posix_Tools.Commands.Helpers.Subject_Operational_Error
              (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
            return;
         end if;

         if Status.Available and then Need_Modify then
            begin
               Modify_Time := Posix_Tools.Unix_Time.Time_Of (Status.Modified_Seconds);
            exception
               when Constraint_Error | Ada.Calendar.Time_Error =>
                  Modify_Available := FS.Modification_Time (Path, Modify_Time);
            end;
         elsif not Status.Available then
            if Need_Mode then
               Mode := FS.File_Permission_Bits (Path, Mode_Available);
            end if;
            if Need_User or else Need_Group then
               FS.File_Ownership (Path, User_Id, Group_Id, Owner_Available);
            end if;
            if Need_Size then
               Size := FS.Size (Path);
            end if;
            if Need_Modify then
               Modify_Available := FS.Modification_Time (Path, Modify_Time);
            end if;
         end if;
         if Need_Access then
            Access_Available := FS.Access_Time (Path, Access_Time);
         end if;
         if Need_Creation then
            Creation_Available := FS.Creation_Time (Path, Creation_Time);
         end if;

         if Has_Format then
            Emit_Line
              (Posix_Tools.Text.Stat_Formats.Render_Format
                 (Format               => To_String (Format_Text),
                  Path                 => Path,
                  Mode_Image           =>
                    (if Need_Mode and then Mode_Available
                     then Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (Mode)
                     else "unknown"),
                  Kind_Name            =>
                    (if Need_Kind then Kind_Name (Path, Kind) else ""),
                  Group_Id_Image       =>
                    (if Need_Group and then Owner_Available
                     then Posix_Tools.Accounts.Image (Group_Id)
                     else "unknown"),
                  Size_Image           =>
                    (if Need_Size
                     then Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Size)
                     else ""),
                  Creation_Time_Image  =>
                    (if Need_Creation and then Creation_Available
                     then Time_Image (Creation_Time) else "unknown"),
                  Creation_Epoch_Image =>
                    (if Need_Creation and then Creation_Available
                     then Epoch_Image (Creation_Time) else "0"),
                  Access_Time_Image    =>
                    (if Need_Access and then Access_Available
                     then Time_Image (Access_Time) else "unknown"),
                  Access_Epoch_Image   =>
                    (if Need_Access and then Access_Available
                     then Epoch_Image (Access_Time) else "0"),
                  Modify_Time_Image    =>
                    (if Need_Modify and then Modify_Available
                     then Time_Image (Modify_Time) else "unknown"),
                  Modify_Epoch_Image   =>
                    (if Need_Modify and then Modify_Available
                     then Epoch_Image (Modify_Time) else "0"),
                  User_Id_Image        =>
                    (if Need_User and then Owner_Available
                     then Posix_Tools.Accounts.Image (User_Id)
                     else "unknown")));
         else
            Emit_Line ("File: " & Path);
            Emit_Line
              ("Size: " & Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Size));
            Emit_Line ("Type: " & Kind_Name (Path, Kind));
            Emit_Line
              ("Mode: "
               & (if Mode_Available
                  then Posix_Tools.Text.File_Modes.Four_Digit_Octal_Image (Mode)
                  else "unknown"));
            if Owner_Available then
               Emit_Line
                 ("Uid: " & Posix_Tools.Accounts.Image (User_Id));
               Emit_Line
                 ("Gid: " & Posix_Tools.Accounts.Image (Group_Id));
            else
               Emit_Line ("Uid: unknown");
               Emit_Line ("Gid: unknown");
            end if;
         end if;
      exception
         when others =>
            --  intentional terminal exception barrier
            Ok := False;
            Flush_Output;
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
               Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Option_Argument, "-c");
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
         Posix_Tools.Commands.Helpers.Usage_Error (Context, Result, Missing_Operand);
         return;
      end if;

      if Has_Format then
         Analyze_Format;
      end if;

      for I in First .. Context.Argument_Count loop
         if I > First and then not Has_Format then
            Emit_Line ("");
         end if;
         Write_One (Context.Argument (I));
      end loop;

      Flush_Output;
      if Context.Output_Failed then
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      elsif Ok then
         Result.Status := Posix_Tools.Exit_Status.Success;
      else
         Result.Status := Posix_Tools.Exit_Status.Operational_Failure;
      end if;
   end Run;

end Posix_Tools.Commands.Stat;
