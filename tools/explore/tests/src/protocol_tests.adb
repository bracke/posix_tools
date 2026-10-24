with AUnit.Assertions;
with AUnit.Test_Caller;
with Ada.Strings.Fixed;
with Explore.Protocol;

package body Protocol_Tests is
   package Caller is new AUnit.Test_Caller (Fixture);
   package Protocol renames Explore.Protocol;

   use type Protocol.Capability_Set;

   ESC : constant Character := Character'Val (27);

   function Suite return AUnit.Test_Suites.Access_Test_Suite is
      Result : constant AUnit.Test_Suites.Access_Test_Suite := AUnit.Test_Suites.New_Suite;
   begin
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("protocol:identity parsing", Test_Identity_Parsing'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("protocol:identity rejection", Test_Identity_Rejection'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("protocol:identity query", Test_Identity_Query'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("protocol:tmux passthrough", Test_Passthrough'Access));
      AUnit.Test_Suites.Add_Test
        (Result, Caller.Create ("protocol:screen modes balance", Test_Screen_Modes_Balance'Access));
      return Result;
   end Suite;

   procedure Test_Identity_Parsing (T : in out Fixture) is
      pragma Unreferenced (T);
      Result : Protocol.Identity;
      Valid  : Boolean;
   begin
      Protocol.Parse_Identity ("v=1;caps=kgfx,kgfx-shm,not-yet-invented", Result, Valid);
      AUnit.Assertions.Assert (Valid, "a version and capabilities identify");
      AUnit.Assertions.Assert (Result.Version = 1, "version");
      AUnit.Assertions.Assert
        (Result.Capabilities
         = Protocol.Capability_Set'
             [Protocol.Kitty_Graphics | Protocol.Kitty_Graphics_Shared_Memory => True, others => False],
         "named capabilities only; unknown names are ignored");

      Protocol.Parse_Identity ("future=1;v=12", Result, Valid);
      AUnit.Assertions.Assert (Valid and then Result.Version = 12, "unknown keys are ignored, any order");
      AUnit.Assertions.Assert (Result.Capabilities = Protocol.No_Capabilities, "no caps key, no capabilities");

      for Item in Protocol.Capability loop
         Protocol.Parse_Identity ("v=1;caps=" & Protocol.Capability_Name (Item), Result, Valid);
         AUnit.Assertions.Assert
           (Valid and then Result.Capabilities (Item), "capability round trip " & Protocol.Capability_Name (Item));
      end loop;
   end Test_Identity_Parsing;

   procedure Test_Identity_Query (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Protocol.Identity_Query (In_Tmux => False) = ESC & "]7701;q" & ESC & "\" & ESC & "[c",
         "identity query, then device attributes as the sentinel");
      AUnit.Assertions.Assert
        (Protocol.Identity_Query (In_Tmux => True)
         = Protocol.Passthrough (ESC & "]7701;q" & ESC & "\") & Protocol.Passthrough (ESC & "[c"),
         "inside tmux both reach the outer terminal, so their answers stay in order");
   end Test_Identity_Query;

   procedure Test_Identity_Rejection (T : in out Fixture) is
      pragma Unreferenced (T);

      procedure Reject (Text : String);

      procedure Reject (Text : String) is
         Result : Protocol.Identity;
         Valid  : Boolean;
      begin
         Protocol.Parse_Identity (Text, Result, Valid);
         AUnit.Assertions.Assert (not Valid, "rejected: '" & Text & "'");
      end Reject;
   begin
      Reject ("");
      Reject ("caps=kgfx");
      Reject ("v=0;caps=kgfx");
      Reject ("v=one");
      Reject ("v=");
      Reject ("v=99999");
      Reject ("v");
   end Test_Identity_Rejection;

   procedure Test_Passthrough (T : in out Fixture) is
      pragma Unreferenced (T);
   begin
      AUnit.Assertions.Assert
        (Protocol.Passthrough (ESC & "[c") = ESC & "Ptmux;" & ESC & ESC & "[c" & ESC & "\",
         "every ESC inside is doubled and the whole is a tmux DCS");
      AUnit.Assertions.Assert
        (Protocol.To_Outer_Terminal ("abc", In_Tmux => False) = "abc", "unchanged outside tmux");
   end Test_Passthrough;

   procedure Test_Screen_Modes_Balance (T : in out Fixture) is
      pragma Unreferenced (T);
      Enter : constant String := Protocol.Enter_Screen;
      Leave : constant String := Protocol.Leave_Screen;
      First : Positive := Enter'First;
   begin
      --  Every private mode Enter_Screen changes, Leave_Screen changes back.
      while First <= Enter'Last loop
         declare
            At_Mode : constant Natural := Ada.Strings.Fixed.Index (Enter (First .. Enter'Last), ESC & "[?");
            Final   : Positive;
         begin
            exit when At_Mode = 0;
            Final := At_Mode + 3;

            while Enter (Final) in '0' .. '9' loop
               Final := Final + 1;
            end loop;

            AUnit.Assertions.Assert
              (Ada.Strings.Fixed.Index
                 (Leave, Enter (At_Mode .. Final - 1) & (if Enter (Final) = 'h' then "l" else "h")) > 0,
               "mode changed back on leaving: " & Enter (At_Mode + 1 .. Final));
            First := Final + 1;
         end;
      end loop;

      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Enter, ESC & "[>1u") > 0 and then Ada.Strings.Fixed.Index (Leave, ESC & "[<u") > 0,
         "the keyboard mode pushed on entering is popped on leaving");
      AUnit.Assertions.Assert
        (Ada.Strings.Fixed.Index (Leave, ESC & "[?1049l") = Leave'Last - 7,
         "the alternate screen is left last, after every mode is reset");
   end Test_Screen_Modes_Balance;
end Protocol_Tests;
