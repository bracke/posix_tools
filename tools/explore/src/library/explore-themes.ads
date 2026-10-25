with Explore.Screen;

--  The styles explore draws each part of the screen in, by role, and the
--  names the configuration gives the roles.
package Explore.Themes is
   --  What each part of the screen is drawn in. The first six are the roles
   --  terminal_styles names, for what they mean there: headers, information,
   --  muted notes, errors, warnings, and success.
   type Theme_Role is
     (Header_Role,
      Info_Role,
      Muted_Role,
      Error_Role,
      Warning_Role,
      Success_Role,
      Status_Role,
      Alert_Role,
      Directory_Role,
      Link_Role,
      Missing_Role,
      Marked_Role,
      Cursor_Role,
      Inactive_Cursor_Role,
      Panel_Role,
      Keyword_Role,
      String_Role,
      Comment_Role,
      Number_Role,
      Heading_Role);

   type Theme is array (Theme_Role) of Explore.Screen.Style;

   --  The title, the current path, notes, errors, special files, executable
   --  files, the status line, a message that is an error, directories,
   --  links, broken links, marked entries, the cursor in the current pane and
   --  in the others, the jobs panel, and the parts of coloured source text.
   --  Marked entries and the cursor are laid over an entry's own style.
   Default_Theme : constant Theme :=
     [Header_Role          => (Bold => True, others => <>),
      Info_Role            => (Foreground => Explore.Screen.Blue, Bold => True, others => <>),
      Muted_Role           => (Dim => True, others => <>),
      Error_Role           => (Foreground => Explore.Screen.Red, others => <>),
      Warning_Role         => (Foreground => Explore.Screen.Yellow, others => <>),
      Success_Role         => (Foreground => Explore.Screen.Green, others => <>),
      Status_Role          => (Inverse => True, others => <>),
      Alert_Role           => (Foreground => Explore.Screen.Red, Inverse => True, others => <>),
      Directory_Role       => (Foreground => Explore.Screen.Blue, Bold => True, others => <>),
      Link_Role            => (Foreground => Explore.Screen.Cyan, others => <>),
      Missing_Role         => (Foreground => Explore.Screen.Red, others => <>),
      Marked_Role          => (Foreground => Explore.Screen.Magenta, Bold => True, others => <>),
      Cursor_Role          => (Inverse => True, others => <>),
      Inactive_Cursor_Role => (Background => Explore.Screen.Bright_Black, others => <>),
      Panel_Role           => (Background => Explore.Screen.Bright_Black, others => <>),
      Keyword_Role         => (Foreground => Explore.Screen.Magenta, Bold => True, others => <>),
      String_Role          => (Foreground => Explore.Screen.Green, others => <>),
      Comment_Role         => (Foreground => Explore.Screen.Bright_Black, others => <>),
      Number_Role          => (Foreground => Explore.Screen.Yellow, others => <>),
      Heading_Role         => (Foreground => Explore.Screen.Blue, Bold => True, others => <>)];

   --  A role's name in the configuration: "header", "inactive_cursor", ...
   --  It is the role's own name without the "_Role" all of them end in.
   function Role_Name (Role : Theme_Role) return String;
end Explore.Themes;
