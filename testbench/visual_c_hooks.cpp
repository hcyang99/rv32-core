#include "DirectC.h"
#include <curses.h>
#include <stdio.h>
#include <signal.h>
#include <ctype.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/signal.h>
#include <unistd.h> 
#include <fcntl.h> 
#include <time.h>
#include <string.h>

#include "riscv_inst.h"


// program-wide parameters
static int ROB_ENTRIES;
static int RS_ENTRIES;
static int NUM_REGS;
static int PRF_ENTRIES;

/* ============================================================================
 *
 *                               STRUCT TYPEDEFS
 * 
 */

/* -------------------- structs for the main hardware components -------------------- */

typedef struct rob_struct{
    // TODO: include data for the rob here
} ROB;

typedef struct rs_struct {
    // TODO: include data for the rs here
} RS;

typedef struct rat_struct {
    // TODO: include data for the rat here
} RAT;

typedef struct rrat_struct {
    // TODO: include data for the rrat here
} RRAT;

typedef struct prf_struct {
    // TODO: include data for the prf here
} PRF;

typedef struct cache_struct {
    // TODO: include data for the cache here
} CACHE;

// main struct for holding all the data,
//      used for superscalar purposes
typedef struct page_struct{
    ROB rob;
    RS rs;
    RAT rat;
    RRAT rrat;
    PRF prf;
} page;


/* -------------------- structs for displaying system information -------------------- */

// TODO: include structs for displaying system information


/* 
 *                            END OF STRUCT TYPEDEFS
 *
 * ============================================================================
 */






/* ============================================================================
 *
 *                               GUI HANDLING
 * 
 */


/* -------------------- main windows to be displayed -------------------- */

WINDOW * rob_win;
WINDOW * rs_win;
WINDOW * rat_win;
WINDOW * rrat_win;
WINDOW * prf_win;

// TODO: include windows for displaying system information


/* -------------------- functions for printing each struct on screen -------------------- */

void draw_rob(WINDOW * win, ROB rob){
    box(win, 0, 0);
    mvwprintw(win, 1, 1, "REORDER BUFFER");
    // TODO: print the data
    // TODO: highlight data that has changed since the last cycle
}

void draw_rs(WINDOW * win, RS rs){
    box(win, 0, 0);
    mvwprintw(win, 1, 1, "RESERVATION STATION");
    // TODO: print the data
    // TODO: highlight data that has changed since the last cycle
}

void draw_rat(WINDOW * win, RAT rat){
    box(win, 0, 0);
    mvwprintw(win, 1, 1, "REGISTER ALIAS TABLE");
    // TODO: print the data
    // TODO: highlight data that has changed since the last cycle
}

void draw_rrat(WINDOW * win, RRAT rrat){
    box(win, 0, 0);
    mvwprintw(win, 1, 1, "RETIREMENT RAT");
    // TODO: print the data
    // TODO: highlight data that has changed since the last cycle
}

void draw_prf(WINDOW * win, PRF prf){
    box(win, 0, 0);
    mvwprintw(win, 1, 1, "PHYSICAL REGISTER TABLE");
    // TODO: print the data
    // TODO: highlight data that has changed since the last cycle
}

// TODO: include display functions for system information

// gui setup function
void setup_gui(){
    initscr();
    cbreak();
    noecho();

    nonl();
    intrflush(stdscr, FALSE);
    keypad(stdscr, TRUE);

    rob_win = newwin(12, ROB_ENTRIES, 0, 49);
    rs_win = newwin(RS_ENTRIES, 48, 12, 49);
    rat_win = newwin(NUM_REGS, 24, 0, 0);
    rrat_win = newwin(NUM_REGS, 24, 0, 25);
    prf_win = newwin(8, PRF_ENTRIES, 32, 0);

    refresh();
}

// main gui function
void redraw(int page_num, ROB rob, RS rs, RAT rat, RRAT rrat, PRF prf){
    draw_rob(rob_win, rob);
    draw_rs(rs_win, rs);
    draw_rat(rat_win, rat);
    draw_rrat(rrat_win, rrat);
    draw_prf(prf_win, prf);

}



/* 
 *                            END OF GUI HANDLING
 *
 * ============================================================================
 */








/* ============================================================================
 *
 *                               DATA HANDLING
 * 
 */

// BIG TODO: include all the data parsing and processing




/* 
 *                               END OF DATA HANDLING
 *
 * ============================================================================
 */



/* -------------------- driver function -------------------- */
extern "C" void initcurses(int n_superscalar){
    setup_gui();

    // setting up main data structure
    page pages[n_superscalar];

    page blank_page = {
        // TODO: fill this with the processor's initial state
    };

    // initializes every parallel component with the default initial state
    for(int i = 0; i < n_superscalar; ++i) pages[i] = blank_page;


    int page_num = 0;
    redraw(page_num, pages[page_num].rob, pages[page_num].rs, pages[page_num].rat, pages[page_num].rrat, pages[page_num].prf);
    int input = getch();



    // MAIN DRIVER FUNCTION
    //
    // redraws the screen each time the user types a command
    // invalid commands will prompt no action to be taken
    //
    // current commands include:
    //      q:          quit
    //      <Return>:   redraw the screen
    while(input != 'q'){
        bool valid_input = false;

        switch(input){
            // include cases for each user input
            // TODO: include more commands for the user
            case 'q':
                valid_input = true;
                break;
            case '\n':
                valid_input = true;
                break;
        }

        if(valid_input){
            redraw(page_num, pages[page_num].rob, pages[page_num].rs, pages[page_num].rat, pages[page_num].rrat, pages[page_num].prf);
        }
        input = getch();
    }

    endwin();
}
