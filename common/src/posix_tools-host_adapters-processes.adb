with Ada.Strings.Unbounded;
with Ada.Environment_Variables;
with Hostkit;
with Hostkit.Process;
with Posix_Tools.Host_Adapters.Environment;

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
      use Ada.Strings.Unbounded;
      Program : constant String := Hostkit.Process.Locate (Utility);
      Host_Arguments : Hostkit.String_Vectors.Vector;
   begin
      if Program = "" then
         Exit_Status := 127;
         return False;
      end if;

      for I in 1 .. Natural (Arguments.Length) loop
         Host_Arguments.Append (To_Unbounded_String (Arguments.Element (I)));
      end loop;

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
end Posix_Tools.Host_Adapters.Processes;
