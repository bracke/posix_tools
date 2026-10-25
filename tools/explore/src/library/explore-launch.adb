with Explore.Images;
with Explore.Paths;
with Explore.Protocol;

package body Explore.Launch is
   package Unbounded renames Ada.Strings.Unbounded;

   ESC : constant Character := Character'Val (27);

   function Clipboard (Text : String; In_Tmux : Boolean) return String is
     (Explore.Protocol.To_Outer_Terminal (ESC & "]52;c;" & Explore.Images.Base64 (Text) & ESC & "\", In_Tmux));

   function Opener_For (Openers : Opener_Vectors.Vector; Name : String; Is_Text : Boolean) return Opener is
   begin
      for Candidate of Openers loop
         if Candidate.Patterns.Is_Empty then
            return Candidate;
         end if;

         for Pattern of Candidate.Patterns loop
            if Explore.Paths.Glob_Matches (Pattern, Name) then
               return Candidate;
            end if;
         end loop;
      end loop;

      return
        (Patterns => <>,
         Run      => Unbounded.To_Unbounded_String (if Is_Text then Text_Opener else Other_Opener),
         Detach   => not Is_Text);
   end Opener_For;

   function Shell_Arguments
     (Directory : String;
      Script    : String;
      Files     : Explore.String_Vectors.Vector;
      Detach    : Boolean := False) return Posix_Tools.Arguments.Vector
   is
      LF     : constant Character := Character'Val (10);
      Result : Posix_Tools.Arguments.Vector;
   begin
      --  The directory goes in as $0, so that it needs no quoting either.
      Result.Append ("-c");
      Result.Append
        ("cd -- ""$0"" || exit 126" & LF
         & (if Detach then "(" & LF & Script & LF & ") </dev/null >/dev/null 2>&1 &" else Script));
      Result.Append (Directory);

      for File of Files loop
         Result.Append (File);
      end loop;

      return Result;
   end Shell_Arguments;
end Explore.Launch;
