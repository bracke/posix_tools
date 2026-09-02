package body Awk_CLI.Redirections is
   package D renames Awk_CLI.Diagnostics;

   function Materialize
     (Outputs    : Redirection_Vectors.Vector;
      Write_File : not null access function
        (Path : String; Content : String; Append : Boolean) return Write_Status)
      return Materialize_Result
   is
   begin
      for Item of Outputs loop
         declare
            Path : constant String := U.To_String (Item.Path);
            Status : constant Write_Status :=
              Write_File (Path, U.To_String (Item.Content), Item.Append);
         begin
            case Status is
               when Write_Success =>
                  null;
               when Open_Failed =>
                  return
                    (Ok => False,
                     Diagnostic =>
                       D.Make ("awk.output_file.open_failed", D.Error, D.Output,
                               Name => "path", Value => Path));
               when Write_Failed =>
                  return
                    (Ok => False,
                     Diagnostic =>
                       D.Make ("awk.output_file.write_failed", D.Error, D.Output,
                               Name => "path", Value => Path));
            end case;
         end;
      end loop;
      return (Ok => True);
   end Materialize;
end Awk_CLI.Redirections;
