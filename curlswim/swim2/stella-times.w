@* Swim Times.

This program fetches best short-course yard (SCY) times for four particular swimmers:

\medskip
$${\vbox{
{\bf Stella Julianna Evans} --- 10~\&~Under Girls

{\bf Kalea Rose Benavente} --- 13--14 Girls

{\bf Kenneth Ray Evans} --- 11--12 Boys

{\bf Keith Santiago Evans} --- 11--12 Boys
}}$$

\medskip\noindent
Twelve events are reported for each swimmer:
50, 100, 200, and 500~Freestyle; 50 and 100~Butterfly;
50 and 100~Backstroke; 50 and 100~Breaststroke; and 100 and 200~Individual
Medley.  Each time record includes the swim date and motivational standard
attained (B, BB, A, \dots).  Data is fetched live from the USA~Swimming
data hub, which is powered by the Sisense analytics platform.

@ {\bf How it works.}  The USA~Swimming data hub exposes a Sisense
JAQL~API.  We make two kinds of requests:

\medskip\item{1.} A {\it person search\/} to resolve the swimmer's internal
  |PersonKey|, given a search string and a substring to match the full name.

\item{2.} A {\it times query\/} for each event, filtered by |PersonKey|
  and event code (e.g.\ \.{100 FR SCY}).  Each row delivers five cells:
  swim time, sort key, meet name, swim date (as \.{YYYYMMDD}), and
  motivational standard.
\medskip

All HTTP communication is handled by \.{libcurl}.  JSON responses are
scanned with simple string operations rather than a full parse tree.

@ {\bf Compilation.}  After tangling with \.{ctangle}:
$$\.{gcc -O2 -o swim-times swim-times.c \$(curl-config --libs)}$$

@ {\bf Program structure.}  The top-level arrangement of the tangled
output is:

@c
@<Includes@> @/
@<Global constants@> @/
@<Option flags@> @/
@<Type definitions@> @/
@<HTTP utilities@> @/
@<JSON scanner@> @/
@<Person lookup@> @/
@<Times fetch@> @/
@<Main function@>

@* Includes and constants.

@ @<Includes@>=
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <curl/curl.h>

@ The Sisense bearer token authenticates us against the analytics
instance that backs \.{data.usaswimming.org}.  |EVENTS| lists the
twelve SCY event codes we query.

@<Global constants@>=
#define NUM_EVENTS 12
#define MAX_TIMES  200

static const char SISENSE_TOKEN[] =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
    ".eyJ1c2VyIjoiNjY0YmE2NmE5M2ZiYTUwMDM4NWIyMWQwIiwiYXBpU2VjcmV0Ijo"
    "iNDQ0YTE3NWQtM2I1OC03NDhhLTVlMGEtYTVhZDE2MmRmODJlIiwiYWxsb3dlZFRl"
    "bmFudHMiOlsiNjRhYzE5ZTEwZTkxNzgwMDFiYzM5YmVhIl0sInRlbmFudElkIjoiN"
    "jRhYzE5ZTEwZTkxNzgwMDFiYzM5YmVhIn0"
    ".izSIvaD2udKTs3QRngla1Aw23kZVyoq7Xh23AbPUw1M";

static const char SISENSE_API[] =
    "https://usaswimming.sisense.com/api/datasources";

static const char *EVENTS[NUM_EVENTS] = {
    "50 FR SCY",
    "100 FR SCY",
    "200 FR SCY",
    "500 FR SCY",
    "50 FL SCY",
    "100 FL SCY",
    "50 BK SCY",
    "100 BK SCY",
    "50 BR SCY",
    "100 BR SCY",
    "100 IM SCY",
    "200 IM SCY"
};

@ The program accepts two optional flags on the command line.

The \.{-o} flag takes a comma-separated list of one or more keywords.
Six keywords are recognised:
\medskip
\item{$\bullet$} \.{stella} --- output only Stella Julianna Evans' events.
\item{$\bullet$} \.{kalea} --- output only Kalea Rose Benavente's events.
\item{$\bullet$} \.{kenny} --- output only Kenneth Ray Evans' events.
\item{$\bullet$} \.{keith} --- output only Keith Santiago Evans' events.
\item{$\bullet$} \.{fastest} --- print only the single fastest time per event.
\item{$\bullet$} \.{csv} --- emit CSV lines (swimmer name on every line) instead of a table.
\medskip\noindent
Keywords may be combined, e.g.\ \.{-o stella,fastest} or \.{-o kalea,csv}.
When no swimmer keyword is specified all four swimmers are shown.

The \.{-e} flag takes one or more comma-separated SCY event codes
(e.g.\ \.{-e "100 FR SCY,50 FL SCY"}) and restricts output to those events
only.  The flag may also be repeated (e.g.\ \.{-e "100 FR SCY" -e "50 FL SCY"}).
When \.{-e} is omitted all twelve events are reported.

If no options are given at all the program prints a usage message and exits.

@<Option flags@>=
#define OPT_STELLA  (1<<0)  /* restrict output to Stella's events         */
#define OPT_KALEA   (1<<1)  /* restrict output to Kalea's events          */
#define OPT_FASTEST (1<<2)  /* print only the single fastest time         */
#define OPT_CSV     (1<<3)  /* emit CSV lines instead of a table          */
#define OPT_KENNY   (1<<4)  /* restrict output to Kenneth Ray Evans       */
#define OPT_KEITH   (1<<5)  /* restrict output to Keith Santiago Evans    */

static int  g_opts    = 0;  /* output-selection flags; 0 = show everything */
static char g_events[NUM_EVENTS][32]; /* event codes requested via \.{-e}  */
static int  g_nevents = 0;  /* number of entries in |g_events|             */

