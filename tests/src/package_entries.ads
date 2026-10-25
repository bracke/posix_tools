--  Calls Add_Entry once for every file the source package holds, in byte
--  order of the path: the root files below, and every ordinary file under
--  the packaged trees (.github, common, docs, fixtures, generated, src,
--  tests, tools) except what .gitignore keeps out of the repository (Alire
--  state, build products, Alire-generated configuration, compiler and editor
--  leftovers) and the files the package step writes itself or a release
--  writes after it: generated/package-files.txt (Generate_Package_Manifest
--  adds it last), generated/package-manifest.txt, and
--  generated/release-checksums.txt. generated/test-work holds test scratch
--  files and is skipped too. Metadata_Checks.Packaging compares the result
--  with the files git tracks, so a stray untracked file or a tracked one the
--  rules miss is reported rather than packaged or lost.
generic
   with procedure Add_Entry (Relative_Path : String);
procedure Package_Entries;
