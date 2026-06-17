#define DEFAULT_TARGET "2026-08-19 08:00:00"
#define WIN_W 520
#define WIN_H 220
#define FONT_NAME "10x20"
#define TICK_USEC 250000 \

/*4:*/
#line 36 "countdown.w"

/*5:*/
#line 56 "countdown.w"

#include <stdio.h>       
#include <stdlib.h>      
#include <string.h>      
#include <time.h>        
#include <unistd.h>      
#include <sys/select.h>  
#include <X11/Xlib.h>    
#include <X11/Xutil.h>   

/*:5*/
#line 37 "countdown.w"

/*6:*/
#line 78 "countdown.w"




/*:6*/
#line 38 "countdown.w"

/*7:*/
#line 88 "countdown.w"

typedef struct{
Display*dpy;
Window win;
GC gc;
XFontStruct*font;
int screen;
time_t target;
int running;
int started;
long frozen;
}App;

/*:7*/
#line 39 "countdown.w"

/*8:*/
#line 108 "countdown.w"

static time_t parse_target(const char*s)
{
struct tm tm;
int yr,mo,dy,hr,mi,se;
memset(&tm,0,sizeof tm);
if(sscanf(s,"%d-%d-%d %d:%d:%d",
&yr,&mo,&dy,&hr,&mi,&se)!=6){
fprintf(stderr,"countdown: bad target \"%s\" "
"(want YYYY-MM-DD HH:MM:SS)\n",s);
exit(2);
}
/*9:*/
#line 127 "countdown.w"

{
time_t t;
tm.tm_year= yr-1900;
tm.tm_mon= mo-1;
tm.tm_mday= dy;
tm.tm_hour= hr;
tm.tm_min= mi;
tm.tm_sec= se;
tm.tm_isdst= -1;
t= mktime(&tm);
if(t==(time_t)-1){
fprintf(stderr,"countdown: target is not a valid date\n");
exit(2);
}
return t;
}

/*:9*/
#line 120 "countdown.w"

}

/*:8*/
#line 40 "countdown.w"

/*10:*/
#line 150 "countdown.w"

static long remaining_secs(time_t target)
{
time_t now= time(NULL);
double d= difftime(target,now);
return d> 0.0?(long)d:0L;
}

/*:10*//*19:*/
#line 313 "countdown.w"

static void toggle_run(App*a)
{
if(!a->started){
a->started= 1;
a->running= 1;
}else if(a->running){
a->frozen= remaining_secs(a->target);
a->running= 0;
}else{
a->running= 1;
}
}

/*:19*/
#line 41 "countdown.w"

/*11:*/
#line 163 "countdown.w"

static void fmt_duration(long secs,char*buf,size_t n)
{
long d= secs/86400;
long r= secs%86400;
long h= r/3600;
long m= (r%3600)/60;
long s= r%60;
snprintf(buf,n,"%ld d  %02ld:%02ld:%02ld",d,h,m,s);
}

/*:11*/
#line 42 "countdown.w"

/*12:*/
#line 180 "countdown.w"

static void open_display(App*a)
{
a->dpy= XOpenDisplay(NULL);
if(a->dpy==NULL){
fprintf(stderr,"countdown: cannot open X display "
"(is DISPLAY set and an X server running?)\n");
exit(1);
}
a->screen= DefaultScreen(a->dpy);
}

/*:12*/
#line 43 "countdown.w"

/*13:*/
#line 198 "countdown.w"

static void create_window(App*a)
{
unsigned long white= WhitePixel(a->dpy,a->screen);
unsigned long black= BlackPixel(a->dpy,a->screen);
a->win= XCreateSimpleWindow(a->dpy,RootWindow(a->dpy,a->screen),
0,0,WIN_W,WIN_H,2,black,white);
XStoreName(a->dpy,a->win,"Countdown");
XSelectInput(a->dpy,a->win,
ExposureMask|KeyPressMask|
ButtonPressMask|StructureNotifyMask);
XMapWindow(a->dpy,a->win);
}

/*:13*/
#line 44 "countdown.w"

/*14:*/
#line 218 "countdown.w"