@* Data structures.

@ A |Buffer| holds a dynamically-grown heap string.  \.{libcurl}
appends each response chunk to it via the write callback.

@<Type definitions@>=
typedef struct {
    char  *data;
    size_t size;
} Buffer;

@ A |TimeRow| records one swim result.  |sort_key| is a numeric proxy
for the swim time (smaller is faster); |time| is the formatted string
(e.g.\ \.{1:02.45}); |date| is the swim date formatted as
\.{YYYY-MM-DD}; |standard| is the motivational standard attained
(e.g.\ \.{B}, \.{BB}, \.{A}, \.{Slower Than B}); and |meet| is the
meet name.  The Sisense API returns the sort key as a quoted decimal
string such as \.{"1010007029.00"}, so we store it as a |double|.

@<Type definitions@>+=
typedef struct {
    double sort_key;
    char   time[32];
    char   date[16];
    char   standard[48];
    char   meet[256];
} TimeRow;

@* HTTP utilities.

@ The \.{libcurl} write callback appends each incoming chunk to a
|Buffer|, growing the allocation as needed.  It maintains a null
terminator so the buffer can always be treated as a C string.

@<HTTP utilities@>=
static size_t write_cb(void *ptr, size_t size, size_t nmemb, void *ud)
{
    Buffer *b = (Buffer *)ud;
    size_t  n = size * nmemb;
    char   *p = realloc(b->data, b->size + n + 1);
    if (!p) return 0;
    b->data = p;
    memcpy(b->data + b->size, ptr, n);
    b->size += n;
    b->data[b->size] = '\0';
    return n;
}

@ |post_json| performs a single HTTP~POST with a JSON body and returns
the response as a null-terminated heap string, or |NULL| on failure.
The caller is responsible for freeing the returned string.

@<HTTP utilities@>+=
static char *post_json(const char *url, const char *body)
{
    CURL *curl = curl_easy_init();
    if (!curl) return NULL;

    Buffer buf = {NULL, 0};

    char auth_hdr[1600];
    snprintf(auth_hdr, sizeof auth_hdr,
             "Authorization: Bearer %s", SISENSE_TOKEN);

    struct curl_slist *hdrs = NULL;
    hdrs = curl_slist_append(hdrs, "Content-Type: application/json");
    hdrs = curl_slist_append(hdrs, auth_hdr);

    curl_easy_setopt(curl, CURLOPT_URL,           url);
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER,    hdrs);
    curl_easy_setopt(curl, CURLOPT_POSTFIELDS,    body);
    curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_cb);
    curl_easy_setopt(curl, CURLOPT_WRITEDATA,     &buf);

    CURLcode rc = curl_easy_perform(curl);
    curl_slist_free_all(hdrs);
    curl_easy_cleanup(curl);

    if (rc != CURLE_OK) { free(buf.data); return NULL; }
    return buf.data;
}

@* JSON scanner.

@ Sisense JAQL responses contain a top-level |"values"| array.  Each
element is itself an array of objects, each holding either a |"text"|
key (string value) or a |"data"| key (numeric value).  A typical
person-search row looks like:
$$\hbox{\.{[{"text":"Stella Julianna Evans"},{"data":12345},{"text":"CAST"}]}}$$

Rather than build a full parse tree we scan forward for a key and
extract the immediately following value, advancing a position pointer.

@ |scan_string| finds the first |"key"| at or after |*pos|, copies the
string value that follows into |out| (at most |max_len-1| bytes), and
advances |*pos| past it.  Returns 1 on success, 0 if the key is absent.

@<JSON scanner@>=
static int scan_string(const char *key, const char **pos,
                       char *out, size_t max_len)
{
    char needle[128];
    snprintf(needle, sizeof needle, "\"%s\"", key);
    const char *p = strstr(*pos, needle);
    if (!p) return 0;
    p += strlen(needle);
    while (*p == ' ' || *p == ':') p++;
    if (*p != '"') return 0;
    p++;
    const char *e = strchr(p, '"');
    if (!e) return 0;
    size_t len = (size_t)(e - p);
    if (len >= max_len) len = max_len - 1;
    memcpy(out, p, len);
    out[len] = '\0';
    *pos = e + 1;
    return 1;
}

@ |scan_long| is the numeric counterpart: it finds |"key"|, converts
the digits that follow to a |long|, stores the result in |*out|, and
advances |*pos|.

@<JSON scanner@>+=
static int scan_long(const char *key, const char **pos, long *out)
{
    char needle[128];
    snprintf(needle, sizeof needle, "\"%s\"", key);
    const char *p = strstr(*pos, needle);
    if (!p) return 0;
    p += strlen(needle);
    while (*p == ' ' || *p == ':') p++;
    char *end;
    *out = strtol(p, &end, 10);
    if (end == p) return 0;
    *pos = end;
    return 1;
}

@* Person lookup. |lookup_person_key| posts a search for |search_query| and scans
the result rows for one whose full name contains |match_substr| (after
lower-casing).  It returns a heap-allocated decimal |PersonKey| string
and, optionally, the swimmer's full name in |*out_name|.  Returns |NULL|
on failure.

