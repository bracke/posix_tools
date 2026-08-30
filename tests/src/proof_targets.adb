with Ada.Strings.Unbounded;

procedure Proof_Targets (Gnatprove : String) is
   use Ada.Strings.Unbounded;

   type Proof_Unit is record
      Name  : Unbounded_String;
      Level : Unbounded_String;
   end record;

   Units : constant array (Positive range <>) of Proof_Unit :=
     [(To_Unbounded_String ("posix_tools"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.version"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.command_inventory"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.command_inventory.tables"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.extension_options"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.numbers"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.paths"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.utf_8"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.classification"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.whitespace_data"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.streams.counting"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.counts"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.tail_rings"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.tail_counts"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.wc_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.exit_status"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.commands.results"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.commands"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.streams"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.escaping"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.checksum_lines"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.checksums"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.cut_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.dd_conversions"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.duration_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.diagnostic_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.file_magic_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.file_operands"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.glob_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.line_breaks"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.locale_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.byte_classes"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.matching"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.nice_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.base_parsing"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.suffixes"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.tab_stops"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.logical_paths"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.portable_paths"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.test_operators"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.hex_digests"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.sort_modifiers"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.paste_delimiters"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.printf_escapes"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.seq_formats"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.find_expressions"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.od_formats"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.signal_names"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.nl_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.decimal_parsing"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.file_modes"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.numeric_images"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.option_parsing"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.octal_modes"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.octal_parsing"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.owner_groups"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.time_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.touch_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.xargs_fields"), To_Unbounded_String ("1")),
      (To_Unbounded_String ("posix_tools.text.file_modes"), To_Unbounded_String ("2"))];
begin
   for Unit of Units loop
      Prove_Target
        (Gnatprove => Gnatprove,
         Label     => "proof target " & To_String (Unit.Name),
         Unit_Name => To_String (Unit.Name),
         Mode      => "prove",
         Level     => To_String (Unit.Level));
   end loop;
end Proof_Targets;
