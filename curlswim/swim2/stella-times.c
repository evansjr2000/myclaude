/*4:*/
#line 41 "stella-times.w"

/*6:*/
#line 53 "stella-times.w"

#include <stdio.h> 
#include <stdlib.h> 
#include <string.h> 
#include <curl/curl.h> 

/*:6*/
#line 42 "stella-times.w"

/*7:*/
#line 63 "stella-times.w"

#define NUM_EVENTS 12
#define MAX_TIMES  200

static const char SISENSE_TOKEN[]= 
"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9"
".eyJ1c2VyIjoiNjY0YmE2NmE5M2ZiYTUwMDM4NWIyMWQwIiwiYXBpU2VjcmV0Ijo"
"iNDQ0YTE3NWQtM2I1OC03NDhhLTVlMGEtYTVhZDE2MmRmODJlIiwiYWxsb3dlZFRl"
"bmFudHMiOlsiNjRhYzE5ZTEwZTkxNzgwMDFiYzM5YmVhIl0sInRlbmFudElkIjoiN"
"jRhYzE5ZTEwZTkxNzgwMDFiYzM5YmVhIn0"
".izSIvaD2udKTs3QRngla1Aw23kZVyoq7Xh23AbPUw1M";

static const char SISENSE_API[]= 
"https://usaswimming.sisense.com/api/datasources";