@
@<Person lookup@>=
static char *lookup_person_key(const char *search_query,
                                const char *match_substr,
                                const char **out_name)
{
    char url[512];
    snprintf(url, sizeof url,
             "%s/aPublicIAAaPersonIAAaSearch/jaql", SISENSE_API);

    char body[1024];
    snprintf(body, sizeof body,
      "{"
        "\"datasource\":{"
          "\"title\":\"Public Person Search\","
          "\"fullname\":\"LocalHost/Public Person Search\"},"
        "\"metadata\":["
          "{\"jaql\":{\"table\":\"Persons\",\"column\":\"FullName\","
            "\"dim\":\"[Persons.FullName]\",\"datatype\":\"text\","
            "\"title\":\"Name\","
            "\"filter\":{\"contains\":\"%s\"}}},"
          "{\"jaql\":{\"table\":\"Persons\",\"column\":\"PersonKey\","
            "\"dim\":\"[Persons.PersonKey]\",\"datatype\":\"numeric\","
            "\"title\":\"PersonKey\"}},"
          "{\"jaql\":{\"table\":\"Persons\",\"column\":\"ClubName\","
            "\"dim\":\"[Persons.ClubName]\",\"datatype\":\"text\","
            "\"title\":\"Club\"}}"
        "],\"count\":100,\"offset\":0}",
      search_query);

    char *resp = post_json(url, body);
    if (!resp) {
        fputs("Error: person lookup request failed\n", stderr);
        return NULL;
    }

    char *key  = NULL;
    char *name = NULL;
    const char *p = strstr(resp, "\"values\"");

    while (p) {
        char full_name[256];
        if (!scan_string("text", &p, full_name, sizeof full_name)) break;

        /* Lower-case the name and check for the match substring. */
        char lower[256];
        size_t flen = strlen(full_name);
        for (size_t i = 0; i <= flen; i++)
            lower[i] = (char)(full_name[i] >= 'A' && full_name[i] <= 'Z'
                              ? full_name[i] + 32 : full_name[i]);

        if (strstr(lower, match_substr)) {
            long pk;
            if (scan_long("data", &p, &pk)) {
                char tmp[32];
                snprintf(tmp, sizeof tmp, "%ld", pk);
                key  = strdup(tmp);
                name = strdup(full_name);
            }
            break;
        }
    }

    free(resp);
    if (!key)
        fprintf(stderr, "Error: swimmer \"%s\" not found\n", search_query);
    if (out_name) *out_name = name;
    else           free(name);
    return key;
}

@* Times fetch.

@ |insertion_sort| sorts |n| |TimeRow| records in-place by |sort_key|
ascending (smallest = fastest time).  A swimmer's career rarely exceeds
a few dozen entries per event, so $O(n^2)$ is entirely adequate.

@<Times fetch@>=
static void insertion_sort(TimeRow *rows, int n)
{
    for (int i = 1; i < n; i++) {
        TimeRow tmp = rows[i];
        int j = i - 1;
        while (j >= 0 && rows[j].sort_key > tmp.sort_key) {
            rows[j + 1] = rows[j];
            j--;
        }
        rows[j + 1] = tmp;
    }
}

@ |format_date| converts an 8-digit \.{YYYYMMDD} string (such as
\.{20230305}) to \.{YYYY-MM-DD} format in |out| (which must be at
least 11 bytes).

@<Times fetch@>+=
static void format_date(const char *ymd8, char *out)
{
    if (strlen(ymd8) == 8) {
        out[0]=ymd8[0]; out[1]=ymd8[1]; out[2]=ymd8[2]; out[3]=ymd8[3];
        out[4]='-';
        out[5]=ymd8[4]; out[6]=ymd8[5];
        out[7]='-';
        out[8]=ymd8[6]; out[9]=ymd8[7];
        out[10]='\0';
    } else {
        strncpy(out, ymd8, 10);
        out[10] = '\0';
    }
}

@ |fetch_times| retrieves all SCY times for |person_key| in
|event_code|, sorts them fastest-first, and prints them.  Each JAQL
result row delivers five cells in order: time, sort key, meet name,
swim date (as \.{YYYYMMDD}), and motivational standard type.
The sort key (a decimal float string such as \.{"1010007029.00"}) is
converted to |double| with |strtod|.  The date is reformatted from
\.{YYYYMMDD} to \.{YYYY-MM-DD} by |format_date|.  |swimmer_name| is
the resolved full name of the swimmer (used in CSV output).
When |opts| has |OPT_CSV| set the output is a comma-separated line per
time record with the swimmer name on every line; when |OPT_FASTEST| is
set only the single fastest time is printed.

