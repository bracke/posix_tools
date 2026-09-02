package body Awk_CLI.Context_IO is
   package Context_State renames Awk_CLI_Context_State;

   function Read_Virtual_File
     (Context : Invocation_Context;
      Path    : String;
      Content : out U.Unbounded_String;
      Found   : out Boolean) return Awk_CLI.Platform.Read_Status is separate;

   function Read_File
     (Context : Invocation_Context;
      Path    : String;
      Content : out U.Unbounded_String) return Awk_CLI.Platform.Read_Status is separate;

   function Write_Standard_Output
     (Context : in out Invocation_Context;
      Content : String) return Boolean is separate;

   function Write_Standard_Error
     (Context : in out Invocation_Context;
      Content : String) return Boolean is separate;

   function Write_File
     (Context : in out Invocation_Context;
      Path    : String;
      Content : String;
      Append  : Boolean) return Awk_CLI.Redirections.Write_Status is separate;

   function Current_Environment
     (Context : Invocation_Context) return Awk_CLI.Environment.Entry_Vectors.Vector is separate;

end Awk_CLI.Context_IO;
