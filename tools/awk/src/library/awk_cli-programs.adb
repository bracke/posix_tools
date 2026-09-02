package body Awk_CLI.Programs is
   use type Ada.Containers.Count_Type;
   package D renames Awk_CLI.Diagnostics;

   function Count_Lines (Text : String) return Natural is
      Count : Natural := 0;
   begin
      if Text = "" then
         return 0;
      end if;
      for C of Text loop
         if C = ASCII.LF then
            Count := Count + 1;
         end if;
      end loop;
      if Text (Text'Last) /= ASCII.LF then
         Count := Count + 1;
      end if;
      return Count;
   end Count_Lines;

   function Ends_With_LF (Text : String) return Boolean is
     (Text'Length > 0 and then Text (Text'Last) = ASCII.LF);

   function Resolve
     (Options   : Awk_CLI.Options.Parsed_Options;
      Read_File : not null access function
        (Path : String; Content : out U.Unbounded_String) return Awk_CLI.Platform.Read_Status)
      return Resolve_Result
   is
      Source       : Program_Source;
      Current_Line : Positive := 1;
   begin
      if not Options.Program_Files.Is_Empty then
         for File of Options.Program_Files loop
            declare
               Path    : constant String := U.To_String (File.Name);
               Content : U.Unbounded_String;
               Lines   : Natural;
               Status  : constant Awk_CLI.Platform.Read_Status :=
                 Read_File (Path, Content);
            begin
               case Status is
                  when Awk_CLI.Platform.Read_Success =>
                     null;
                  when Awk_CLI.Platform.Open_Failed =>
                     return
                       (Ok => False,
                        Diagnostic =>
                          D.Make ("awk.program_file.open_failed", D.Error, D.Program_Source,
                                  Name => "path", Value => Path));
                  when Awk_CLI.Platform.Read_Failed =>
                     return
                       (Ok => False,
                        Diagnostic =>
                          D.Make ("awk.program_file.read_failed", D.Error, D.Program_Source,
                                  Name => "path", Value => Path));
               end case;

               if U.Length (Source.Text) > 0
                 and then not Ends_With_LF (U.To_String (Source.Text))
               then
                  U.Append (Source.Text, ASCII.LF);
               end if;

               Lines := Count_Lines (U.To_String (Content));
               U.Append (Source.Text, Content);
               Source.Segments.Append
                 (Source_Segment'
                    (Display_Name => File.Name,
                     Start_Line   => Current_Line,
                     End_Line     => (if Lines = 0 then Current_Line - 1 else Current_Line + Lines - 1)));
               if Lines > 0 then
                  Current_Line := Current_Line + Lines;
               end if;
            end;
         end loop;
         Source.Operands := Options.Operands;
      else
         if Options.Operands.Is_Empty then
            return
              (Ok => False,
               Diagnostic =>
                 D.Make ("awk.usage.missing_program", D.Error, D.Usage,
                         Hint_Id => "awk.hint.use_help"));
         end if;

         Source.Text := Options.Operands.First_Element.Text;
         Source.Segments.Append
           (Source_Segment'
              (Display_Name => U.To_Unbounded_String ("awk.source.command_line"),
               Start_Line => 1,
               End_Line => Count_Lines (U.To_String (Source.Text))));

         if Options.Operands.Length > 1 then
            for Position in Options.Operands.First_Index + 1 .. Options.Operands.Last_Index loop
               Source.Operands.Append (Options.Operands.Element (Position));
            end loop;
         end if;
      end if;

      return (Ok => True, Source => Source);
   end Resolve;
end Awk_CLI.Programs;