@<Times fetch@>+=
static void fetch_times(const char *person_key, const char *event_code,
                        const char *swimmer_name, int opts)
{
    char url[512];
    snprintf(url, sizeof url,
             "%s/aUSAIAAaSwimmingIAAaTimesIAAaElasticube/jaql", SISENSE_API);

    char body[2048];
    snprintf(body, sizeof body,
      "{"
        "\"datasource\":{"
          "\"title\":\"USA Swimming Times Elasticube\","
          "\"fullname\":\"LocalHost/USA Swimming Times Elasticube\"},"
        "\"metadata\":["
          "{\"jaql\":{\"table\":\"UsasSwimTime\",\"column\":\"PersonKey\","
            "\"dim\":\"[UsasSwimTime.PersonKey]\",\"datatype\":\"numeric\","
            "\"title\":\"PersonKey\","
            "\"filter\":{\"equals\":%s}},\"panel\":\"scope\"},"
          "{\"jaql\":{\"table\":\"SwimEvent\",\"column\":\"EventCode\","
            "\"dim\":\"[SwimEvent.EventCode]\",\"datatype\":\"text\","
            "\"title\":\"Event\","
            "\"filter\":{\"equals\":\"%s\"}},\"panel\":\"scope\"},"
          "{\"jaql\":{\"table\":\"UsasSwimTime\","
            "\"column\":\"SwimTimeFormatted\","
            "\"dim\":\"[UsasSwimTime.SwimTimeFormatted]\","
            "\"datatype\":\"text\",\"title\":\"Time\"}},"
          "{\"jaql\":{\"table\":\"UsasSwimTime\",\"column\":\"SortKey\","
            "\"dim\":\"[UsasSwimTime.SortKey]\",\"datatype\":\"numeric\","
            "\"title\":\"SortKey\"}},"
          "{\"jaql\":{\"table\":\"Meet\",\"column\":\"MeetName\","
            "\"dim\":\"[Meet.MeetName]\",\"datatype\":\"text\","
            "\"title\":\"Meet\"}},"
          "{\"jaql\":{\"table\":\"UsasSwimTime\","
            "\"column\":\"SeasonCalendarKey\","
            "\"dim\":\"[UsasSwimTime.SeasonCalendarKey]\","
            "\"datatype\":\"numeric\",\"title\":\"Date\"}},"
          "{\"jaql\":{\"table\":\"TimeStandard\","
            "\"column\":\"StandardType\","
            "\"dim\":\"[TimeStandard.StandardType]\","
            "\"datatype\":\"text\",\"title\":\"Standard\"}}"
        "],\"count\":100,\"offset\":0}",
      person_key, event_code);

    char *resp = post_json(url, body);
    if (!resp) {
        fprintf(stderr, "Error: times request failed for %s\n", event_code);
        return;
    }

    TimeRow rows[MAX_TIMES];
    int     nrows = 0;
    const char *p = strstr(resp, "\"values\"");

    /* Each row has five cells scanned in order via "text":
       0 = swim time string, 1 = sort key as decimal float string,
       2 = meet name, 3 = date as YYYYMMDD, 4 = motivational standard. */
    while (p && nrows < MAX_TIMES) {
        char time_str[32];
        if (!scan_string("text", &p, time_str, sizeof time_str)) break;
        if (time_str[0] == '\0') break;

        char sort_str[64];
        if (!scan_string("text", &p, sort_str, sizeof sort_str)) break;

        char meet_str[256];
        if (!scan_string("text", &p, meet_str, sizeof meet_str)) break;

        char date_str[16];
        if (!scan_string("text", &p, date_str, sizeof date_str)) break;

        char std_str[48];
        if (!scan_string("text", &p, std_str, sizeof std_str)) break;

        rows[nrows].sort_key = strtod(sort_str, NULL);
        strncpy(rows[nrows].time, time_str, sizeof rows[nrows].time - 1);
        rows[nrows].time[sizeof rows[nrows].time - 1] = '\0';
        format_date(date_str, rows[nrows].date);
        strncpy(rows[nrows].standard, std_str,
                sizeof rows[nrows].standard - 1);
        rows[nrows].standard[sizeof rows[nrows].standard - 1] = '\0';
        strncpy(rows[nrows].meet, meet_str, sizeof rows[nrows].meet - 1);
        rows[nrows].meet[sizeof rows[nrows].meet - 1] = '\0';
        nrows++;
    }

    free(resp);
    insertion_sort(rows, nrows);

    int lim = (opts & OPT_FASTEST) ? (nrows > 0 ? 1 : 0) : nrows;

    if (opts & OPT_CSV) {
        /* CSV: swimmer,event,time,date,standard,meet  (no header here;
           caller emits the header once before the first swimmer loop). */
        for (int i = 0; i < lim; i++)
            printf("\"%s\",\"%s\",\"%s\",%s,\"%s\",\"%s\"\n",
                   swimmer_name ? swimmer_name : "",
                   event_code,
                   rows[i].time, rows[i].date,
                   rows[i].standard, rows[i].meet);
    } else {
        printf("%s --- %s:\n", event_code,
               (opts & OPT_FASTEST) ? "fastest time"
                                    : "all times (fastest first)");
        printf("%-12s  %-10s  %-13s  %s\n", "Time", "Date", "Standard", "Meet");
        printf("%-12s  %-10s  %-13s  %s\n",
               "------------", "----------", "-------------", "----");
        for (int i = 0; i < lim; i++)
            printf("%-12s  %-10s  %-13s  %s\n",
                   rows[i].time, rows[i].date,
                   rows[i].standard, rows[i].meet);
        if (nrows == 0)
            printf("(no times found)\n");
        putchar('\n');
    }
}

@* Main program.

@ We define a small |Swimmer| record to hold the person-search
parameters for each swimmer.  Each entry supplies a |search_query| string
sent to the database (ideally distinctive enough to return a small set),
a |match_substr| (lower-cased) used to identify the correct row, and
a |flag| bit used to filter output when the user passes a swimmer keyword
to \.{-o}.
Kalea's entry searches ``Benavente'' because the simple two-word query
``Kalea Benavente'' returns no results; the API requires an exact substring
match against the registered name ``Kalea Rose Benavente''.
Kenneth's entry uses ``kenneth ray'' and Keith's uses ``keith santiago''
to avoid false matches on the common surname ``Evans''.

@<Main function@>=
typedef struct {
    const char *search_query;  /* Name string to search for  */
    const char *match_substr;  /* Lower-case substring to match */
    int         flag;          /* |OPT_STELLA|, |OPT_KALEA|, etc. */
} Swimmer;

static const Swimmer SWIMMERS[] = {
    { "Julianna Evans",  "stella",         OPT_STELLA }, /* Stella Julianna Evans  */
    { "Benavente",       "kalea",          OPT_KALEA  }, /* Kalea Rose Benavente   */
    { "Ray Evans",       "kenneth ray",    OPT_KENNY  }, /* Kenneth Ray Evans      */
    { "Santiago Evans",  "keith santiago", OPT_KEITH  }  /* Keith Santiago Evans   */
};
#define NUM_SWIMMERS ((int)(sizeof SWIMMERS / sizeof SWIMMERS[0]))