static const char*EVENTS[NUM_EVENTS]= {
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

/*:7*/
#line 43 "stella-times.w"

/*9:*/
#line 98 "stella-times.w"

typedef struct{
char*data;
size_t size;
}Buffer;

/*:9*//*10:*/
#line 112 "stella-times.w"

typedef struct{
double sort_key;
char time[32];
char date[16];
char standard[48];
char meet[256];
}TimeRow;

/*:10*/
#line 44 "stella-times.w"

/*12:*/
#line 127 "stella-times.w"

static size_t write_cb(void*ptr,size_t size,size_t nmemb,void*ud)
{
Buffer*b= (Buffer*)ud;
size_t n= size*nmemb;
char*p= realloc(b->data,b->size+n+1);
if(!p)return 0;
b->data= p;
memcpy(b->data+b->size,ptr,n);
b->size+= n;
b->data[b->size]= '\0';
return n;
}

/*:12*//*13:*/
#line 145 "stella-times.w"

static char*post_json(const char*url,const char*body)
{
CURL*curl= curl_easy_init();
if(!curl)return NULL;

Buffer buf= {NULL,0};

char auth_hdr[1600];
snprintf(auth_hdr,sizeof auth_hdr,
"Authorization: Bearer %s",SISENSE_TOKEN);

struct curl_slist*hdrs= NULL;
hdrs= curl_slist_append(hdrs,"Content-Type: application/json");
hdrs= curl_slist_append(hdrs,auth_hdr);

curl_easy_setopt(curl,CURLOPT_URL,url);
curl_easy_setopt(curl,CURLOPT_HTTPHEADER,hdrs);
curl_easy_setopt(curl,CURLOPT_POSTFIELDS,body);
curl_easy_setopt(curl,CURLOPT_WRITEFUNCTION,write_cb);
curl_easy_setopt(curl,CURLOPT_WRITEDATA,&buf);

CURLcode rc= curl_easy_perform(curl);
curl_slist_free_all(hdrs);
curl_easy_cleanup(curl);

if(rc!=CURLE_OK){free(buf.data);return NULL;}
return buf.data;
}

/*:13*/
#line 45 "stella-times.w"

/*16:*/
#line 190 "stella-times.w"

static int scan_string(const char*key,const char**pos,
char*out,size_t max_len)
{
char needle[128];
snprintf(needle,sizeof needle,"\"%s\"",key);
const char*p= strstr(*pos,needle);
if(!p)return 0;
p+= strlen(needle);
while(*p==' '||*p==':')p++;
if(*p!='"')return 0;
p++;
const char*e= strchr(p,'"');
if(!e)return 0;
size_t len= (size_t)(e-p);
if(len>=max_len)len= max_len-1;
memcpy(out,p,len);
out[len]= '\0';
*pos= e+1;
return 1;
}

/*:16*//*17:*/
#line 216 "stella-times.w"

static int scan_long(const char*key,const char**pos,long*out)
{
char needle[128];
snprintf(needle,sizeof needle,"\"%s\"",key);
const char*p= strstr(*pos,needle);
if(!p)return 0;
p+= strlen(needle);
while(*p==' '||*p==':')p++;
char*end;
*out= strtol(p,&end,10);
if(end==p)return 0;
*pos= end;
return 1;
}

/*:17*/
#line 46 "stella-times.w"

/*19:*/
#line 240 "stella-times.w"

static char*lookup_person_key(const char*search_query,
const char*match_substr,
const char**out_name)
{
char url[512];
snprintf(url,sizeof url,
"%s/aPublicIAAaPersonIAAaSearch/jaql",SISENSE_API);

char body[1024];
snprintf(body,sizeof body,
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

char*resp= post_json(url,body);
if(!resp){
fputs("Error: person lookup request failed\n",stderr);
return NULL;
}

char*key= NULL;
char*name= NULL;
const char*p= strstr(resp,"\"values\"");

while(p){
char full_name[256];
if(!scan_string("text",&p,full_name,sizeof full_name))break;


char lower[256];
size_t flen= strlen(full_name);
for(size_t i= 0;i<=flen;i++)
lower[i]= (char)(full_name[i]>='A'&&full_name[i]<='Z'
?full_name[i]+32:full_name[i]);

if(strstr(lower,match_substr)){
long pk;
if(scan_long("data",&p,&pk)){
char tmp[32];
snprintf(tmp,sizeof tmp,"%ld",pk);
key= strdup(tmp);
name= strdup(full_name);
}
break;
}
}

free(resp);
if(!key)
fprintf(stderr,"Error: swimmer \"%s\" not found\n",search_query);
if(out_name)*out_name= name;
else free(name);
return key;
}

/*:19*/
#line 47 "stella-times.w"

/*21:*/
#line 316 "stella-times.w"

static void insertion_sort(TimeRow*rows,int n)
{
for(int i= 1;i<n;i++){
TimeRow tmp= rows[i];
int j= i-1;
while(j>=0&&rows[j].sort_key> tmp.sort_key){
rows[j+1]= rows[j];
j--;
}
rows[j+1]= tmp;
}
}

/*:21*//*22:*/
#line 334 "stella-times.w"

static void format_date(const char*ymd8,char*out)
{
if(strlen(ymd8)==8){
out[0]= ymd8[0];out[1]= ymd8[1];out[2]= ymd8[2];out[3]= ymd8[3];
out[4]= '-';
out[5]= ymd8[4];out[6]= ymd8[5];
out[7]= '-';
out[8]= ymd8[6];out[9]= ymd8[7];
out[10]= '\0';
}else{
strncpy(out,ymd8,10);
out[10]= '\0';
}
}

/*:22*//*23:*/
#line 358 "stella-times.w"

static void fetch_times(const char*person_key,const char*event_code)
{
char url[512];
snprintf(url,sizeof url,
"%s/aUSAIAAaSwimmingIAAaTimesIAAaElasticube/jaql",SISENSE_API);

char body[2048];
snprintf(body,sizeof body,
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
person_key,event_code);

char*resp= post_json(url,body);
if(!resp){
fprintf(stderr,"Error: times request failed for %s\n",event_code);
return;
}

TimeRow rows[MAX_TIMES];
int nrows= 0;
const char*p= strstr(resp,"\"values\"");




while(p&&nrows<MAX_TIMES){
char time_str[32];
if(!scan_string("text",&p,time_str,sizeof time_str))break;
if(time_str[0]=='\0')break;

char sort_str[64];
if(!scan_string("text",&p,sort_str,sizeof sort_str))break;

char meet_str[256];
if(!scan_string("text",&p,meet_str,sizeof meet_str))break;

char date_str[16];
if(!scan_string("text",&p,date_str,sizeof date_str))break;

char std_str[48];
if(!scan_string("text",&p,std_str,sizeof std_str))break;

rows[nrows].sort_key= strtod(sort_str,NULL);
strncpy(rows[nrows].time,time_str,sizeof rows[nrows].time-1);
rows[nrows].time[sizeof rows[nrows].time-1]= '\0';
format_date(date_str,rows[nrows].date);
strncpy(rows[nrows].standard,std_str,
sizeof rows[nrows].standard-1);
rows[nrows].standard[sizeof rows[nrows].standard-1]= '\0';
strncpy(rows[nrows].meet,meet_str,sizeof rows[nrows].meet-1);
rows[nrows].meet[sizeof rows[nrows].meet-1]= '\0';
nrows++;
}

free(resp);
insertion_sort(rows,nrows);

printf("%s --- all times (fastest first):\n",event_code);
printf("%-12s  %-10s  %-13s  %s\n","Time","Date","Standard","Meet");
printf("%-12s  %-10s  %-13s  %s\n",
"------------","----------","-------------","----");
for(int i= 0;i<nrows;i++)
printf("%-12s  %-10s  %-13s  %s\n",
rows[i].time,rows[i].date,
rows[i].standard,rows[i].meet);
if(nrows==0)
printf("(no times found)\n");
putchar('\n');
}

/*:23*/
#line 48 "stella-times.w"

/*25:*/
#line 469 "stella-times.w"

typedef struct{
const char*search_query;
const char*match_substr;
}Swimmer;

static const Swimmer SWIMMERS[]= {
{"Julianna Evans","stella"},
{"Benavente","kalea"}
};
#define NUM_SWIMMERS ((int)(sizeof SWIMMERS / sizeof SWIMMERS[0]))

/*:25*//*26:*/
#line 485 "stella-times.w"

int main(void)
{
curl_global_init(CURL_GLOBAL_DEFAULT);

for(int s= 0;s<NUM_SWIMMERS;s++){
const char*name= NULL;
char*key= lookup_person_key(SWIMMERS[s].search_query,
SWIMMERS[s].match_substr,
&name);
if(!key){
curl_global_cleanup();
return 1;
}

printf("Swimmer: %s  (PersonKey: %s)\n\n",
name?name:"(unknown)",key);

for(int i= 0;i<NUM_EVENTS;i++)
fetch_times(key,EVENTS[i]);

free(key);
free((void*)name);
printf("\n");
}

curl_global_cleanup();
return 0;
}

/*:26*/
#line 49 "stella-times.w"


/*:4*/
