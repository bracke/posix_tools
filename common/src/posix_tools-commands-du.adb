with Ada.Containers.Indefinite_Vectors;
with Posix_Tools.Commands.Helpers;
with Posix_Tools.Counts;
with Posix_Tools.Exit_Status;
with Posix_Tools.Host_Adapters.File_System;
with Posix_Tools.Text.Numeric_Images;

package body Posix_Tools.Commands.Du is
   package FS renames Posix_Tools.Host_Adapters.File_System;
   package String_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);

   use type Posix_Tools.Host_Adapters.File_System.File_Kind;

   procedure Run
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result)
   is
      First        : Positive := 1;
      All_Entries  : Boolean := False;
      Summary_Only : Boolean := False;
      Unit_Size    : Long_Long_Integer := 512;
      All_Ok       : Boolean := True;
      Seen_Dirs    : String_Vectors.Vector;

      function Allocated_Units (Path : String) return Long_Long_Integer;
      function Already_Seen_Directory (Path : String) return Boolean;
      procedure Print_Usage (Units : Long_Long_Integer; Path : String);
      procedure Walk
        (Path        : String;
         Top_Level   : Boolean;
         Total_Units : in out Long_Long_Integer;
         Ok          : in out Boolean);

      function Allocated_Units (Path : String) return Long_Long_Integer is
         Available : Boolean := False;
         Bytes     : constant Long_Long_Integer := FS.Allocated_Size (Path, Available);
      begin
         return Posix_Tools.Counts.Rounded_Units
           ((if Available then Bytes else FS.Size (Path)), Unit_Size);
      end Allocated_Units;

      function Already_Seen_Directory (Path : String) return Boolean is
      begin
         for I in 1 .. Natural (Seen_Dirs.Length) loop
            begin
               if FS.Same_File (Path, Seen_Dirs.Element (I)) then
                  return True;
               end if;
            exception
               when others =>
                  null;
            end;
         end loop;
         return False;
      end Already_Seen_Directory;

      procedure Print_Usage (Units : Long_Long_Integer; Path : String) is
      begin
         if not Context.Output_Failed then
            Context.Put_Line
              (Posix_Tools.Text.Numeric_Images.Long_Long_Integer_Image (Units)
               & Character'Val (9) & Path);
         end if;
      end Print_Usage;

      procedure Walk
        (Path        : String;
         Top_Level   : Boolean;
         Total_Units : in out Long_Long_Integer;
         Ok          : in out Boolean)
      is
         Kind : constant FS.File_Kind := FS.Kind (Path);
      begin
         case Kind is
            when FS.Missing_File =>
               Posix_Tools.Commands.Helpers.Subject_Operational_Error
                 (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
               Ok := False;
            when FS.Ordinary_File | FS.Special_File =>
               declare
                  Size_Units : Long_Long_Integer := 0;
               begin
                  begin
                     Size_Units := Allocated_Units (Path);
                  exception
                     when others =>
                        Posix_Tools.Commands.Helpers.Subject_Operational_Error
                          (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
                        Ok := False;
                        return;
                  end;

                  Total_Units := Total_Units + Size_Units;
                  if All_Entries or else Top_Level then
                     Print_Usage (Size_Units, Path);
                  end if;
               end;
            when FS.Directory =>
               declare
                  Directory_Units : Long_Long_Integer := 0;
                  Iteration_Ok    : Boolean := True;
                  Full_Path       : constant String := FS.Full_Name (Path);

                  procedure Visit_Child
                    (Name      : String;
                     Full_Name : String;
                     Stop      : in out Boolean);

                  procedure Visit_Child
                    (Name      : String;
                     Full_Name : String;
                     Stop      : in out Boolean)
                  is
                     pragma Unreferenced (Name);
                     Child_Units : Long_Long_Integer := 0;
                  begin
                     Walk (Full_Name, False, Child_Units, Ok);
                     Directory_Units := Directory_Units + Child_Units;
                     Stop := Context.Output_Failed;
                  end Visit_Child;

                  procedure Each is new FS.For_Each_Directory_Entry (Visit_Child);
               begin
                  if Already_Seen_Directory (Path) then
                     Total_Units := 0;
                     return;
                  end if;
                  Seen_Dirs.Append (Full_Path);
                  begin
                     Directory_Units := Allocated_Units (Path);
                  exception
                     when others =>
                        Directory_Units := 0;
                  end;

                  Each (Path, Iteration_Ok);
                  if not Iteration_Ok then
                     Posix_Tools.Commands.Helpers.Subject_Operational_Error
                       (Context, Path, "posix_tools.diagnostic.file.open_failed", "cannot open file");
                     Ok := False;
                  end if;

                  Total_Units := Total_Units + Directory_Units;
                  if not Summary_Only or else Top_Level then
                     Print_Usage (Directory_Units, Path);
                  end if;
               end;
         end case;
      end Walk;
   begin
      if Posix_Tools.Commands.Helpers.Intercept_Extension (Context, Result) then
         return;
      end if;

      while First <= Context.Argument_Count loop
         declare
            Arg : constant String := Context.Argument (First);
         begin
            exit when Arg = "" or else Arg = "-";
            if Arg = "--" then
               First := First + 1;
               exit;
            elsif Arg'Length >= 2 and then Arg (Arg'First) = '-' then
               for I in Arg'First + 1 .. Arg'Last loop
                  case Arg (I) is
                     when 'a' => All_Entries := True;
                     when 's' => Summary_Only := True;
                     when 'k' => Unit_Size := 1024;
                     when others =>
                        Posix_Tools.Commands.Helpers.Usage_Error
                          (Context, Result, "unknown option '-" & Arg (I) & "'");
                        return;
                  end case;
               end loop;
               First := First + 1;
            else
               exit;
            end if;
         end;
      end loop;

      if First > Context.Argument_Count then
         declare
            Total : Long_Long_Integer := 0;
         begin
            Seen_Dirs.Clear;
            Walk (".", True, Total, All_Ok);
         end;
      else
         for I in First .. Context.Argument_Count loop
            declare
               Total : Long_Long_Integer := 0;
            begin
               Seen_Dirs.Clear;
               Walk (Context.Argument (I), True, Total, All_Ok);
               exit when Context.Output_Failed;
            end;
         end loop;
      end if;

      Result.Status :=
        (if Context.Output_Failed or else not All_Ok then Posix_Tools.Exit_Status.Operational_Failure
         else Posix_Tools.Exit_Status.Success);
   end Run;
end Posix_Tools.Commands.Du;
