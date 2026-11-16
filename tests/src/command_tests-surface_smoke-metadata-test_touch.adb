separate (Command_Tests.Surface_Smoke.Metadata)
   procedure Test_Touch (T : in out Surface_Fixture) is
      pragma Unreferenced (T);
      Context : Test_Contexts.Capturing_Context;
      Result  : Posix_Tools.Commands.Results.Result;
   begin
      Write_File (Source, "copy-data");
      Context.Initialize ("touch", One_Arg (Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Ada.Directories.Exists (Touched), "touch created file");

      Write_File (Touched, "touch-data");
      Context.Initialize ("touch", One_Arg (Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "touch existing status");
      Context.Initialize ("cat", One_Arg (Touched));
      Posix_Tools.Commands.Cat.Run (Context, Result);
      AUnit.Assertions.Assert (Test_Contexts.Output (Context) = "touch-data", "touch preserves existing data");

      Context.Initialize ("touch", Two_Args ("-c", No_Create));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (No_Create),
         "touch -c leaves missing file absent");

      Context.Initialize ("touch", Two_Args ("-am", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert (Result.Status = Posix_Tools.Exit_Status.Success, "touch -am status");

      GNAT.OS_Lib.Set_File_Last_Modify_Time_Stamp
        (Touched,
         GNAT.OS_Lib.GM_Time_Of
           (2026,
            8,
            12,
            10,
            0,
            0));
      Context.Initialize ("touch", Three_Args ("-a", "-t202608121540.11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (10 * 3_600))),
         "touch -a leaves modification timestamp unchanged");
      declare
         --  touch -t names a local time: 15:40:11 at this host's offset.
         Expected_Access : constant Ada.Calendar.Time :=
           Ada.Calendar.Formatting.Time_Of
             (2026, 8, 12, 15, 40, 11,
              Time_Zone => Ada.Calendar.Time_Zones.UTC_Time_Offset (Ada.Calendar.Time_Of (2026, 8, 12)));
         Available : Boolean;
         Accessed  : constant Ada.Calendar.Time := Hostkit.Metadata.File_Access_Time (Touched, Available);
      begin
         if Available then
            AUnit.Assertions.Assert
              (Time_Near (Accessed, Expected_Access),
               "touch -a applies explicit access timestamp: got "
               & Ada.Calendar.Formatting.Image (Accessed) & " expected "
               & Ada.Calendar.Formatting.Image (Expected_Access) & " offset"
               & Ada.Calendar.Time_Zones.UTC_Time_Offset (Ada.Calendar.Time_Of (2026, 8, 12))'Image);
         end if;
      end;

      Context.Initialize ("touch", Three_Args ("-m", "-t202608121540.11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 40 * 60 + 11))),
         "touch -m applies explicit modification timestamp");

      --  A reference time far from both now and the time Touched has, so
      --  a touch that ignored -r could not land near it.
      AUnit.Assertions.Assert
        (Hostkit.Metadata.Set_File_Times (Source, 1_612_325_106, 1_646_370_367),
         "touch -r reference time setup");
      Context.Initialize ("touch", Three_Args ("-r", Source, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near (Ada.Directories.Modification_Time (Touched), Ada.Directories.Modification_Time (Source)),
         "touch -r status and timestamp");

      AUnit.Assertions.Assert
        (Hostkit.Metadata.Set_File_Times (Touched, 1_700_000_000, 1_700_000_000),
         "touch compact -r target time setup");
      Context.Initialize ("touch", Two_Args ("-r" & Source, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near (Ada.Directories.Modification_Time (Touched), Ada.Directories.Modification_Time (Source)),
         "touch compact -r status and timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121530.45", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 30 * 60 + 45))),
         "touch -t status and timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121531", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 31 * 60))),
         "touch -t explicit century minute timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202608121531.46", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (15 * 3_600 + 31 * 60 + 46))),
         "touch -t explicit century seconds timestamp");

      Context.Initialize ("touch", Two_Args ("-t08121530", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of
              (Ada.Calendar.Year (Ada.Calendar.Clock), 8, 12, Duration (15 * 3_600 + 30 * 60))),
         "touch compact -t status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "202608121631.05", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 31 * 60 + 5))),
         "touch -d status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d202608121632.06", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 32 * 60 + 6))),
         "touch compact -d status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:33:07", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 33 * 60 + 7))),
         "touch -d ISO date-time status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-12 16:34:08", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 34 * 60 + 8))),
         "touch compact -d spaced date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:35:09Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 35 * 60 + 9))),
         "touch -d UTC date-time status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-12 16:36:10Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (16 * 3_600 + 36 * 60 + 10))),
         "touch compact -d UTC spaced date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12T16:35:09+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (14 * 3_600 + 5 * 60 + 9))),
         "touch -d positive numeric offset status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-12 16:36:10-0330", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 12, Duration (20 * 3_600 + 6 * 60 + 10))),
         "touch -d negative numeric offset status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, 0.0)),
         "touch -d date-only status and timestamp");

      Context.Initialize ("touch", Two_Args ("-d2026-08-13T17:45", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 45 * 60))),
         "touch compact -d minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:46Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 46 * 60))),
         "touch -d UTC minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:47+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (15 * 3_600 + 17 * 60))),
         "touch -d positive offset minute-precision status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026/08/13 17:48:11", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 48 * 60 + 11))),
         "touch -d slash date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13t17:49:12Z", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 49 * 60 + 12))),
         "touch -d lowercase-t UTC date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "2026-08-13T17:50:13.987+02:30", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (15 * 3_600 + 20 * 60 + 13))),
         "touch -d fractional offset date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Aug 13 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 51 * 60 + 14))),
         "touch -d abbreviated month-name date-time status and timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "August 13, 2026 17:52", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 52 * 60))),
         "touch -d full month-name minute timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Sep 14 2026", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 9, 14, 0.0)),
         "touch -d month-name date-only timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "13 Aug 2026 17:53:16", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 8, 13, Duration (17 * 3_600 + 53 * 60 + 16))),
         "touch -d day-first abbreviated month-name timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "14 September 2026", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then Time_Near
           (Ada.Directories.Modification_Time (Touched),
            Ada.Calendar.Time_Of (2026, 9, 14, 0.0)),
         "touch -d day-first full month-name date-only timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "noon", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      declare
         Year : Ada.Calendar.Year_Number;
         Month : Ada.Calendar.Month_Number;
         Day : Ada.Calendar.Day_Number;
         Seconds : Duration;
      begin
         Ada.Calendar.Split (Ada.Calendar.Clock, Year, Month, Day, Seconds);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near
              (Ada.Directories.Modification_Time (Touched),
               Ada.Calendar.Time_Of (Year, Month, Day, Duration (12 * 3_600))),
            "touch -d noon timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "2 hours ago", Touched));
      declare
         Expected : constant Ada.Calendar.Time := Ada.Calendar.Clock - Duration (2 * 3_600);
      begin
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near (Ada.Directories.Modification_Time (Touched), Expected),
            "touch -d relative hours ago timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "+1 day", Touched));
      declare
         Expected : constant Ada.Calendar.Time := Ada.Calendar.Clock + 86_400.0;
      begin
         Posix_Tools.Commands.Touch.Run (Context, Result);
         AUnit.Assertions.Assert
           (Result.Status = Posix_Tools.Exit_Status.Success
            and then Time_Near (Ada.Directories.Modification_Time (Touched), Expected),
            "touch -d relative plus day timestamp");
      end;

      Context.Initialize ("touch", Three_Args ("-d", "bad", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid -d timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "Nope 13 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid month-name -d timestamp");

      Context.Initialize ("touch", Three_Args ("-d", "32 Aug 2026 17:51:14", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid day-first month-name -d timestamp");

      Context.Initialize ("touch", Three_Args ("-t", "202613121530", Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Invalid_Usage,
         "touch rejects invalid timestamp");

      Context.Initialize ("touch", Three_Args ("-r", No_Create, Touched));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Operational_Failure,
         "touch missing reference status");

      Context.Initialize ("touch", Two_Args ("-ac", No_Create));
      Posix_Tools.Commands.Touch.Run (Context, Result);
      AUnit.Assertions.Assert
        (Result.Status = Posix_Tools.Exit_Status.Success
         and then not Ada.Directories.Exists (No_Create),
         "touch grouped -ac leaves missing file absent");
   end Test_Touch;
