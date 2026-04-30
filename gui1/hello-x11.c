/*7:*/
#line 88 "hello-x11.w"

/*9:*/
#line 108 "hello-x11.w"

#include <stdio.h> 
#include <stdlib.h> 
#include <string.h> 
#include <time.h> 
#include <X11/Xlib.h> 
#include <X11/Xutil.h> 

/*:9*/
#line 89 "hello-x11.w"

/*10:*/
#line 120 "hello-x11.w"

#define WIN_W      320     
#define WIN_H      160     
#define BTN_W      120     
#define BTN_H       40     
#define MARGIN      20     
#define WIN_TITLE   "Hello X11"

/*:10*//*11:*/
#line 133 "hello-x11.w"

#define HELLO_X    ((WIN_W - BTN_W) / 2)
#define HELLO_Y    MARGIN
#define EXIT_X     ((WIN_W - BTN_W) / 2)
#define EXIT_Y     (MARGIN + BTN_H + MARGIN)

/*:11*/
#line 90 "hello-x11.w"

/*13:*/
#line 146 "hello-x11.w"

typedef struct{
int x,y;
int w,h;
const char*label;
}Button;

/*:13*/
#line 91 "hello-x11.w"

/*14:*/
#line 159 "hello-x11.w"

static Display*g_dpy= NULL;
static GC g_gc= NULL;
static Window g_win= 0;
static Atom g_wm_delete= 0;

/*:14*//*15:*/
#line 169 "hello-x11.w"

static const Button g_buttons[2]= {
{HELLO_X,HELLO_Y,BTN_W,BTN_H,"Hello"},
{EXIT_X,EXIT_Y,BTN_W,BTN_H,"Exit"}
};
#define N_BUTTONS ((int)(sizeof g_buttons / sizeof g_buttons[0]))

/*:15*/
#line 92 "hello-x11.w"

/*17:*/
#line 184 "hello-x11.w"

static void format_local_time(char*out,size_t max_len)
{
time_t now= time(NULL);
struct tm*lt= localtime(&now);
if(lt)strftime(out,max_len,"%Y-%m-%d %H:%M:%S",lt);
else snprintf(out,max_len,"(time unavailable)");
}

/*:17*/
#line 93 "hello-x11.w"

/*19:*/
#line 199 "hello-x11.w"

static int hit_test(int x,int y)
{
for(int i= 0;i<N_BUTTONS;i++){
const Button*b= &g_buttons[i];
if(x>=b->x&&x<b->x+b->w&&
y>=b->y&&y<b->y+b->h)
return i;
}
return-1;
}

/*:19*/
#line 94 "hello-x11.w"

/*21:*/
#line 219 "hello-x11.w"

static void draw_button(const Button*b)
{
XDrawRectangle(g_dpy,g_win,g_gc,b->x,b->y,b->w,b->h);
/*22:*/
#line 231 "hello-x11.w"

int dir,ascent,descent;
XCharStruct ext;
int len= (int)strlen(b->label);
XQueryTextExtents(g_dpy,XGContextFromGC(g_gc),
b->label,len,&dir,&ascent,&descent,&ext);
int tx= b->x+(b->w-ext.width)/2;
int ty= b->y+(b->h+ascent-descent)/2;
XDrawString(g_dpy,g_win,g_gc,tx,ty,b->label,len);

/*:22*/
#line 223 "hello-x11.w"

}

/*:21*//*23:*/
#line 245 "hello-x11.w"

static void draw_buttons(void)
{
for(int i= 0;i<N_BUTTONS;i++)
draw_button(&g_buttons[i]);
}

/*:23*/
#line 95 "hello-x11.w"

/*25:*/
#line 261 "hello-x11.w"

static void on_hello_click(void)
{
char ts[32];
format_local_time(ts,sizeof ts);
printf("Hello World, and the current local time: %s\n",ts);
fflush(stdout);
}

/*:25*//*26:*/
#line 275 "hello-x11.w"

static int on_button_press(const XButtonEvent*ev)
{
int idx= hit_test(ev->x,ev->y);
if(idx<0)return 0;
if(strcmp(g_buttons[idx].label,"Hello")==0){
on_hello_click();
return 0;
}
if(strcmp(g_buttons[idx].label,"Exit")==0){
return 1;
}
return 0;
}

/*:26*//*27:*/
#line 296 "hello-x11.w"

static int on_client_message(const XClientMessageEvent*ev)
{
if((Atom)ev->data.l[0]==g_wm_delete)return 1;
return 0;
}

/*:27*/
#line 96 "hello-x11.w"

/*29:*/
#line 312 "hello-x11.w"

static int display_open(void)
{
/*30:*/
#line 328 "hello-x11.w"

g_dpy= XOpenDisplay(NULL);
if(!g_dpy){
fputs("Error: cannot open X display "
"(is $DISPLAY set?)\n",stderr);
return 0;
}

/*:30*/
#line 315 "hello-x11.w"

/*31:*/
#line 346 "hello-x11.w"

int scr= DefaultScreen(g_dpy);
Window root= RootWindow(g_dpy,scr);
g_win= XCreateSimpleWindow(g_dpy,root,0,0,WIN_W,WIN_H,1,
BlackPixel(g_dpy,scr),
WhitePixel(g_dpy,scr));
XStoreName(g_dpy,g_win,WIN_TITLE);
XSelectInput(g_dpy,g_win,
ExposureMask|ButtonPressMask|StructureNotifyMask);

/*:31*/
#line 316 "hello-x11.w"

/*32:*/
#line 362 "hello-x11.w"

g_gc= XCreateGC(g_dpy,g_win,0,NULL);
if(!g_gc){
fputs("Error: cannot create graphics context\n",stderr);
XDestroyWindow(g_dpy,g_win);
XCloseDisplay(g_dpy);
g_dpy= NULL;
return 0;
}
XSetForeground(g_dpy,g_gc,BlackPixel(g_dpy,DefaultScreen(g_dpy)));

/*:32*/
#line 317 "hello-x11.w"

/*33:*/
#line 379 "hello-x11.w"

g_wm_delete= XInternAtom(g_dpy,"WM_DELETE_WINDOW",False);
XSetWMProtocols(g_dpy,g_win,&g_wm_delete,1);

/*:33*/
#line 318 "hello-x11.w"

XMapWindow(g_dpy,g_win);
return 1;
}

/*:29*/
#line 97 "hello-x11.w"

/*35:*/
#line 390 "hello-x11.w"

static void display_close(void)
{
if(g_dpy){
if(g_gc){XFreeGC(g_dpy,g_gc);g_gc= NULL;}
if(g_win){XDestroyWindow(g_dpy,g_win);g_win= 0;}
XCloseDisplay(g_dpy);
g_dpy= NULL;
}
}

/*:35*/
#line 98 "hello-x11.w"

/*37:*/
#line 409 "hello-x11.w"

int main(int argc,char**argv)
{
(void)argc;(void)argv;
if(!display_open())return 1;
/*38:*/
#line 422 "hello-x11.w"

for(;;){
XEvent ev;
XNextEvent(g_dpy,&ev);
int quit= 0;
switch(ev.type){
case Expose:
if(ev.xexpose.count==0)draw_buttons();
break;
case ButtonPress:
quit= on_button_press(&ev.xbutton);
break;
case ClientMessage:
quit= on_client_message(&ev.xclient);
break;
default:
break;
}
if(quit)break;
}

/*:38*/
#line 414 "hello-x11.w"

display_close();
return 0;
}

/*:37*/
#line 99 "hello-x11.w"


/*:7*/