@ |parse_opts_str| tokenises a comma-separated option string (the
argument to \.{-o}) and sets bits in |g_opts|.  Unknown tokens are
silently ignored so that future options can be added without breaking
existing invocations.

@<Main function@>+=
static void parse_opts_str(const char *s)
{
    /* Work on a writable copy so strtok can insert NUL bytes. */
    char *buf = strdup(s);
    if (!buf) return;
    char *tok = strtok(buf, ",");
    while (tok) {
        if      (strcmp(tok, "stella")  == 0) g_opts |= OPT_STELLA;
        else if (strcmp(tok, "kalea")   == 0) g_opts |= OPT_KALEA;
        else if (strcmp(tok, "kenny")   == 0) g_opts |= OPT_KENNY;
        else if (strcmp(tok, "keith")   == 0) g_opts |= OPT_KEITH;
        else if (strcmp(tok, "fastest") == 0) g_opts |= OPT_FASTEST;
        else if (strcmp(tok, "csv")     == 0) g_opts |= OPT_CSV;
        tok = strtok(NULL, ",");
    }
    free(buf);
}

@ |parse_events_str| tokenises a comma-separated event-code string (the
argument to \.{-e}) and appends each code to |g_events|.  Codes that would
overflow the |NUM_EVENTS|-entry array are silently dropped.  The flag may
be supplied multiple times; each invocation extends the list.

@<Main function@>+=
static void parse_events_str(const char *s)
{
    char *buf = strdup(s);
    if (!buf) return;
    char *tok = strtok(buf, ",");
    while (tok && g_nevents < NUM_EVENTS) {
        /* Trim leading spaces left by comma-split with spaces around commas. */
        while (*tok == ' ') tok++;
        strncpy(g_events[g_nevents], tok, sizeof g_events[0] - 1);
        g_events[g_nevents][sizeof g_events[0] - 1] = '\0';
        g_nevents++;
        tok = strtok(NULL, ",");
    }
    free(buf);
}

@ |print_usage| writes the full usage message to standard error.

@<Main function@>+=
static void print_usage(const char *prog)
{
    fprintf(stderr,
        "Usage: %s -o option[,option...] [-e event[,event...]]\n"
        "\n"
        "  -o option,...   comma-separated output options:\n"
        "       stella      restrict output to Stella Julianna Evans\n"
        "       kalea       restrict output to Kalea Rose Benavente\n"
        "       kenny       restrict output to Kenneth Ray Evans\n"
        "       keith       restrict output to Keith Santiago Evans\n"
        "       fastest     print only the single fastest time per event\n"
        "       csv         emit CSV output (header + one line per time)\n"
        "\n"
        "  -e event,...    restrict output to one or more SCY event codes;\n"
        "                  comma-separated, or repeat -e for each event.\n"
        "       Valid codes: 50 FR SCY, 100 FR SCY, 200 FR SCY, 500 FR SCY,\n"
        "                    50 FL SCY, 100 FL SCY, 50 BK SCY, 100 BK SCY,\n"
        "                    50 BR SCY, 100 BR SCY, 100 IM SCY, 200 IM SCY\n"
        "\n"
        "Examples:\n"
        "  %s -o stella,fastest\n"
        "  %s -o kalea,csv\n"
        "  %s -o kenny -e \"100 FR SCY\"\n"
        "  %s -o keith -e \"100 FR SCY,50 FL SCY\"\n"
        "  %s -o stella -e \"100 FR SCY\" -e \"50 FL SCY\"\n",
        prog, prog, prog, prog, prog, prog);
}

@ We initialise the global \.{libcurl} state, parse the optional
\.{-o} and \.{-e} flags, then for each swimmer (subject to swimmer-selection
bits) resolve her |PersonKey| and iterate over events.  If one or more
\.{-e} codes were given only those events are fetched; otherwise all twelve
are processed.  In CSV mode a single header line is printed before the first
data row.  If no options at all are supplied, the usage message is printed
and the program exits with status~1.

@<Main function@>+=
int main(int argc, char *argv[])
{
    int ch;
    while ((ch = getopt(argc, argv, "o:e:")) != -1) {
        switch (ch) {
        case 'o':
            parse_opts_str(optarg);
            break;
        case 'e':
            parse_events_str(optarg);
            break;
        default:
            print_usage(argv[0]);
            return 2;
        }
    }

    /* Require at least one option; print usage and exit otherwise. */
    if (g_opts == 0 && g_nevents == 0) {
        print_usage(argv[0]);
        return 1;
    }

    curl_global_init(CURL_GLOBAL_DEFAULT);

    /* Print CSV header once, before any swimmer loop. */
    if (g_opts & OPT_CSV)
        printf("\"Swimmer\",\"Event\",\"Time\",\"Date\",\"Standard\",\"Meet\"\n");

    int swimmer_mask = OPT_STELLA | OPT_KALEA | OPT_KENNY | OPT_KEITH;

    for (int s = 0; s < NUM_SWIMMERS; s++) {
        /* Skip this swimmer if the -o flag restricts to the other one. */
        if ((g_opts & swimmer_mask) && !(g_opts & SWIMMERS[s].flag))
            continue;

        const char *name = NULL;
        char *key = lookup_person_key(SWIMMERS[s].search_query,
                                      SWIMMERS[s].match_substr,
                                      &name);
        if (!key) {
            curl_global_cleanup();
            return 1;
        }

        if (!(g_opts & OPT_CSV))
            printf("Swimmer: %s  (PersonKey: %s)\n\n",
                   name ? name : "(unknown)", key);

        if (g_nevents > 0) {
            /* Fetch only the events requested via -e. */
            for (int i = 0; i < g_nevents; i++)
                fetch_times(key, g_events[i], name, g_opts);
        } else {
            for (int i = 0; i < NUM_EVENTS; i++)
                fetch_times(key, EVENTS[i], name, g_opts);
        }

        free(key);
        free((void *)name);
        if (!(g_opts & OPT_CSV))
            putchar('\n');
    }

    curl_global_cleanup();
    return 0;
}

