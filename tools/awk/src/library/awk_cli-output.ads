with Awk_CLI.Diagnostics;
with Awk_CLI.Localization;
with Awk_CLI.Options;

package Awk_CLI.Output is
   --  Presentation layer for CLI-owned text.
   --
   --  AWK program output must bypass this package except for raw stream
   --  forwarding performed by the top-level runner.

   --  @param Mode Color mode to apply to CLI-owned presentation text.
   procedure Set_Color (Mode : Awk_CLI.Options.Color_Mode);

   --  @param Catalog Initialized catalog runtime.
   --  @param Destination_Is_Terminal Whether the help destination is a terminal.
   --  @param No_Color_Active Whether automatic color is disabled by host policy.
   --  @return Localized help text.
   function Help
     (Catalog : Awk_CLI.Localization.Catalog;
      Destination_Is_Terminal : Boolean;
      No_Color_Active        : Boolean := False) return String;

   --  @param Catalog Initialized catalog runtime.
   --  @return Localized version metadata text.
   function Version (Catalog : Awk_CLI.Localization.Catalog) return String;

   --  @param Catalog Initialized catalog runtime.
   --  @param Item Structured diagnostic to render.
   --  @param Destination_Is_Terminal Whether the diagnostic destination is a terminal.
   --  @param No_Color_Active Whether automatic color is disabled by host policy.
   --  @return Localized diagnostic text.
   function Diagnostic_Text
     (Catalog : Awk_CLI.Localization.Catalog;
      Item    : Awk_CLI.Diagnostics.Diagnostic;
      Destination_Is_Terminal : Boolean;
      No_Color_Active        : Boolean := False) return String;
end Awk_CLI.Output;
