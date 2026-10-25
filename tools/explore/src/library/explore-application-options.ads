with Ada.Strings.Unbounded;
with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

--  The command line: at most one directory, and the options that name the
--  configuration file and the files explore writes for a shell or a program
--  that runs it. Each option takes its value as "--name=value" or as the
--  next argument; "--" ends the options.
private package Explore.Application.Options is
   type Option_Set is record
      --  Empty when not given.
      Directory    : Ada.Strings.Unbounded.Unbounded_String;
      Config_Path  : Ada.Strings.Unbounded.Unbounded_String;
      Cwd_File     : Ada.Strings.Unbounded.Unbounded_String;
      Chooser_File : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Read Context's arguments into Into. Ok is False, with the usage error
   --  reported and in Result, when they make no sense.
   procedure Parse
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : in out Posix_Tools.Commands.Results.Result;
      Into    : out Option_Set;
      Ok      : out Boolean);
end Explore.Application.Options;