@* Glossary.

The following terms and interfaces appear throughout this program.

@
\def\gitem#1{\medskip\noindent{\bf #1.}\enspace\ignorespaces}
\def\sig#1{\par\noindent\quad{\tt #1}\par\noindent}

\gitem{JAQL (JSON Analytics Query Language)}
The query language used by the Sisense Analytic Engine to describe data
requests.  A JAQL query is a JSON object posted to the endpoint
\.{/api/datasources/\{name\}/jaql}.  Its \.{metadata} array specifies
the columns (dimensions or measures) to retrieve; \.{filter} objects
restrict row membership; and \.{count}/\.{offset} control pagination.
The Sisense back-end translates JAQL to an internal columnar query,
executes it against the ElastiCube, and returns results in a
\.{values} array whose rows are parallel to the \.{metadata} array.

\gitem{Sisense Analytic Engine (ElastiCube)}
A columnar, in-memory analytics database developed by Sisense.
USA Swimming hosts a Sisense instance at
\.{usaswimming.sisense.com} that powers the public data hub at
\.{data.usaswimming.org}.  The engine stores swim-time, meet, person,
and time-standard data in compressed column stores called
{\it ElastiCubes}; this program queries two of them---``Public Person
Search'' and ``USA Swimming Times Elasticube''---via their JAQL
endpoints, authenticating with a bearer token in the
\.{Authorization} HTTP header.