static void create_gc(App*a)
{
a->gc= XCreateGC(a->dpy,a->win,0,NULL);
XSetForeground(a->dpy,a->gc,BlackPixel(a->dpy,a->screen));
a->font= XLoadQueryFont(a->dpy,FONT_NAME);
if(a->font!=NULL)
XSetFont(a->dpy,a->gc,a->font->fid);
}

/*:14*/
#line 45 "countdown.w"

/*15:*/
#line 235 "countdown.w"

static void render(App*a)
{
static const char*hint= "[Space] or click: start/pause    [q]: quit";
char hdr[80],big[48],status[64];
long secs= (a->running)?remaining_secs(a->target):a->frozen;
/*16:*/
#line 255 "countdown.w"

{
struct tm*lt= localtime(&a->target);
strftime(hdr,sizeof hdr,"Target: %a %d %b %Y  %H:%M:%S",lt);
fmt_duration(secs,big,sizeof big);
if(secs==0&&a->started)
snprintf(status,sizeof status,"Status: THE MOMENT HAS ARRIVED");
else if(!a->started)
snprintf(status,sizeof status,"Status: ready -- press Space to start");
else
snprintf(status,sizeof status,"Status: %s",
a->running?"running":"paused");
}

/*:16*/
#line 241 "countdown.w"

XClearWindow(a->dpy,a->win);
XDrawString(a->dpy,a->win,a->gc,24,40,hdr,strlen(hdr));
XDrawString(a->dpy,a->win,a->gc,24,110,big,strlen(big));
XDrawString(a->dpy,a->win,a->gc,24,150,status,strlen(status));
XDrawString(a->dpy,a->win,a->gc,24,195,hint,strlen(hint));
XFlush(a->dpy);
}

/*:15*/
#line 46 "countdown.w"

/*17:*/
#line 276 "countdown.w"

static int handle_event(App*a,XEvent*ev)
{
switch(ev->type){
case Expose:case ConfigureNotify:
render(a);
break;
case KeyPress:
/*18:*/
#line 297 "countdown.w"

{
KeySym k= XLookupKeysym(&ev->xkey,0);
if(k==XK_q||k==XK_Escape)
return 0;
if(k==XK_space){
toggle_run(a);
render(a);
}
}

/*:18*/
#line 284 "countdown.w"

break;
case ButtonPress:
toggle_run(a);
render(a);
break;
}
return 1;
}

/*:17*/
#line 47 "countdown.w"

/*20:*/
#line 335 "countdown.w"

static void run_loop(App*a)
{
int xfd= ConnectionNumber(a->dpy);
for(;;){
/*21:*/
#line 350 "countdown.w"

while(XPending(a->dpy)> 0){
XEvent ev;
XNextEvent(a->dpy,&ev);
if(!handle_event(a,&ev)){
/*23:*/
#line 378 "countdown.w"

{
if(a->font)XFreeFont(a->dpy,a->font);
XFreeGC(a->dpy,a->gc);
XDestroyWindow(a->dpy,a->win);
XCloseDisplay(a->dpy);
exit(0);
}

/*:23*/
#line 355 "countdown.w"

}
}

/*:21*/
#line 340 "countdown.w"

/*22:*/
#line 364 "countdown.w"

{
fd_set rfds;
struct timeval tv;
FD_ZERO(&rfds);
FD_SET(xfd,&rfds);
tv.tv_sec= 0;
tv.tv_usec= TICK_USEC;
select(xfd+1,&rfds,NULL,NULL,&tv);
}

/*:22*/
#line 341 "countdown.w"

if(a->running)render(a);
}
}

/*:20*/
#line 48 "countdown.w"

/*24:*/
#line 391 "countdown.w"

int main(int argc,char**argv)
{
App a;
const char*spec= (argc> 1)?argv[1]:DEFAULT_TARGET;
memset(&a,0,sizeof a);
a.target= parse_target(spec);
a.frozen= remaining_secs(a.target);
/*25:*/
#line 407 "countdown.w"

{
open_display(&a);
create_window(&a);
create_gc(&a);
render(&a);
run_loop(&a);
}

/*:25*/
#line 399 "countdown.w"

return 0;
}

/*:24*/
#line 49 "countdown.w"


/*:4*/
