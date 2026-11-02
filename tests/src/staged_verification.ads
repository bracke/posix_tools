--  The staged verification step: every built executable identifies
--  itself as the command it is installed as, at this version, and is
--  told apart from one at another version.
package Staged_Verification is
   procedure Run;
end Staged_Verification;