@ {\bf Sisense JAQL API Calls.}
All requests are HTTP POST to \.{https://usaswimming.sisense.com/api/datasources/\{ds\}/jaql}
with headers \.{Content-Type: application/json} and
\.{Authorization: Bearer \{token\}}.
The JSON request body has the following top-level fields:

\medskip
\item{$\bullet$} \.{datasource} (object).
  Identifies the ElastiCube to query.
  \par\noindent Fields:
  \itemitem{--} \.{title} (string): human-readable name,
    e.g.\ \.{"Public Person Search"}.
  \itemitem{--} \.{fullname} (string): internal path used by the server,
    e.g.\ \.{"LocalHost/Public Person Search"}.

\item{$\bullet$} \.{metadata} (array of objects).
  Each element describes one column of the result.
  \par\noindent Per-element fields:
  \itemitem{--} \.{jaql.table} (string): the ElastiCube table name
    (e.g.\ \.{"Persons"}, \.{"UsasSwimTime"}, \.{"Meet"},
    \.{"SwimEvent"}, \.{"TimeStandard"}).
  \itemitem{--} \.{jaql.column} (string): the column name within the table
    (e.g.\ \.{"FullName"}, \.{"PersonKey"}, \.{"SwimTimeFormatted"},
    \.{"SortKey"}, \.{"MeetName"}, \.{"SeasonCalendarKey"},
    \.{"EventCode"}, \.{"StandardType"}).
  \itemitem{--} \.{jaql.dim} (string): the bracketed dimension path
    \.{"[Table.Column]"} used by the query engine.
  \itemitem{--} \.{jaql.datatype} (string): \.{"text"} or \.{"numeric"}.
  \itemitem{--} \.{jaql.title} (string): label for the column in the response.
  \itemitem{--} \.{jaql.filter} (object, optional): restricts rows.
    This program uses two filter types:
    \.{\{"contains": "..."\}} for substring matches on text columns
    (person search) and \.{\{"equals": value\}} for exact matches
    ({\tt PersonKey} and {\tt EventCode} scope filters).
  \itemitem{--} \.{panel} (string, optional): when set to \.{"scope"}
    the column acts as a {\it scope filter}---it narrows the result set
    without appearing as an output column.

\item{$\bullet$} \.{count} (integer).
  Maximum number of rows to return.
  This program uses 10 for quick existence checks and 100 for full
  result sets.

\item{$\bullet$} \.{offset} (integer).
  Zero-based row offset for pagination.

\medskip\noindent
The response body is a JSON object.  Relevant fields:

\medskip
\item{$\bullet$} \.{values} (array of arrays).
  Each inner array is one result row; its elements correspond
  positionally to the non-scope entries in \.{metadata}.
  Each element is an object with two keys: \.{data} (the raw value,
  number or string) and \.{text} (the formatted string representation).
  This program always reads the \.{text} field.

\item{$\bullet$} \.{error} (boolean, present on failure).
  When true, \.{details} contains an error message.

\medskip\noindent
{\bf Person search call.}
Endpoint: \.{.../aPublicIAAaPersonIAAaSearch/jaql}.
Queries the \.{Persons} table with a \.{contains} filter on
\.{FullName}.  Returns \.{FullName} (text) and \.{PersonKey} (numeric)
columns.  This program sends \.{count:100} and scans rows until it
finds one whose lower-cased name contains the match substring.

\medskip\noindent
{\bf Times query call.}
Endpoint: \.{.../aUSAIAAaSwimmingIAAaTimesIAAaElasticube/jaql}.
Uses two scope filters (\.{PersonKey} equals and \.{EventCode} equals)
and retrieves five output columns in order:
\.{SwimTimeFormatted} (formatted time string),
\.{SortKey} (numeric sort key as decimal string, smaller = faster),
\.{MeetName} (meet name),
\.{SeasonCalendarKey} (swim date as \.{YYYYMMDD} integer), and
\.{StandardType} from the \.{TimeStandard} table
(motivational level: \.{"B"}, \.{"BB"}, \.{"A"}, \.{"Slower Than B"}, etc.).

@ {\bf libcurl API Calls.}
This program uses the libcurl ``easy'' interface for synchronous HTTP.
All functions return a |CURLcode| (zero = \.{CURLE\_OK}) except where
noted.

\medskip
\item{$\bullet$} {\tt curl\_global\_init(flags)}.
  \par\noindent Parameter: {\tt flags} ({\tt long}) ---
  a bitmask of subsystems to initialise.
  This program passes \.{CURL\_GLOBAL\_DEFAULT}, which enables SSL
  and the Windows socket layer on that platform.
  Must be called once before any other libcurl function.
  Returns a {\tt CURLcode}; this program ignores the return value
  because failure is treated as fatal by the subsequent easy calls.

\item{$\bullet$} {\tt curl\_global\_cleanup(void)}.
  Releases all resources allocated by |curl_global_init|.
  Must be called once after all easy handles have been cleaned up.
  Returns nothing.

\item{$\bullet$} {\tt curl\_easy\_init(void)}.
  Allocates and returns a new easy handle (a \.{CURL *}).
  Returns \.{NULL} on failure.
  Each call to |post_json| creates its own handle and destroys it
  before returning, so handles are never shared between requests.

\item{$\bullet$} {\tt curl\_easy\_setopt(handle, option, value)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt handle} ({\tt CURL *}): the easy handle.
  \itemitem{--} {\tt option} ({\tt CURLoption}): a constant selecting
    the behaviour to configure.  Options used here:
    \itemitem{} \.{CURLOPT\_URL} ({\tt char *}) --- the request URL.
    \itemitem{} \.{CURLOPT\_HTTPHEADER} ({\tt struct curl\_slist *}) ---
      linked list of extra HTTP headers
      (\.{Content-Type} and \.{Authorization}).
    \itemitem{} \.{CURLOPT\_POSTFIELDS} ({\tt char *}) ---
      the POST body; setting this also switches the method to POST.
    \itemitem{} \.{CURLOPT\_WRITEFUNCTION} (function pointer) ---
      callback invoked for each response chunk; signature
      {\tt size\_t cb(void*,size\_t,size\_t,void*)}.
    \itemitem{} \.{CURLOPT\_WRITEDATA} ({\tt void *}) ---
      the user-data pointer passed as the fourth argument to the
      write callback; here a pointer to the |Buffer| accumulator.
  \itemitem{--} {\tt value}: type depends on {\tt option} (see above).

\item{$\bullet$} {\tt curl\_easy\_perform(handle)}.
  \par\noindent Parameter: {\tt handle} ({\tt CURL *}).
  Executes the configured request synchronously, invoking the write
  callback for each received chunk.
  Returns \.{CURLE\_OK} on success or a non-zero error code; on failure
  |post_json| frees the partial buffer and returns \.{NULL}.

\item{$\bullet$} {\tt curl\_easy\_cleanup(handle)}.
  \par\noindent Parameter: {\tt handle} ({\tt CURL *}).
  Releases all resources associated with the handle.
  The handle must not be used after this call.

\item{$\bullet$} {\tt curl\_slist\_append(list, string)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt list} ({\tt struct curl\_slist *}):
    existing list head, or \.{NULL} to start a new list.
  \itemitem{--} {\tt string} ({\tt const char *}): the string to append.
  Returns the new list head, or \.{NULL} on allocation failure.
  Used to build the two-header list
  (\.{Content-Type} then \.{Authorization}).

\item{$\bullet$} {\tt curl\_slist\_free\_all(list)}.
  \par\noindent Parameter: {\tt list} ({\tt struct curl\_slist *}).
  Frees every node in the linked list.
  Called immediately after |curl_easy_perform| so the headers are
  released before the handle.

@ {\bf POSIX System Calls and Library Functions.}
The following identifiers from the POSIX.1-2008 standard are used
directly in this program.  Each entry gives the C~signature, a
description of each parameter, and a note on how the program uses it.

\medskip
\item{$\bullet$} {\tt int fprintf(FILE *stream, const char *fmt, ...)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt stream}: destination file (\.{stderr} here).
  \itemitem{--} {\tt fmt}: printf-style format string.
  \itemitem{--} {\tt ...}: values substituted into {\tt fmt}.
  Writes formatted output to {\tt stream}; returns the character count
  or a negative value on error.
  Used to report lookup and HTTP failures to standard error.

\item{$\bullet$} {\tt int fputs(const char *s, FILE *stream)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt s}: null-terminated string to write.
  \itemitem{--} {\tt stream}: destination file (\.{stderr} here).
  Writes {\tt s} without a trailing newline; returns non-negative on
  success or \.{EOF} on error.
  Used for fixed error messages where no formatting is needed.

\item{$\bullet$} {\tt void free(void *ptr)}.
  \par\noindent Parameter:
  \itemitem{--} {\tt ptr}: pointer to a heap block, or \.{NULL}
    (in which case nothing happens).
  Releases the block back to the heap.
  Called on every heap string (response buffers, duplicated names and
  keys) when they are no longer needed.

\item{$\bullet$} {\tt void *memcpy(void *dst, const void *src, size\_t n)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt dst}: destination address.
  \itemitem{--} {\tt src}: source address.
  \itemitem{--} {\tt n}: number of bytes to copy.
  Copies exactly {\tt n} bytes from {\tt src} to {\tt dst};
  regions must not overlap.
  Returns {\tt dst}.
  Used in |write_cb| to append each network chunk to the buffer,
  and in |scan_string| to copy a JSON string value.

\item{$\bullet$} {\tt int printf(const char *fmt, ...)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt fmt}: printf-style format string.
  \itemitem{--} {\tt ...}: values substituted into {\tt fmt}.
  Writes formatted output to standard output; returns the character
  count or a negative value on error.
  Used for all swimmer and time-table output.

\item{$\bullet$} {\tt int putchar(int c)}.
  \par\noindent Parameter:
  \itemitem{--} {\tt c}: character value (as {\tt unsigned char} cast
    to {\tt int}).
  Writes one character to standard output; returns the character
  written, or \.{EOF} on error.
  Used to emit a blank line (\.{'\char`\\n'}) after each event section.

\item{$\bullet$} {\tt void *realloc(void *ptr, size\_t size)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt ptr}: existing heap block, or \.{NULL}.
  \itemitem{--} {\tt size}: new size in bytes.
  Returns a pointer to the resized block (possibly moved), or \.{NULL}
  if allocation fails (the original block is unchanged on failure).
  When {\tt ptr} is \.{NULL} the call is equivalent to {\tt malloc}.
  Used in |write_cb| to grow the response buffer incrementally as
  libcurl delivers each chunk.

\item{$\bullet$} {\tt int snprintf(char *buf, size\_t n, const char *fmt, ...)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt buf}: destination character array.
  \itemitem{--} {\tt n}: maximum bytes to write, including the null terminator.
  \itemitem{--} {\tt fmt}: printf-style format string.
  \itemitem{--} {\tt ...}: values substituted into {\tt fmt}.
  Writes at most {\tt n}$-1$ formatted characters to {\tt buf} and
  always null-terminates.  Returns the number of characters that would
  have been written had the buffer been unlimited (so a return value
  $\ge${\tt n} signals truncation).
  Used to assemble URL strings, JSON bodies, and the bearer-token header.

\item{$\bullet$} {\tt char *strchr(const char *s, int c)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt s}: string to search.
  \itemitem{--} {\tt c}: character to find (compared as {\tt unsigned char}).
  Returns a pointer to the first occurrence of {\tt c} in {\tt s},
  including the terminator if {\tt c} is \.{'\char`\\0'}, or \.{NULL}.
  Used in |scan_string| to find the closing double-quote of a JSON
  string value.

\item{$\bullet$} {\tt char *strdup(const char *s)}.
  \par\noindent Parameter:
  \itemitem{--} {\tt s}: null-terminated string to duplicate.
  Allocates a new heap block of {\tt strlen(s)+1} bytes, copies
  {\tt s} into it, and returns the pointer; returns \.{NULL} on failure.
  Used in |lookup_person_key| to persist the swimmer's full name and
  PersonKey string across the lifetime of a query.

\item{$\bullet$} {\tt size\_t strlen(const char *s)}.
  \par\noindent Parameter:
  \itemitem{--} {\tt s}: null-terminated string.
  Returns the number of bytes before the null terminator.
  Used to compute loop bounds when lower-casing names, to advance
  past a search needle in |scan_string| and |scan_long|, and to
  validate the 8-character date string in |format_date|.

\item{$\bullet$} {\tt char *strncpy(char *dst, const char *src, size\_t n)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt dst}: destination array (at least {\tt n} bytes).
  \itemitem{--} {\tt src}: source string.
  \itemitem{--} {\tt n}: maximum bytes to copy.
  Copies up to {\tt n} bytes; if {\tt src} is shorter than {\tt n},
  the remainder of {\tt dst} is zero-filled.  If {\tt src} is at least
  {\tt n} bytes long, {\tt dst} will {\it not\/} be null-terminated.
  Returns {\tt dst}.
  This program always writes {\tt dst[sizeof dst - 1] = '\char`\\0'}
  after the call to guarantee termination.
  Used to copy time, standard, and meet strings into {\tt TimeRow}.

\item{$\bullet$} {\tt char *strstr(const char *hay, const char *needle)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt hay}: string to search within.
  \itemitem{--} {\tt needle}: substring to search for.
  Returns a pointer to the first occurrence of {\tt needle} in
  {\tt hay}, or \.{NULL} if not found.
  The workhorse of the JSON scanner: used to locate key names
  (\.{"text"}, \.{"data"}, \.{"values"}) and to advance through
  the raw Sisense response text.

\item{$\bullet$} {\tt double strtod(const char *s, char **endptr)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt s}: string containing a floating-point number.
  \itemitem{--} {\tt endptr}: if non-\.{NULL}, receives a pointer to the
    first character not consumed by the conversion.
  Returns the parsed {\tt double}; sets {\tt *endptr} past the
  converted text.
  Used to convert the Sisense sort-key string
  (e.g.\ \.{"1010007029.00"}) to a {\tt double} for the insertion sort.

\item{$\bullet$} {\tt long strtol(const char *s, char **endptr, int base)}.
  \par\noindent Parameters:
  \itemitem{--} {\tt s}: string containing an integer.
  \itemitem{--} {\tt endptr}: if non-\.{NULL}, receives a pointer to the
    first character not consumed.
  \itemitem{--} {\tt base}: numeric base (2--36), or 0 for auto-detection
    from a \.{0x} or \.{0} prefix.  This program passes 10 (decimal).
  Returns the parsed {\tt long}; sets {\tt *endptr} past the converted
  text.  Used in |scan_long| to read the \.{PersonKey} integer from
  the JSON person-search response.

@* Index.

