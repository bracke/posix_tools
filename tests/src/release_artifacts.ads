--  What the docs, package and release subcommands write: the generated
--  documentation, the package manifest, the source archive and the release
--  checksums, and the clean tree a release starts from.
package Release_Artifacts is
   --  generated/command_inventory.csv, the manual pages, the manual index
   --  and docs/commands/index.md.
   procedure Generate_Docs;
   --  generated/package-files.txt and generated/package-manifest.txt.
   procedure Generate_Package_Manifest;
   --  The 7z source archive of the package file list, tested once made.
   procedure Generate_Release_Archive;
   --  generated/release-checksums.txt, from the manifest, the archive and
   --  the binaries the build made.
   procedure Generate_Release_Checksums;
   --  Fail unless git reports the source tree clean.
   procedure Require_Clean_Source_Tree;
end Release_Artifacts;
