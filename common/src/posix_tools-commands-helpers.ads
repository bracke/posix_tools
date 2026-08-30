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

   function Parse_Natural_Operand
     (Context : in out Posix_Tools.Commands.Contexts.Context'Class;
      Result  : out Posix_Tools.Commands.Results.Result;
      Text    : String;
      Subject : String;
      Value   : out Natural) return Boolean;

   function Read_Affirmative_Response
     (Context           : in out Posix_Tools.Commands.Contexts.Context'Class;
      Wait_For_Line_End : Boolean := False) return Boolean;

   function Resolve_Group_Id (Text : String; Value : out Natural) return Boolean;

   function Resolve_User_Id (Text : String; Value : out Natural) return Boolean;

   function Group_Id_Text
     (Context     : Posix_Tools.Commands.Contexts.Context'Class;
      Id          : Natural;
      Prefer_Name : Boolean := True) return String;

   function User_Id_Text
     (Context     : Posix_Tools.Commands.Contexts.Context'Class;
      Id          : Natural;
      Prefer_Name : Boolean := True) return String;

   function Decorated_Group_Id_Text
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Id      : Natural) return String;

   function Decorated_User_Id_Text
     (Context : Posix_Tools.Commands.Contexts.Context'Class;
      Id      : Natural) return String;

   function Current_User_Name
     (Context : Posix_Tools.Commands.Contexts.Context'Class) return String;

   generic
      with procedure Action (Path : String);
   procedure For_Each_Directory_Child
     (Path   : String;
      Listed : out Boolean);

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
