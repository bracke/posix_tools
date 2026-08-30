with Ada.Environment_Variables;
with Ada.Strings.Unbounded;
with Hostkit;
with Hostkit.Descriptors;
with Hostkit.Process;
with Hostkit.Spawn;
with Posix_Tools.Host_Adapters.Environment;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Host_Adapters.Processes is
   function Equal_Position (Text : String) return Natural is
   begin
      for I in Text'Range loop
         if Text (I) = '=' then
            return I;
         end if;
      end loop;
      return 0;
   end Equal_Position;

   function To_Host_Arguments (Arguments : Posix_Tools.Arguments.Vector) return Hostkit.String_Vectors.Vector is
      use Ada.Strings.Unbounded;
      Result : Hostkit.String_Vectors.Vector;
   begin
      for I in 1 .. Natural (Arguments.Length) loop
         Result.Append (To_Unbounded_String (Arguments.Element (I)));
      end loop;
      return Result;
   end To_Host_Arguments;

   procedure Clear_Pairs (Pairs : Posix_Tools.Arguments.Vector) is
   begin
      for I in 1 .. Natural (Pairs.Length) loop
         declare
            Pair  : constant String := Pairs.Element (I);
            Equal : constant Natural := Equal_Position (Pair);
         begin
            if Equal > Pair'First then
               Ada.Environment_Variables.Clear (Pair (Pair'First .. Equal - 1));
            end if;
         end;
      end loop;
   end Clear_Pairs;

   procedure Set_Pairs (Pairs : Posix_Tools.Arguments.Vector) is
   begin
      for I in 1 .. Natural (Pairs.Length) loop
         declare
            Pair  : constant String := Pairs.Element (I);
            Equal : constant Natural := Equal_Position (Pair);
         begin
            if Equal > Pair'First then
               Ada.Environment_Variables.Set (Pair (Pair'First .. Equal - 1), Pair (Equal + 1 .. Pair'Last));
            end if;
         end;
      end loop;
   end Set_Pairs;

   function Run
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
   is
      Program : constant String := Hostkit.Process.Locate (Utility);
      Host_Arguments : constant Hostkit.String_Vectors.Vector := To_Host_Arguments (Arguments);
   begin
      if Program = "" then
         Exit_Status := 127;
         return False;
      end if;
      if Hostkit.Process.Run (Program, Host_Arguments, Exit_Status) then
         return True;
      end if;

      Exit_Status := 126;
      return False;
   end Run;

   function Run_With_Environment
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Environment : Posix_Tools.Arguments.Vector;
      Exit_Status : out Integer) return Boolean
   is
      Original : constant Posix_Tools.Arguments.Vector := Posix_Tools.Host_Adapters.Environment.Pairs;
      Started  : Boolean := False;
   begin
      Clear_Pairs (Original);
      Set_Pairs (Environment);
      Started := Run (Utility, Arguments, Exit_Status);
      Clear_Pairs (Environment);
      Set_Pairs (Original);
      return Started;
   exception
      when others =>
         Clear_Pairs (Environment);
         Set_Pairs (Original);
         Exit_Status := 125;
      return False;
   end Run_With_Environment;

   function Run_With_Nice_Adjustment
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Adjustment  : Integer;
      Exit_Status : out Integer) return Boolean
   is
      use Ada.Strings.Unbounded;

      Nice_Program : constant String := Hostkit.Process.Locate ("nice");
      Host_Arguments : Hostkit.String_Vectors.Vector;
   begin
      if Nice_Program = "" then
         Exit_Status := 127;
         return False;
      end if;

      Host_Arguments.Append (To_Unbounded_String ("-n"));
      Host_Arguments.Append
        (To_Unbounded_String (Posix_Tools.Text.Numeric_Images.Integer_Image (Adjustment)));
      Host_Arguments.Append (To_Unbounded_String (Utility));
      for I in 1 .. Natural (Arguments.Length) loop
         Host_Arguments.Append (To_Unbounded_String (Arguments.Element (I)));
      end loop;

      if Hostkit.Process.Run (Nice_Program, Host_Arguments, Exit_Status) then
         return True;
      end if;

      Exit_Status := 126;
      return False;
   exception
      when others =>
         Exit_Status := 125;
         return False;
   end Run_With_Nice_Adjustment;

   function Run_With_Timeout
     (Utility     : String;
      Arguments   : Posix_Tools.Arguments.Vector;
      Timeout_Ms  : Natural;
      Exit_Status : out Integer;
      Timed_Out   : out Boolean) return Boolean
   is
      Program : constant String := Hostkit.Process.Locate (Utility);
      Host_Arguments : constant Hostkit.String_Vectors.Vector := To_Host_Arguments (Arguments);
      Outcome : Hostkit.Process.Process_Outcome;
   begin
      Timed_Out := False;

      if Program = "" then
         Exit_Status := 127;
         return False;
      end if;

      Outcome :=
        Hostkit.Process.Run_Captured
          (Program    => Program,
           Arguments  => Host_Arguments,
           Timeout_Ms => Timeout_Ms);

      Timed_Out := Outcome.Timed_Out;
      Exit_Status := Outcome.Exit_Status;
      if not Outcome.Started then
         Exit_Status := 126;
      end if;
      return Outcome.Started;
   exception
      when others =>
         Timed_Out := False;
         Exit_Status := 125;
         return False;
   end Run_With_Timeout;

   function Run_With_Redirected_Output
     (Utility         : String;
      Arguments       : Posix_Tools.Arguments.Vector;
      Output_Path     : String;
      Redirect_Output : Boolean;
      Redirect_Error  : Boolean;
      Exit_Status     : out Integer) return Boolean
   is
      package Descriptors renames Hostkit.Descriptors;
      package Spawn renames Hostkit.Spawn;

      Program        : constant String := Hostkit.Process.Locate (Utility);
      Host_Arguments : constant Hostkit.String_Vectors.Vector := To_Host_Arguments (Arguments);
      Output_File    : Descriptors.Descriptor := Descriptors.Invalid;
      Options        : Spawn.Options;
      Child          : Spawn.Process_Handle;
      Started        : Spawn.Spawn_Outcome;
      Status         : Spawn.Status;
   begin
      if Program = "" then
         Exit_Status := 127;
         return False;
      end if;

      if Redirect_Output then
         if Output_Path = ""
           or else not Descriptors.Open_File (Output_Path, Descriptors.Open_Write_Append, Output_File)
         then
            Exit_Status := 126;
            return False;
         end if;
      end if;

      if Redirect_Output then
         Options.Output := Output_File;
      end if;

      if Redirect_Error then
         Options.Error_Output := (if Redirect_Output then Output_File else Descriptors.Standard_Output);
      end if;

      Options.Reset_Signals := False;
      Started := Spawn.Start (Program, Host_Arguments, Options, Child);
      Descriptors.Close (Output_File);

      case Started is
         when Spawn.Spawn_Ok =>
            null;
         when Spawn.Spawn_Not_Found =>
            Exit_Status := 127;
            return False;
         when others =>
            Exit_Status := 126;
            return False;
      end case;

      if not Spawn.Wait (Child, Spawn.Wait_Block, Status) then
         Exit_Status := 125;
         return False;
      end if;

      case Status.State is
         when Spawn.Wait_Exited =>
            Exit_Status := Status.Exit_Code;
         when Spawn.Wait_Signalled =>
            Exit_Status := 128 + Status.Raw_Signal_Number;
         when others =>
            Exit_Status := 125;
      end case;

      return True;
   exception
      when others =>
         Hostkit.Descriptors.Close (Output_File);
         Exit_Status := 125;
         return False;
   end Run_With_Redirected_Output;
end Posix_Tools.Host_Adapters.Processes;
