separate (Awk_CLI.Platform)
package body Standard_Streams is
   function Write_Stream
     (Stream  : Interfaces.C_Streams.FILEs;
      Content : String) return Boolean
   is
      use type Interfaces.C_Streams.size_t;
      use type System.Address;

      Handle  : constant Interfaces.C_Streams.int :=
        Interfaces.C_Streams.fileno (Stream);
      Position  : Natural := Content'First;
      Remaining : Natural := Content'Length;
   begin
      if Stream = Interfaces.C_Streams.NULL_Stream or else Handle < 0 then
         return False;
      end if;

      Interfaces.C_Streams.set_binary_mode (Handle);

      while Remaining > 0 loop
         declare
            Written : constant Interfaces.C_Streams.size_t :=
              Interfaces.C_Streams.fwrite
                (Content (Position)'Address,
                 1,
                 Interfaces.C_Streams.size_t (Remaining),
                 Stream);
            Count : constant Natural := Natural (Written);
         begin
            if Count = 0 then
               return False;
            end if;

            Position := Position + Count;
            Remaining := Remaining - Count;
         end;
      end loop;

      return Interfaces.C_Streams.fflush (Stream) = 0;
   exception
      when Constraint_Error | Program_Error | Storage_Error =>
         return False;
   end Write_Stream;

   function Write_Output (Content : String) return Boolean is
   begin
      return Write_Stream (Interfaces.C_Streams.stdout, Content);
   end Write_Output;

   function Write_Error (Content : String) return Boolean is
   begin
      return Write_Stream (Interfaces.C_Streams.stderr, Content);
   end Write_Error;
end Standard_Streams;
