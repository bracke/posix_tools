with Posix_Tools.Commands.Contexts;
with Posix_Tools.Commands.Results;

package Posix_Tools.Commands.Helpers is
   function Escape_Untrusted (Text : String) return String;

   function Intercept_Extension
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Conventional : Boolean := True) return Boolean;

   procedure Usage_Error
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Message : String);

   procedure Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Message_Key : String;
      Default     : String);

   procedure Subject_Operational_Error
     (Context     : in out Posix_Tools.Commands.Contexts.Context'Class;
      Subject     : String;
      Message_Key : String;
      Default     : String);
end Posix_Tools.Commands.Helpers;
