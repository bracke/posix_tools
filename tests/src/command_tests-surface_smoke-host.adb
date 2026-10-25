with AUnit.Assertions;
with Command_Tests.Surface_Smoke.Fixtures;
with Command_Tests.Surface_Smoke.Helpers;
with Hostkit.Signals;
with Posix_Tools.Commands.Arch;
with Posix_Tools.Commands.Date;
with Posix_Tools.Commands.Df;
with Posix_Tools.Commands.Env;
with Posix_Tools.Commands.Getconf;
with Posix_Tools.Commands.Groups;
with Posix_Tools.Commands.Hostname;
with Posix_Tools.Commands.Id;
with Posix_Tools.Commands.Kill;
with Posix_Tools.Commands.Locale;
with Posix_Tools.Commands.Logname;
with Posix_Tools.Commands.Nice;
with Posix_Tools.Commands.Nohup;
with Posix_Tools.Commands.Printenv;
with Posix_Tools.Commands.Results;
with Posix_Tools.Commands.Sleep;
with Posix_Tools.Commands.Uname;
with Posix_Tools.Commands.Which;
with Posix_Tools.Commands.Whoami;
with Posix_Tools.Exit_Status;
with Test_Contexts;

package body Command_Tests.Surface_Smoke.Host is
   use type Posix_Tools.Exit_Status.Code;
   use Command_Tests.Surface_Smoke.Fixtures;
   use Command_Tests.Surface_Smoke.Helpers;

   procedure Test_Arch (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("arch", No_Args);
      Posix_Tools.Commands.Arch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-machine" & EOL,
         "arch reports machine class");
   end Test_Arch;

   procedure Test_Date (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("date", No_Args);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context)'Length > 1, "date output");

      Context.Initialize ("date", One_Arg ("+%%"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "%" & EOL, "date escaped percent output");

      Context.Initialize ("date", One_Arg ("+blocked"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "date reports standard-output failure");

      Context.Initialize ("date", One_Arg ("+literal"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "literal" & EOL, "date literal format output");

      Context.Initialize ("date", Two_Args ("--", "+%Y"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 5
            and then (for all I in Output'First .. Output'First + 3 => Output (I) in '0' .. '9')
            and then Output (Output'Last) = EOL,
            "date honors end-of-options before format");
      end;

      Context.Initialize ("date", One_Arg ("+%F %T %R %y"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 29
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then Output (Output'First + 10) = ' '
            and then Output (Output'First + 13) = ':'
            and then Output (Output'First + 16) = ':'
            and then Output (Output'First + 19) = ' '
            and then Output (Output'First + 22) = ':'
            and then Output (Output'First + 25) = ' '
            and then Output (Output'First + 28) = EOL,
            "date composite format output");
      end;

      Context.Initialize ("date", One_Arg ("+%x %X"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 18
            and then Output (Output'First + 2) = '/'
            and then Output (Output'First + 5) = '/'
            and then Output (Output'First + 8) = ' '
            and then Output (Output'First + 11) = ':'
            and then Output (Output'First + 14) = ':'
            and then Output (Output'First + 17) = EOL,
            "date localized composite shape output");
      end;

      Context.Initialize ("date", One_Arg ("+%c"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length >= 25
            and then Contains (Output, ":")
            and then not Contains (Output, "%c")
            and then Output (Output'Last) = EOL,
            "date full composite output");
      end;

      Context.Initialize ("date", One_Arg ("+%C %D %e %I %k %l %p %r %u %w %j"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 47
            and then Output (Output'First + 2) = ' '
            and then Output (Output'First + 5) = '/'
            and then Output (Output'First + 8) = '/'
            and then Output (Output'First + 11) = ' '
            and then Output (Output'First + 14) = ' '
            and then Output (Output'First + 17) = ' '
            and then Output (Output'First + 20) = ' '
            and then Output (Output'First + 23) = ' '
            and then Output (Output'First + 26) = ' '
            and then Output (Output'First + 29) = ':'
            and then Output (Output'First + 32) = ':'
            and then Output (Output'First + 35) = ' '
            and then Output (Output'First + 38) = ' '
            and then Output (Output'First + 40) = ' '
            and then Output (Output'First + 42) = ' '
            and then Output (Output'First + 46) = EOL,
            "date extended numeric format output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);

         function Has_Word (Needle : String) return Boolean is
         begin
            return Contains (Output, Needle & " ") or else Contains (Output, " " & Needle & EOL);
         end Has_Word;
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "Mon ") or else Contains (Output, "Tue ") or else Contains (Output, "Wed ")
             or else Contains (Output, "Thu ") or else Contains (Output, "Fri ") or else Contains (Output, "Sat ")
             or else Contains (Output, "Sun "))
            and then (Has_Word ("January") or else Has_Word ("February") or else Has_Word ("March")
              or else Has_Word ("April") or else Has_Word ("May") or else Has_Word ("June")
              or else Has_Word ("July") or else Has_Word ("August") or else Has_Word ("September")
              or else Has_Word ("October") or else Has_Word ("November") or else Has_Word ("December")),
            "date weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "da");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "mandag") or else Contains (Output, "tirsdag")
             or else Contains (Output, "onsdag") or else Contains (Output, "torsdag")
             or else Contains (Output, "fredag") or else Contains (Output, "lørdag")
             or else Contains (Output, "søndag"))
            and then (Contains (Output, "januar") or else Contains (Output, "februar")
              or else Contains (Output, "marts") or else Contains (Output, "april")
              or else Contains (Output, "maj") or else Contains (Output, "juni")
              or else Contains (Output, "juli") or else Contains (Output, "august")
              or else Contains (Output, "september") or else Contains (Output, "oktober")
              or else Contains (Output, "november") or else Contains (Output, "december")),
            "date Danish weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "es");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "lunes") or else Contains (Output, "martes")
             or else Contains (Output, "miercoles") or else Contains (Output, "jueves")
             or else Contains (Output, "viernes") or else Contains (Output, "sabado")
             or else Contains (Output, "domingo"))
            and then (Contains (Output, "enero") or else Contains (Output, "febrero")
              or else Contains (Output, "marzo") or else Contains (Output, "abril")
              or else Contains (Output, "mayo") or else Contains (Output, "junio")
              or else Contains (Output, "julio") or else Contains (Output, "agosto")
              or else Contains (Output, "septiembre") or else Contains (Output, "octubre")
              or else Contains (Output, "noviembre") or else Contains (Output, "diciembre")),
            "date Spanish weekday and month names output");
      end;

      Context.Initialize ("date", One_Arg ("+%a %A %b %B"));
      Test_Contexts.Set_Locale (Context, "zz");
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           ((Contains (Output, "Mon ") or else Contains (Output, "Tue ") or else Contains (Output, "Wed ")
             or else Contains (Output, "Thu ") or else Contains (Output, "Fri ") or else Contains (Output, "Sat ")
             or else Contains (Output, "Sun "))
            and then not Contains (Output, "posix_tools.date."),
            "date unknown locale falls back without message-key leak");
      end;

      Context.Initialize ("date", One_Arg ("+%b %h"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 8
            and then Output (Output'First .. Output'First + 2) =
              Output (Output'First + 4 .. Output'First + 6)
            and then Output (Output'Last) = EOL,
            "date %h aliases abbreviated month name");
      end;

      Context.Initialize ("date", One_Arg ("+%G-%g-%V"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 11
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then not Contains (Output, "%G")
            and then not Contains (Output, "%g")
            and then not Contains (Output, "%V")
            and then Output (Output'Last) = EOL,
            "date ISO week format output");
      end;

      Context.Initialize ("date", One_Arg ("+%U %W"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '0' .. '9'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) = ' '
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'Last) = EOL
            and then not Contains (Output, "%U")
            and then not Contains (Output, "%W"),
            "date POSIX week number output");
      end;

      Context.Initialize ("date", One_Arg ("+%z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '+' | '-'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) in '0' .. '9'
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'First + 5) = EOL,
            "date timezone offset output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "+%z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000" & EOL, "date -u timezone output");

      Context.Initialize ("date", Two_Args ("-u", "+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "CET-1");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0000 UTC" & EOL,
         "date -u overrides TZ fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "GMT+00:00");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ signed colon UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC-0000");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ signed compact UTC output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "UTC+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0230 UTC" & EOL, "date TZ positive fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "GMT-0330");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "-0330 GMT" & EOL, "date TZ negative fixed offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "CET-1");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "-0100 CET" & EOL, "date TZ named hour offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "EST5EDT");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0500 EST" & EOL,
         "date TZ ignores DST suffix after standard offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "EST5EDT,M3.2.0,M11.1.0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0500 EST" & EOL,
         "date TZ ignores DST transition rules after standard offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "FOO+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0230 FOO" & EOL, "date TZ named colon offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "<UTC+1>+02:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0230 UTC+1" & EOL,
         "date TZ quoted non-alphabetic name output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "<-0330>-03:30");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "-0330 -0330" & EOL,
         "date TZ quoted signed name output");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "BAR0");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 BAR" & EOL, "date TZ named zero offset");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "Etc/UTC");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "+0000 UTC" & EOL, "date TZ i18n UTC zone");

      Context.Initialize ("date", One_Arg ("+%z %Z"));
      Test_Contexts.Set_Environment_Value (Context, "TZ", "Asia/Kolkata");
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "+0530 IST" & EOL
         or else Test_Contexts.Output (Context) = "+0530 Asia/Kolkata" & EOL,
         "date TZ i18n regional zone");

      Context.Initialize ("date", Two_Args ("-u", "+%Z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "UTC" & EOL, "date -u timezone name output");

      Context.Initialize ("date", One_Arg ("+%Z"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 6
            and then Output (Output'First) in '+' | '-'
            and then Output (Output'First + 1) in '0' .. '9'
            and then Output (Output'First + 2) in '0' .. '9'
            and then Output (Output'First + 3) in '0' .. '9'
            and then Output (Output'First + 4) in '0' .. '9'
            and then Output (Output'First + 5) = EOL,
            "date local timezone name fallback output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "+%F %T"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length = 20
            and then Output (Output'First + 4) = '-'
            and then Output (Output'First + 7) = '-'
            and then Output (Output'First + 10) = ' '
            and then Output (Output'First + 13) = ':'
            and then Output (Output'First + 16) = ':'
            and then Output (Output'First + 19) = EOL,
            "date -u timestamp shape");
      end;

      Context.Initialize ("date", One_Arg ("+%s"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      declare
         Output : constant String := Test_Contexts.Output (Context);
      begin
         AUnit.Assertions.Assert
           (Output'Length >= 2
            and then Output (Output'Last) = EOL
            and then (for all I in Output'First .. Output'Last - 1 => Output (I) in '0' .. '9'),
            "date epoch seconds output");
      end;

      Context.Initialize ("date", Two_Args ("-u", "010203042026.05"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "date set operand status");
      AUnit.Assertions.Assert (Test_Contexts.Date_Set_Called (Context), "date set operand calls context setter");
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "2026")
         and then Contains (Test_Contexts.Output (Context), "03:04:05"),
         "date set operand reports selected timestamp");

      Context.Initialize ("date", Two_Args ("-u", "01020304"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "date set operand current year status");

      Context.Initialize ("date", Two_Args ("-u", "0102030469"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "1969"),
         "date set operand maps two-digit year 69 to 1969");

      Context.Initialize ("date", Two_Args ("-u", "0102030468"));
      Test_Contexts.Set_Date_Set_Allowed (Context, True);
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Contains (Test_Contexts.Output (Context), "2068"),
         "date set operand maps two-digit year 68 to 2068");

      Context.Initialize ("date", One_Arg ("13320304"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "date rejects invalid set operand");

      Context.Initialize ("date", One_Arg ("010203042026"));
      Posix_Tools.Commands.Date.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "date reports failed system date set");
      AUnit.Assertions.Assert
        (Test_Contexts.Error_Output (Context) = "date: cannot set system date" & EOL,
         "date set failure diagnostic");
   end Test_Date;

   procedure Test_Df (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("df", No_Args);
      Posix_Tools.Commands.Df.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "Filesystem 512-blocks Used Available"),
         "df reports current filesystem capacity");
   end Test_Df;

   procedure Test_Env (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("env", Two_Args ("-i", "NAME=value"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "env status");
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "NAME=value" & EOL, "env -i assignment output");

      Context.Initialize ("env", Two_Args ("-i", "NAME=value"));
      Test_Contexts.Set_Output_Failure_After (Context, 0);
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "env reports standard-output failure");

      Context.Initialize ("env", One_Arg ("B=3"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Test_Contexts.Set_Environment_Value (Context, "B", "2");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A=1" & EOL & "B=3" & EOL,
         "env inherited and replacement output");

      Context.Initialize ("env", Two_Args ("-u", "A"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Test_Contexts.Set_Environment_Value (Context, "B", "2");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "B=2" & EOL,
         "env -u removes inherited variable");

      Context.Initialize ("env", Three_Args ("-u", "A", "A=3"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "A=3" & EOL,
         "env -u allows later replacement");

      Context.Initialize ("env", One_Arg ("-u"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "env -u missing operand status");

      Context.Initialize ("env", One_Arg ("-i"));
      Test_Contexts.Set_Environment_Value (Context, "A", "1");
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "", "env -i empty output");

      Context.Initialize ("env", One_Arg ("=bad"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "env rejects empty name");

      Context.Initialize ("env", Three_Args ("-i", "--", "NAME=value"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Test_Contexts.Output (Context) = "NAME=value" & EOL,
         "env accepts assignment after --");

      Context.Initialize ("env", Four_Args ("-i", "NAME=value", "printenv", "NAME"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "value" & EOL,
         "env executes utility with computed environment");

      Context.Initialize ("env", Two_Args ("-i", "false"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "env returns utility nonzero status");

      Context.Initialize ("env", Two_Args ("--", "-i"));
      Posix_Tools.Commands.Env.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Utility_Not_Found,
         "env treats option after -- as missing utility");
   end Test_Env;

   procedure Test_Getconf (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("getconf", One_Arg ("POSIX_VERSION"));
      Posix_Tools.Commands.Getconf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "202405" & EOL,
         "getconf POSIX_VERSION");

      Context.Initialize ("getconf", One_Arg ("NO_SUCH_VARIABLE"));
      Posix_Tools.Commands.Getconf.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "getconf rejects unknown variable");
   end Test_Getconf;

   procedure Test_Groups (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("groups", No_Args);
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-primary test-extra" & EOL,
         "groups writes current group list");

      Context.Initialize ("groups", One_Arg ("named-user"));
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "named-user : named-extra test-primary" & EOL,
         "groups writes named user group list");

      Context.Initialize ("groups", One_Arg ("missing-user"));
      Posix_Tools.Commands.Groups.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) /= "",
         "groups reports missing user group list");
   end Test_Groups;

   procedure Test_Hostname (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("hostname", No_Args);
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-node" & EOL,
         "hostname reports node name");

      Context.Initialize ("hostname", One_Arg ("new-node"));
      Test_Contexts.Set_Node_Name_Allowed (Context, True);
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Node_Name_Set_Called (Context)
         and then Test_Contexts.Captured_Node_Name (Context) = "new-node",
         "hostname sets node name through context");

      Context.Initialize ("hostname", One_Arg ("denied-node"));
      Posix_Tools.Commands.Hostname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) /= "",
         "hostname reports failed node-name set");
   end Test_Hostname;

   procedure Test_Id (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("id", One_Arg ("-u"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "50000" & EOL,
         "id -u writes identity");

      Context.Initialize ("id", One_Arg ("-G"));
      Posix_Tools.Commands.Id.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "60000 60001" & EOL,
         "id -G writes group list");
   end Test_Id;

   procedure Test_Kill (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("kill", One_Arg ("-l"));
      Posix_Tools.Commands.Kill.Run (Context, Result);
      --  A host with no signals (Windows) has nothing to list.
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then (Test_Contexts.Output (Context)'Length > 0
                   or else not Hostkit.Signals.Is_Supported (Hostkit.Signals.Signal_Terminate)),
         "kill -l lists signals");
   end Test_Kill;

   procedure Test_Locale (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("locale", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LANG", "en_US.UTF-8");
      Posix_Tools.Commands.Locale.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Contains (Test_Contexts.Output (Context), "LANG=""en_US.UTF-8"""),
         "locale reports effective LANG");

      Context.Initialize ("locale", One_Arg ("-a"));
      Posix_Tools.Commands.Locale.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "C" & EOL & "POSIX" & EOL,
         "locale -a portable list");
   end Test_Locale;

   procedure Test_Logname (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("logname", No_Args);
      Test_Contexts.Set_Environment_Value (Context, "LOGNAME", "test-login");
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "test-login" & EOL,
         "logname writes context login name");

      Context.Initialize ("logname", No_Args);
      Posix_Tools.Commands.Logname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "session-user" & EOL,
         "logname falls back to host login database");
   end Test_Logname;

   procedure Test_Nice (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("nice", Two_Args ("-n5", "true"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Nice_Adjustment (Context) = 5,
         "nice applies compact adjustment");

      Context.Initialize ("nice", Two_Args ("-n+", "true"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "nice rejects sign-only adjustment");

      Context.Initialize ("nice", Three_Args ("-n", "2147483648", "true"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "nice rejects overflowing adjustment");

      Context.Initialize ("nice", One_Arg ("false"));
      Posix_Tools.Commands.Nice.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Nice_Adjustment (Context) = 10,
         "nice applies default adjustment");
   end Test_Nice;

   procedure Test_Nohup (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("nohup", One_Arg ("true"));
      Posix_Tools.Commands.Nohup.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "nohup propagates true status");

      Context.Initialize ("nohup", One_Arg ("true"));
      Test_Contexts.Set_Standard_Output_Is_Terminal (Context, True);
      Test_Contexts.Set_Standard_Error_Is_Terminal (Context, True);
      Posix_Tools.Commands.Nohup.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Redirected_Output_Path (Context) = "nohup.out"
         and then Test_Contexts.Redirected_Output_Enabled (Context)
         and then Test_Contexts.Redirected_Error_Enabled (Context),
         "nohup redirects terminal output to nohup.out");
   end Test_Nohup;

   procedure Test_Printenv (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("printenv", One_Arg ("POSIX_TOOLS_TEST_PRINTENV"));
      Test_Contexts.Set_Environment_Value (Context, "POSIX_TOOLS_TEST_PRINTENV", "printed-value");
      Posix_Tools.Commands.Printenv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "printed-value" & EOL,
         "printenv selected variable");

      Context.Initialize ("printenv", One_Arg ("POSIX_TOOLS_TEST_MISSING"));
      Posix_Tools.Commands.Printenv.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "printenv missing variable status");
   end Test_Printenv;

   procedure Test_Sleep (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("sleep", One_Arg ("0"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "",
         "sleep zero status");

      Context.Initialize ("sleep", One_Arg ("0s"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "",
         "sleep seconds suffix status");

      Context.Initialize ("sleep", One_Arg ("0m"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "",
         "sleep minutes suffix status");

      Context.Initialize ("sleep", One_Arg ("0h"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "",
         "sleep hours suffix status");

      Context.Initialize ("sleep", One_Arg ("0d"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "",
         "sleep days suffix status");

      Context.Initialize ("sleep", Two_Args ("0.0", "0.00s"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "",
         "sleep accepts fractional zero durations");

      Context.Initialize ("sleep", No_Args);
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "sleep: missing operand" & EOL,
         "sleep rejects missing operands");

      Context.Initialize ("sleep", One_Arg ("-1"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "sleep: invalid operand '-1'" & EOL,
         "sleep rejects negative durations");

      Context.Initialize ("sleep", Two_Args ("31622400", "1"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "sleep: invalid operand '31622400'" & EOL,
         "sleep rejects duration sums above the implementation limit");

      Context.Initialize ("sleep", One_Arg ("31622400d"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "sleep: invalid operand '31622400d'" & EOL,
         "sleep rejects suffixed durations above the implementation limit");

      Context.Initialize ("sleep", One_Arg ("999999999999999999999999999999999999999"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "sleep: invalid operand '999999999999999999999999999999999999999'" & EOL,
         "sleep rejects overflowing duration");

      Context.Initialize ("sleep", One_Arg ("0x"));
      Posix_Tools.Commands.Sleep.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage
         and then Test_Contexts.Output (Context) = ""
         and then Test_Contexts.Error_Output (Context) = "sleep: invalid operand '0x'" & EOL,
         "sleep rejects unknown suffix");
   end Test_Sleep;

   procedure Test_Uname (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("uname", No_Args);
      Posix_Tools.Commands.Uname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "TestOS" & EOL
         and then Test_Contexts.Error_Output (Context) = "",
         "uname writes system name");

      Context.Initialize ("uname", One_Arg ("-a"));
      Posix_Tools.Commands.Uname.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Test_Contexts.Output (Context) = "TestOS test-node 1.2.3 test-version test-machine" & EOL
         and then Test_Contexts.Error_Output (Context) = "",
         "uname -a writes multiple system fields");
   end Test_Uname;

   procedure Test_Which (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("which", One_Arg ("POSIX_TOOLS_NO_SUCH_COMMAND"));
      Posix_Tools.Commands.Which.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure
         and then Test_Contexts.Output (Context) = "",
         "which reports missing command through status");
   end Test_Which;

   procedure Test_Whoami (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Context.Initialize ("whoami", No_Args);
      Posix_Tools.Commands.Whoami.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success and then Test_Contexts.Output (Context) = "test-user" & EOL,
         "whoami writes name");
   end Test_Whoami;

end Command_Tests.Surface_Smoke.Host;
