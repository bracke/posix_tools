with Posix_Tools.Commands.Contexts;

--  Structured diagnostic logging for rg's compatibility-level debug output.
package Posix_Tools.Commands.Rg.Diagnostics is
   type Log_Level is (Logging_Off, Debug_Logging, Trace_Logging);

   function Localized
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Message : String) return String;

   procedure Error_Line
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Message : String);

   procedure Debug
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Configured : Log_Level;
      Component  : String;
      Message    : String);

   procedure Trace
     (Context    : in out Posix_Tools.Commands.Contexts.Context'Class;
      Configured : Log_Level;
      Component  : String;
      Message    : String);
end Posix_Tools.Commands.Rg.Diagnostics;
