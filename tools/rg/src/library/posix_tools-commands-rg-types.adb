with Version.Ignore;

package body Posix_Tools.Commands.Rg.Types is
   LF : constant Character := ASCII.LF;

   Catalog : constant String :=
     "ada: *.adb, *.ads" & LF
     & "agda: *.agda, *.lagda" & LF
     & "aidl: *.aidl" & LF
     & "alire: alire.toml" & LF
     & "amake: *.bp, *.mk" & LF
     & "asciidoc: *.adoc, *.asc, *.asciidoc" & LF
     & "asm: *.S, *.asm, *.s" & LF
     & "asp: *.ascx, *.ascx.cs, *.ascx.vb, *.asp, *.aspx, *.aspx.cs, *.aspx.vb" & LF
     & "ats: *.ats, *.dats, *.hats, *.sats" & LF
     & "avro: *.avdl, *.avpr, *.avsc" & LF
     & "awk: *.awk" & LF
     & "bat: *.bat" & LF
     & "batch: *.bat" & LF
     & "bazel: *.BUILD, *.bazel, *.bazelrc, *.bzl, BUILD, MODULE.bazel"
     & ", WORKSPACE, WORKSPACE.bazel, WORKSPACE.bzlmod" & LF
     & "bitbake: *.bb, *.bbappend, *.bbclass, *.conf, *.inc" & LF
     & "boxlang: *.bx, *.bxm, *.bxs" & LF
     & "brotli: *.br" & LF
     & "buildstream: *.bst" & LF
     & "bzip2: *.bz2, *.tbz2" & LF
     & "c: *.[chH], *.[chH].in, *.cats" & LF
     & "cabal: *.cabal" & LF
     & "candid: *.did" & LF
     & "carp: *.carp" & LF
     & "cbor: *.cbor" & LF
     & "ceylon: *.ceylon" & LF
     & "cfml: *.cfc, *.cfm" & LF
     & "clojure: *.clj, *.cljc, *.cljs, *.cljx" & LF
     & "cmake: *.cmake, CMakeLists.txt" & LF
     & "cmd: *.bat, *.cmd" & LF
     & "cml: *.cml" & LF
     & "coffeescript: *.coffee" & LF
     & "config: *.cfg, *.conf, *.config, *.ini" & LF
     & "container: *Containerfile*, *Dockerfile*" & LF
     & "coq: *.v" & LF
     & "cpp: *.[ChH], *.[ChH].in, *.[ch]pp, *.[ch]pp.in, *.[ch]xx, *.[ch]xx.in"
     & ", *.cc, *.cc.in, *.hh, *.hh.in, *.inl" & LF
     & "creole: *.creole" & LF
     & "crystal: *.cr, *.ecr, Projectfile, shard.yml" & LF
     & "cs: *.cs" & LF
     & "csharp: *.cs" & LF
     & "cshtml: *.cshtml" & LF
     & "csproj: *.csproj" & LF
     & "css: *.css, *.scss" & LF
     & "csv: *.csv" & LF
     & "cuda: *.cu, *.cuh" & LF
     & "cython: *.pxd, *.pxi, *.pyx" & LF
     & "d: *.d" & LF
     & "dart: *.dart" & LF
     & "devicetree: *.dts, *.dtsi, *.dtso" & LF
     & "dhall: *.dhall" & LF
     & "diff: *.diff, *.patch" & LF
     & "dita: *.dita, *.ditamap, *.ditaval" & LF
     & "docker: *Dockerfile*" & LF
     & "dockercompose: docker-compose.*.yml, docker-compose.yml" & LF
     & "dts: *.dts, *.dtsi" & LF
     & "dvc: *.dvc, Dvcfile" & LF
     & "ebuild: *.ebuild, *.eclass" & LF
     & "edn: *.edn" & LF
     & "elisp: *.el" & LF
     & "elixir: *.eex, *.ex, *.exs, *.heex, *.leex, *.livemd" & LF
     & "elm: *.elm" & LF
     & "erb: *.erb" & LF
     & "erlang: *.erl, *.hrl" & LF
     & "fennel: *.fnl" & LF
     & "fidl: *.fidl" & LF
     & "fish: *.fish" & LF
     & "flatbuffers: *.fbs" & LF
     & "fortran: *.F, *.F77, *.F90, *.F95, *.f, *.f77, *.f90, *.f95, *.pfo" & LF
     & "fsharp: *.fs, *.fsi, *.fsx" & LF
     & "fut: *.fut" & LF
     & "gap: *.g, *.gap, *.gd, *.gi, *.tst" & LF
     & "gdscript: *.gd" & LF
     & "gleam: *.gleam" & LF
     & "gn: *.gn, *.gni" & LF
     & "go: *.go" & LF
     & "gprbuild: *.gpr" & LF
     & "gradle: *.gradle, *.gradle.kts, gradle-wrapper.*, gradle.properties, gradlew, gradlew.bat" & LF
     & "graphql: *.graphql, *.graphqls" & LF
     & "groovy: *.gradle, *.groovy" & LF
     & "gzip: *.gz, *.tgz" & LF
     & "h: *.h, *.hh, *.hpp" & LF
     & "haml: *.haml" & LF
     & "hare: *.ha" & LF
     & "haskell: *.c2hs, *.cpphs, *.hs, *.hsc, *.lhs" & LF
     & "hbs: *.hbs" & LF
     & "hs: *.hs, *.lhs" & LF
     & "html: *.ejs, *.htm, *.html" & LF
     & "hurl: *.hurl" & LF
     & "hy: *.hy" & LF
     & "idris: *.idr, *.lidr" & LF
     & "janet: *.janet" & LF
     & "java: *.java, *.jsp, *.jspx, *.properties" & LF
     & "jinja: *.j2, *.jinja, *.jinja2" & LF
     & "jl: *.jl" & LF
     & "js: *.cjs, *.js, *.jsx, *.mjs, *.vue" & LF
     & "json: *.json, *.sarif, composer.lock" & LF
     & "jsonl: *.jsonl" & LF
     & "julia: *.jl" & LF
     & "jupyter: *.ipynb, *.jpynb" & LF
     & "k: *.k" & LF
     & "kconfig: Kconfig, Kconfig.*" & LF
     & "kotlin: *.kt, *.kts" & LF
     & "lean: *.lean" & LF
     & "less: *.less" & LF
     & "license: *[.-]LICEN[CS]E*, AGPL-*[0-9]*, APACHE-*[0-9]*, BSD-*[0-9]*, CC-BY-*"
     & ", COPYING, COPYING[.-]*, COPYRIGHT, COPYRIGHT[.-]*, EULA, EULA[.-]*"
     & ", GFDL-*[0-9]*, GNU-*[0-9]*, GPL-*[0-9]*, LGPL-*[0-9]*, LICEN[CS]E"
     & ", LICEN[CS]E[.-]*, MIT-*[0-9]*, MPL-*[0-9]*, NOTICE, NOTICE[.-]*"
     & ", OFL-*[0-9]*, PATENTS, PATENTS[.-]*, UNLICEN[CS]E, UNLICEN[CS]E[.-]*"
     & ", agpl[.-]*, gpl[.-]*, lgpl[.-]*, licen[cs]e, licen[cs]e.*" & LF
     & "lilypond: *.ily, *.ly" & LF
     & "lisp: *.el, *.jl, *.lisp, *.lsp, *.sc, *.scm" & LF
     & "llvm: *.ll" & LF
     & "lock: *.lock, package-lock.json" & LF
     & "log: *.log" & LF
     & "lua: *.lua" & LF
     & "lz4: *.lz4" & LF
     & "lzma: *.lzma" & LF
     & "m4: *.ac, *.m4" & LF
     & "make: *.mak, *.mk, Makefile.*, [Gg][Nn][Uu]makefile"
     & ", [Gg][Nn][Uu]makefile.am, [Gg][Nn][Uu]makefile.in"
     & ", [Mm]akefile, [Mm]akefile.am, [Mm]akefile.in" & LF
     & "mako: *.mako, *.mao" & LF
     & "man: *.[0-9][cEFMmpSx], *.[0-9lnpx]" & LF
     & "markdown: *.markdown, *.md, *.mdown, *.mdwn, *.mdx, *.mkd, *.mkdn" & LF
     & "matlab: *.m" & LF
     & "md: *.markdown, *.md, *.mdown, *.mdwn, *.mdx, *.mkd, *.mkdn" & LF
     & "meson: meson.build, meson.options, meson_options.txt" & LF
     & "minified: *.min.css, *.min.html, *.min.js" & LF
     & "mint: *.mint" & LF
     & "mk: mkfile" & LF
     & "ml: *.ml" & LF
     & "mojo: *.mojo" & LF
     & "motoko: *.mo" & LF
     & "msbuild: *.csproj, *.fsproj, *.proj, *.props, *.sln, *.slnf, *.targets, *.vcxproj" & LF
     & "nim: *.nim, *.nimble, *.nimf, *.nims" & LF
     & "nix: *.nix" & LF
     & "objc: *.h, *.m" & LF
     & "objcpp: *.h, *.mm" & LF
     & "ocaml: *.ml, *.mli, *.mll, *.mly" & LF
     & "org: *.org, *.org_archive" & LF
     & "pants: BUILD" & LF
     & "pascal: *.dpr, *.inc, *.lpr, *.pas, *.pp" & LF
     & "pdf: *.pdf" & LF
     & "perl: *.PL, *.perl, *.pl, *.plh, *.plx, *.pm, *.t" & LF
     & "php: *.php, *.php3, *.php4, *.php5, *.php7, *.php8, *.pht, *.phtml" & LF
     & "pkgbuild: PKGBUILD" & LF
     & "po: *.po" & LF
     & "pod: *.pod" & LF
     & "postscript: *.eps, *.ps" & LF
     & "prolog: *.P, *.pl, *.pro, *.prolog" & LF
     & "proto: *.proto" & LF
     & "protobuf: *.proto" & LF
     & "ps: *.cdxml, *.ps1, *.ps1xml, *.psd1, *.psm1" & LF
     & "puppet: *.epp, *.erb, *.pp, *.rb" & LF
     & "purs: *.purs" & LF
     & "py: *.py, *.pyi" & LF
     & "python: *.py, *.pyi" & LF
     & "qmake: *.prf, *.pri, *.pro" & LF
     & "qml: *.qml" & LF
     & "qrc: *.qrc" & LF
     & "qui: *.ui" & LF
     & "r: *.R, *.Rmd, *.Rnw, *.r, *.rmd, *.rnw" & LF
     & "racket: *.rkt" & LF
     & "raku: *.p6, *.pl6, *.pm6, *.raku, *.rakudoc, *.rakumod, *.rakutest" & LF
     & "rdoc: *.rdoc" & LF
     & "readme: *README, README*" & LF
     & "reasonml: *.re, *.rei" & LF
     & "red: *.r, *.red, *.reds" & LF
     & "rescript: *.res, *.resi" & LF
     & "robot: *.robot" & LF
     & "rocq: *.v" & LF
     & "rst: *.rst" & LF
     & "ruby: *.gemspec, *.rake, *.rb, *.rbw, .irbrc, Gemfile, Rakefile, config.ru" & LF
     & "rust: *.rs" & LF
     & "sass: *.sass, *.scss" & LF
     & "scala: *.sbt, *.scala" & LF
     & "scdoc: *.scd, *.scdoc" & LF
     & "seed7: *.s7i, *.sd7" & LF
     & "sh: *.bash, *.bashrc, *.csh, *.cshrc, *.env, *.ksh, *.kshrc, *.sh, *.tcsh, *.zsh"
     & ", .bash_login, .bash_logout, .bash_profile, .bashrc, .cshrc, .env, .kshrc"
     & ", .login, .logout, .profile, .tcshrc, .zlogin, .zlogout, .zprofile, .zshenv, .zshrc"
     & ", bash_login, bash_logout, bash_profile, bashrc, profile, zlogin, zlogout"
     & ", zprofile, zshenv, zshrc" & LF
     & "slim: *.skim, *.slim, *.slime" & LF
     & "smarty: *.tpl" & LF
     & "sml: *.sig, *.sml" & LF
     & "solidity: *.sol" & LF
     & "soy: *.soy" & LF
     & "spark: *.spark" & LF
     & "spec: *.spec" & LF
     & "sql: *.psql, *.sql" & LF
     & "ssa: *.ssa" & LF
     & "stylus: *.styl" & LF
     & "sv: *.h, *.sv, *.svh, *.v, *.vg" & LF
     & "svelte: *.svelte, *.svelte.ts" & LF
     & "svg: *.svg" & LF
     & "swift: *.swift" & LF
     & "swig: *.def, *.i" & LF
     & "systemd: *.automount, *.conf, *.device, *.link, *.mount, *.path, *.scope"
     & ", *.service, *.slice, *.socket, *.swap, *.target, *.timer" & LF
     & "taskpaper: *.taskpaper" & LF
     & "tcl: *.tcl" & LF
     & "tex: *.bib, *.cls, *.dtx, *.ins, *.ltx, *.sty, *.tex" & LF
     & "texinfo: *.texi" & LF
     & "textile: *.textile" & LF
     & "tf: *.terraform.lock.hcl, *.terraformrc, *.tf, *.tf.json, *.tfrc, *.tfvars, *.tfvars.json, terraform.rc" & LF
     & "thrift: *.thrift" & LF
     & "toml: *.toml, Cargo.lock" & LF
     & "ts: *.cts, *.mts, *.ts, *.tsx" & LF
     & "twig: *.twig" & LF
     & "txt: *.txt" & LF
     & "typescript: *.cts, *.mts, *.ts, *.tsx" & LF
     & "typoscript: *.ts, *.typoscript" & LF
     & "typst: *.typ" & LF
     & "usd: *.usd, *.usda, *.usdc" & LF
     & "v: *.v, *.vsh" & LF
     & "vala: *.vala" & LF
     & "vb: *.vb" & LF
     & "vcl: *.vcl" & LF
     & "verilog: *.sv, *.svh, *.v, *.vh" & LF
     & "vhdl: *.vhd, *.vhdl" & LF
     & "vim: *.vim, .gvimrc, .vimrc, _gvimrc, _vimrc, gvimrc, vimrc" & LF
     & "vimscript: *.vim, .gvimrc, .vimrc, _gvimrc, _vimrc, gvimrc, vimrc" & LF
     & "vue: *.vue" & LF
     & "webidl: *.idl, *.webidl, *.widl" & LF
     & "wgsl: *.wgsl" & LF
     & "wiki: *.mediawiki, *.wiki" & LF
     & "xml: *.dtd, *.rng, *.sch, *.xhtml, *.xjb, *.xml, *.xml.dist, *.xsd, *.xsl, *.xslt" & LF
     & "xz: *.txz, *.xz" & LF
     & "yacc: *.y" & LF
     & "yaml: *.yaml, *.yml" & LF
     & "yang: *.yang" & LF
     & "z: *.Z" & LF
     & "zig: *.zig" & LF
     & "zsh: *.zsh, .zlogin, .zlogout, .zprofile, .zshenv, .zshrc, zlogin, zlogout, zprofile, zshenv, zshrc" & LF
     & "zstd: *.zst, *.zstd" & LF;

   function Leaf_Name (Path : String) return String;
   function Known (Name : String) return Boolean;
   function Matches_Type (Name, Leaf : String) return Boolean;

   function Leaf_Name (Path : String) return String is
   begin
      for Index in reverse Path'Range loop
         if Path (Index) = '/' or else Path (Index) = '\' then
            return Path (Index + 1 .. Path'Last);
         end if;
      end loop;
      return Path;
   end Leaf_Name;

   function Matches_Patterns
     (First : Positive;
      Last  : Natural;
      Leaf  : String) return Boolean
   is
      Start : Positive := First;
      Stop  : Natural;
   begin
      while Start <= Last loop
         Stop := Start;
         while Stop <= Last - 1
           and then not (Catalog (Stop) = ',' and then Catalog (Stop + 1) = ' ')
         loop
            Stop := Stop + 1;
         end loop;
         if Version.Ignore.Wildcard_Matches
           (Catalog (Start .. (if Stop < Last then Stop - 1 else Stop)), Leaf)
         then
            return True;
         end if;
         Start := Stop + 2;
      end loop;
      return False;
   end Matches_Patterns;

   function Matches_Type (Name, Leaf : String) return Boolean is
      Line_First : Positive := Catalog'First;
   begin
      while Line_First <= Catalog'Last loop
         declare
            Line_Last : Natural := Line_First;
            Colon     : Natural := Line_First;
         begin
            while Catalog (Line_Last) /= LF loop
               Line_Last := Line_Last + 1;
            end loop;
            while Catalog (Colon) /= ':' loop
               Colon := Colon + 1;
            end loop;
            if (Name = "all" or else Catalog (Line_First .. Colon - 1) = Name)
              and then Matches_Patterns (Colon + 2, Line_Last - 1, Leaf)
            then
               return True;
            end if;
            Line_First := Line_Last + 1;
         end;
      end loop;
      return False;
   end Matches_Type;

   function Known (Name : String) return Boolean is
      Line_First : Positive := Catalog'First;
   begin
      if Name = "all" then
         return True;
      end if;
      while Line_First <= Catalog'Last loop
         declare
            Line_Last : Natural := Line_First;
            Colon     : Natural := Line_First;
         begin
            while Catalog (Line_Last) /= LF loop
               Line_Last := Line_Last + 1;
            end loop;
            while Catalog (Colon) /= ':' loop
               Colon := Colon + 1;
            end loop;
            if Catalog (Line_First .. Colon - 1) = Name then
               return True;
            end if;
            Line_First := Line_Last + 1;
         end;
      end loop;
      return False;
   end Known;

   function Include_Type (Self : in out Policy; Name : String) return Boolean is
   begin
      if not Known (Name) then
         return False;
      end if;
      Self.Included.Append (Name);
      return True;
   end Include_Type;

   function Exclude_Type (Self : in out Policy; Name : String) return Boolean is
   begin
      if not Known (Name) then
         return False;
      end if;
      Self.Excluded.Append (Name);
      return True;
   end Exclude_Type;

   function Selects (Self : Policy; Path : String) return Boolean is
      Leaf     : constant String := Leaf_Name (Path);
      Included : Boolean := Self.Included.Is_Empty;
   begin
      for Name of Self.Included loop
         Included := Included or else Matches_Type (Name, Leaf);
      end loop;
      if not Included then
         return False;
      end if;
      for Name of Self.Excluded loop
         if Matches_Type (Name, Leaf) then
            return False;
         end if;
      end loop;
      return True;
   end Selects;

   procedure Put_List
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class) is
   begin
      Context.Put (Catalog);
   end Put_List;
end Posix_Tools.Commands.Rg.Types;
