
with TEXT_IO;

package DATA_STRUCTURES is
                                       --{10:}

   BUF_SIZE       : constant := 132;
   MAX_BYTES      : constant := 65000;
   MAX_TOKS       : constant := 65000;
   MAX_NAMES      : constant := 10000;
   MAX_TEXTS      : constant := 10000;
   HASH_SIZE      : constant := 353;
   LONGEST_NAME   : constant := 400;
   LINE_LENGTH    : constant := 132;
   OUT_BUF_SIZE   : constant := 264;
   STACK_SIZE     : constant := 50;
   MAX_ID_LENGTH  : constant := LINE_LENGTH;
   UNAMBIG_LENGTH : constant := MAX_ID_LENGTH;
                                       --{:10}{11:}

   type HISTORY_TYPE is ( SPOTLESS,           HARMLESS_MESSAGE,
      ERROR_MESSAGE,      FATAL_MESSAGE );

   HISTORY : HISTORY_TYPE := SPOTLESS; --{:11}{12:}

   subtype ASCII_CODE is INTEGER range 0..127;
                                       --{:12}{13:}
   subtype TEXT_CHAR is CHARACTER;
   subtype TEXT_FILE is TEXT_IO.FILE_TYPE;
                                       --{:13}{14:}

   XORD                : array(TEXT_CHAR) of ASCII_CODE;
   XCHR                : array(ASCII_CODE) of TEXT_CHAR;
                                       --{:14}{16:}
   AND_SIGN            : constant ASCII_CODE := 8#4#;
   NOT_SIGN            : constant ASCII_CODE := 8#5#;
   SET_ELEMENT_SIGN    : constant ASCII_CODE := 8#6#;
   TAB_MARK            : constant ASCII_CODE := 8#11#;
   LINE_FEED           : constant ASCII_CODE := 8#12#;
   FORM_FEED           : constant ASCII_CODE := 8#14#;
   CARRIAGE_RETURN     : constant ASCII_CODE := 8#15#;
   RIGHT_ARROW         : constant ASCII_CODE := 8#21#;
   BOX_SIGN            : constant ASCII_CODE := 8#22#;
   DOUBLE_STAR         : constant ASCII_CODE := 8#23#;
   LEFT_LABEL_BRACKET  : constant ASCII_CODE := 8#24#;
   RIGHT_LABEL_BRACKET : constant ASCII_CODE := 8#25#;
   LEFT_ARROW          : constant ASCII_CODE := 8#30#;
   NOT_EQUAL           : constant ASCII_CODE := 8#32#;
   LESS_OR_EQUAL       : constant ASCII_CODE := 8#34#;
   GREATER_OR_EQUAL    : constant ASCII_CODE := 8#35#;
   EQUIVALENCE_SIGN    : constant ASCII_CODE := 8#36#;
   OR_SIGN             : constant ASCII_CODE := 8#37#;
                                       --{:16}{22:}
   WEB_FILE            : TEXT_FILE;
   CHANGE_FILE         : TEXT_FILE;    --{:22}{25:}
   ADA_FILE            : TEXT_FILE;    --{:25}{27:}

   type BUFFER_TYPE is array(INTEGER range <>) of ASCII_CODE;

   subtype BUFFER_INDEX is INTEGER range 0..BUF_SIZE;

   BUFFER         : BUFFER_TYPE(BUFFER_INDEX);
                                       --{:27}{30:}
   PHASE_ONE      : BOOLEAN;           --{:30}{35:}
   END_OF_ATANGLE : exception;         --{:35}{38:}

   subtype EIGHT_BITS is INTEGER range 0..255;
   subtype SIXTEEN_BITS is INTEGER range 0..65535;
                                       --{:38}{39:}

   WW : constant INTEGER := 2;
   ZZ : constant INTEGER := 3;

   subtype W_RANGE is INTEGER range 0..WW - 1;
   subtype Z_RANGE is INTEGER range 0..ZZ - 1;
   subtype BYTE_INDEX is INTEGER range 0..MAX_BYTES;
   subtype TOKEN_INDEX is INTEGER range 0..MAX_TOKS;
   subtype NAME_INDEX is INTEGER range 0..MAX_NAMES;
   subtype TEXT_INDEX is INTEGER range 0..MAX_TEXTS;

   type BYTE_MEMORY is array(W_RANGE, BYTE_INDEX) of ASCII_CODE;
                                       --PRAGMA PACK(BYTE_MEMORY);
   type TOKEN_MEMORY is array(Z_RANGE, TOKEN_INDEX) of EIGHT_BITS;
                                       --PRAGMA PACK(TOKEN_MEMORY);
   type NAME_INFO is array(NAME_INDEX) of SIXTEEN_BITS;
   type TOKEN_INFO is array(TEXT_INDEX) of SIXTEEN_BITS;

   BYTE_MEM   : BYTE_MEMORY;
   TOK_MEM    : TOKEN_MEMORY;
   BYTE_START : NAME_INFO;
   TOK_START  : TOKEN_INFO;
   LINK       : NAME_INFO;
   ILK        : NAME_INFO;
   EQUIV      : NAME_INFO;
   TEXT_LINK  : TOKEN_INFO;            --{:39}{40:}

   subtype NAME_POINTER is NAME_INDEX;

   NAME_PTR : NAME_POINTER := 1;
   BYTE_PTR : array(W_RANGE) of BYTE_INDEX := (others => 0);
                                       --{:40}{42:}

   subtype TEXT_POINTER is TEXT_INDEX;

   TEXT_PTR   : TEXT_POINTER := 1;
   TOK_PTR    : array(Z_RANGE) of TOKEN_INDEX := (others => 0);
   Z          : Z_RANGE := 1 mod ZZ;
   --MAX_TOK_PTR:ARRAY(Z_RANGE)OF TOKEN_INDEX;
   --{:42}{44:}
   NORMAL     : constant SIXTEEN_BITS := 0;
   SIMPLE     : constant SIXTEEN_BITS := 1;
   PARAMETRIC : constant SIXTEEN_BITS := 2;
                                       --{:44}{45:}
   LLINK      : NAME_INFO renames LINK;
   RLINK      : NAME_INFO renames ILK; --{:45}{49:}
   ID_FIRST   : BUFFER_INDEX;
   ID_LOC     : BUFFER_INDEX;

   subtype HASH_INDEX is INTEGER range 0..HASH_SIZE;
   subtype CHOP_HASH_INDEX is INTEGER range 0..UNAMBIG_LENGTH;

   HASH, CHOP_HASH : array(HASH_INDEX) of SIXTEEN_BITS := (others => 0);
   CHOPPED_ID      : array(CHOP_HASH_INDEX) of ASCII_CODE;
                                       --{:49}{62:}

   subtype LONG_NAME_INDEX is INTEGER range 0..LONGEST_NAME;

   MOD_TEXT : array(LONG_NAME_INDEX) of ASCII_CODE;
                                       --{:62}{63:}

   type COMPARE is (LESS, EQUAL, GREATER, PREFIX, EXTENSION );
                                       --{:63}{70:}

   MODULE_FLAG   : constant SIXTEEN_BITS := MAX_TEXTS;
   LAST_UNNAMED  : TEXT_POINTER := 0;  --{:70}{72:}
   PARAM         : constant EIGHT_BITS := 0;
   VERBATIM      : constant EIGHT_BITS := 2;
   FORCE_LINE    : constant EIGHT_BITS := 3;
   BEGIN_COMMENT : constant EIGHT_BITS := 8#11#;
   END_COMMENT   : constant EIGHT_BITS := 8#12#;
   CHARACTER_TOK : constant EIGHT_BITS := 8#14#;
   ASCII_TOK     : constant EIGHT_BITS := 8#15#;
   OUTPUT_TOK    : constant EIGHT_BITS := 8#16#;
   DOUBLE_DOT    : constant EIGHT_BITS := 8#40#;
   JOIN          : constant EIGHT_BITS := 8#177#;
                                       --{:72}{76:}

   subtype MOD_RANGE is INTEGER range 0..8#27777#;

   type OUTPUT_STATE is
      record
         END_FIELD  : SIXTEEN_BITS;
         BYTE_FIELD : SIXTEEN_BITS;
         NAME_FIELD : NAME_POINTER;
         REPL_FIELD : TEXT_POINTER;
         MOD_FIELD  : MOD_RANGE;
      end record;
   CUR_STATE     : OUTPUT_STATE;
   STACK         : array(1..STACK_SIZE) of OUTPUT_STATE;
   STACK_PTR     : INTEGER range 0..STACK_SIZE;
   CUR_END       : SIXTEEN_BITS renames CUR_STATE.END_FIELD;
   CUR_BYTE      : SIXTEEN_BITS renames CUR_STATE.BYTE_FIELD;
   CUR_NAME      : NAME_POINTER renames CUR_STATE.NAME_FIELD;
   CUR_REPL      : TEXT_POINTER renames CUR_STATE.REPL_FIELD;
   CUR_MOD       : MOD_RANGE renames CUR_STATE.MOD_FIELD;
                                       --{:76}{77:}
   ZO            : Z_RANGE;            --{:77}{79:}
   BRACE_LEVEL   : EIGHT_BITS;         --{:79}{83:}
   MODULE_NUMBER : constant SIXTEEN_BITS := 8#201#;
   IDENTIFIER    : constant SIXTEEN_BITS := 8#202#;
   CUR_VAL       : INTEGER;            --{:83}{91:}

   subtype OUT_BUFFER_INDEX is INTEGER range 0..OUT_BUF_SIZE;

   OUT_BUF               : BUFFER_TYPE(OUT_BUFFER_INDEX);
   OUT_PTR               : OUT_BUFFER_INDEX;
   BREAK_PTR             : OUT_BUFFER_INDEX;
   SEMI_PTR              : OUT_BUFFER_INDEX;
                                       --{:91}{92:}
   MISC                  : constant EIGHT_BITS := 0;
   NUM_OR_ID             : constant EIGHT_BITS := 1;
   UNBREAKABLE           : constant EIGHT_BITS := 2;
   OUT_STATE             : EIGHT_BITS;
   COMMENT_OUTPUT        : BOOLEAN;    --{:92}{97:}
   STR                   : constant EIGHT_BITS := 1;
   IDENT                 : constant EIGHT_BITS := 2;
   FRAC                  : constant EIGHT_BITS := 3;
   OUT_CONTRIB           : BUFFER_TYPE(1..LINE_LENGTH);
                                       --{:97}{107:}
   FILE_NAME             : STRING(1..256);
   FN_LENGTH             : INTEGER range 1..256;
   F_LINE                : INTEGER;    --{:107}{109:}
   SCANNING_BASED_NUMBER : BOOLEAN := FALSE;
                                       --{:109}{116:}
   LINE                  : INTEGER;
   OTHER_LINE            : INTEGER;
   TEMP_LINE             : INTEGER;
   LIMIT                 : BUFFER_INDEX;
   LOC                   : BUFFER_INDEX;
   INPUT_HAS_ENDED       : BOOLEAN;
   CHANGING              : BOOLEAN;    --{:116}{118:}
   CHANGE_BUFFER         : BUFFER_TYPE(BUFFER_INDEX);
   CHANGE_LIMIT          : BUFFER_INDEX;
                                       --{:118}{131:}
   IGNORE                : constant EIGHT_BITS := 0;
   CONTROL_TEXT          : constant EIGHT_BITS := 8#203#;
   FORMAT                : constant EIGHT_BITS := 8#204#;
   DEFINITION            : constant EIGHT_BITS := 8#205#;
   BEGIN_ADA             : constant EIGHT_BITS := 8#206#;
   MODULE_NAME           : constant EIGHT_BITS := 8#207#;
   NEW_MODULE            : constant EIGHT_BITS := 8#210#;
                                       --{:131}{136:}
   CUR_MODULE            : NAME_POINTER;
   SCANNING_CHARACTER    : BOOLEAN := FALSE;
                                       --{:136}{148:}
   CUR_REPL_TEXT         : TEXT_POINTER;
   NEXT_CONTROL          : SIXTEEN_BITS;
                                       --{:148}{156:}
   MODULE_COUNT          : MOD_RANGE;  --{:156}{165:}
   OPENED                : BOOLEAN := FALSE;

                                       --{:165}{47:}
   procedure PRINT_ID(P : NAME_POINTER);

                                       --{:47}{73:}
   procedure STORE_TWO_BYTES(X : SIXTEEN_BITS);
                                       --{:73}

end DATA_STRUCTURES;
