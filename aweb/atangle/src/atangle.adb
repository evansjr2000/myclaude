
with ADA.COMMAND_LINE;
use  ADA.COMMAND_LINE;
with TEXT_IO, INT_NUMBER_IO;
with DATA_STRUCTURES, INPUT_OUTPUT, INPUT_PHASE, OUTPUT_PHASE;
use  DATA_STRUCTURES, INPUT_OUTPUT, INPUT_PHASE, OUTPUT_PHASE;

procedure ATANGLE is
   AC : INTEGER := 0;
begin
   TEXT_IO.PUT("Trying to open input file.");
   TEXT_IO.NEW_LINE;
   AC := ARGUMENT_COUNT;

   if AC < 1 then
      TEXT_IO.NEW_LINE;
      TEXT_IO.PUT("No file on command line");
      ERROR;
      HISTORY := FATAL_MESSAGE;
      raise END_OF_ATANGLE;
   end if;

   OPEN_A_FILE(WEB_FILE, TEXT_IO.IN_FILE, ARGUMENT(1), OPENED);

   if not OPENED then
      TEXT_IO.NEW_LINE;
      TEXT_IO.PUT("AWEB file not open");
      ERROR;
      HISTORY := FATAL_MESSAGE;
      raise END_OF_ATANGLE;
   end if;

   OPENED := FALSE;

   if AC >= 2 then
      OPEN_A_FILE(CHANGE_FILE, TEXT_IO.IN_FILE, ARGUMENT(2), OPENED);
   end if;

   if not OPENED then
      TEXT_IO.NEW_LINE;
      TEXT_IO.PUT("! No change file.");
      TEXT_IO.NEW_LINE;
   end if;

   OPEN_A_FILE(
      ADA_FILE, TEXT_IO.OUT_FILE, "web_output.a", OPENED);

   if (not OPENED) and then (not CREATE_ADA_FILE("web_output.a")) then
      TEXT_IO.NEW_LINE;
      TEXT_IO.PUT("ADA file not open");
      ERROR;
      HISTORY := FATAL_MESSAGE;
      raise END_OF_ATANGLE;
   end if;

   FN_LENGTH := TEXT_IO.NAME(ADA_FILE)'LAST;
   FILE_NAME(1..FN_LENGTH) := TEXT_IO.NAME(ADA_FILE);
   F_LINE := 1;
   PHASE_I;
   --FOR ZO IN Z_RANGE LOOP MAX_TOK_PTR(ZO):=TOK_PTR(ZO);END LOOP;
   PHASE_II;
   raise END_OF_ATANGLE;

exception
   when END_OF_ATANGLE =>
      ----{168:}
      --TEXT_IO.NEW_LINE;TEXT_IO.PUT("Memory usage statistics:");
      --TEXT_IO.NEW_LINE;INT_NUMBER_IO.PUT(NAME_PTR,1);TEXT_IO.PUT(" names, ");
      --INT_NUMBER_IO.PUT(TEXT_PTR,1);TEXT_IO.PUT(" replacement texts;");
      --TEXT_IO.NEW_LINE;INT_NUMBER_IO.PUT(BYTE_PTR(0),1);
      --FOR WO IN 1..WW-1 LOOP TEXT_IO.PUT("+");
      --INT_NUMBER_IO.PUT(BYTE_PTR(WO),1);END LOOP;TEXT_IO.PUT(" bytes, ");
      --INT_NUMBER_IO.PUT(MAX_TOK_PTR(0),1);
      --FOR ZO IN 1..ZZ-1 LOOP TEXT_IO.PUT("+");
      --INT_NUMBER_IO.PUT(MAX_TOK_PTR(ZO),1);END LOOP;TEXT_IO.PUT(" tokens.")
      ----{:168}
      --;
      --{169:}
      case HISTORY is
         when SPOTLESS =>
            TEXT_IO.NEW_LINE;
            TEXT_IO.PUT("(No errors were found.)");
         when HARMLESS_MESSAGE =>
            TEXT_IO.NEW_LINE;
            TEXT_IO.PUT("(Did you see the warning message above?)");
         when ERROR_MESSAGE =>
            TEXT_IO.NEW_LINE;
            TEXT_IO.PUT("(Pardon me, but I think I spotted something wrong.)"
            );

         when FATAL_MESSAGE =>
            TEXT_IO.NEW_LINE;
            TEXT_IO.PUT("(That was a fatal error, my friend.)");

      end case;

      TEXT_IO.NEW_LINE;                --{:169}
      
end ATANGLE;

                                       --{:166}
