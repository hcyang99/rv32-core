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

#define PARENT_READ     readpipe[0]
#define CHILD_WRITE     readpipe[1]
#define CHILD_READ      writepipe[0]
#define PARENT_WRITE    writepipe[1]
#define NUM_HISTORY     256
#define NOOP_INST       0x00000013


/* ============================================================================
 *
 *                               VARIABLE DECLARATIONS
 * 
 */

// program-wide parameters
int N_WAYS;
int RS_SIZE;
int ROB_SIZE;
int PRF_SIZE;
int NUM_REGS;
int XLEN;

int ymax, xmax;

// these variables tell the gui what to print
char mode = '\0';

// variables for including important information
int fd[2], readpipe[2], writepipe[2];
int stdout_save;
int stdout_open;
void signal_handler_IO (int status);
int wait_flag = 0;
char done_state;
char echo_data;
FILE * fp;
FILE * fp2;
int setup_registers = 0;
int stop_time;
int done_time = -1;
char time_wrapped = 0;

int earliest_cycle = 0; // earliest cycle that the user can go to
int present_cycle = 0; // the cycle that the testbench is on
int curr_cycle = 0; // the cycle that the debugger is showing
int history_num = 0; // the index of our history buffer, corresponds to curr_cycle

char readbuffer[1024];

/* -------------------- structs for the main hardware components -------------------- */

typedef struct rs_line_struct {
    int opa_ready;
    int opa_value;
    int opb_ready;
    int opb_value;
    int dest_prn;
    int rob_idx;
} RS_LINE;

typedef struct rob_entry_struct {
    int dest_ARN;
    int dest_PRN;
    int reg_write;
    int is_branch;
    int PC;
    int target;
    int branch_direction;
    int mispredicted;
    int done;
    int illegal;
    int halt;
} ROB_ENTRY;



typedef struct if_struct {

} IF;

typedef struct id_struct {

} ID;

typedef struct rs_struct {
    RS_LINE * contents;
    int num_free;
} RS;

typedef struct rob_struct{
    ROB_ENTRY * entries;
    int num_free;
} ROB;

typedef struct rat_struct {
    int * prn;
    // TODO: free-list and valid-list
} RAT;

typedef struct rrat_struct {
    int * prn;
    // TODO: free-list and valid-list
} RRAT;

typedef struct prf_struct {
    int * value;
    // TODO: free-list and valid-list
} PRF;

typedef struct lsq_struct {
    // TODO: include data for the lsq here
} LSQ;

typedef struct cache_struct {
    // TODO: include data for the cache here
} CACHE;

ROB * rob;
RS * rs;
RAT * rat;
RRAT * rrat;
PRF * prf;


/* -------------------- structs for displaying system information -------------------- */

// TODO: include structs for displaying system information


/* 
 *                            END OF VARIABLE DECLARATIONS
 *
 * ============================================================================
 */






/* ============================================================================
 *
 *                               GUI HANDLING
 * 
 */


/* -------------------- main windows to be displayed -------------------- */

WINDOW * legend_win;
WINDOW * display_win;

WINDOW * rob_win;
WINDOW * rs_win;
WINDOW * rat_win;
WINDOW * rrat_win;
WINDOW * prf_win;

// TODO: include windows for displaying system information


/* -------------------- functions for printing each struct on screen -------------------- */

void draw_rob(){
    box(rob_win, 0, 0);

    mvwprintw(rob_win, 0, xmax / 2, "ROB");
    mvwprintw(rob_win, 1, 1, "entry#: ");
    mvwprintw(rob_win, 2, 1, "dest_arn: ");
    mvwprintw(rob_win, 3, 1, "dest_prn: ");
    mvwprintw(rob_win, 4, 1, "reg_write: ");
    mvwprintw(rob_win, 5, 1, "is_branch: ");
    mvwprintw(rob_win, 6, 1, "PC: ");
    mvwprintw(rob_win, 7, 1, "target: ");
    mvwprintw(rob_win, 8, 1, "direction: ");
    mvwprintw(rob_win, 9, 1, "mispredict: ");
    mvwprintw(rob_win, 10, 1, "done: ");
    mvwprintw(rob_win, 11, 1, "illegal: ");
    mvwprintw(rob_win, 12, 1, "halt: ");

    int entries_per_row = (xmax - 15) / 9;

    for(int i = 0; i < ROB_SIZE; ++i){
        int curr_row = i / entries_per_row;
        mvwprintw(rob_win, 1 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", i);
        mvwprintw(rob_win, 2 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].dest_ARN);
        mvwprintw(rob_win, 3 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].dest_PRN);
        mvwprintw(rob_win, 4 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].reg_write);
        mvwprintw(rob_win, 5 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].is_branch);
        mvwprintw(rob_win, 6 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].PC);
        mvwprintw(rob_win, 7 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].target);
        mvwprintw(rob_win, 8 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].branch_direction);
        mvwprintw(rob_win, 9 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].mispredicted);
        mvwprintw(rob_win, 10 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].done);
        mvwprintw(rob_win, 11 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].illegal);
        mvwprintw(rob_win, 12 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", rob[history_num].entries[i].halt);
    }
    // TODO: highlight data that has changed since the last cycle
    wrefresh(rob_win);
}

void draw_rs(){
    box(rs_win, 0, 0);
    mvwprintw(rs_win, 0, 1, "RS");
    // TODO: print the data
    // TODO: highlight data that has changed since the last cycle
    wrefresh(rs_win);
}

void draw_rat(){
    box(rat_win, 0, 0);
    box(rrat_win, 0, 0);
    mvwprintw(rat_win, 0, 1, "RAT");
    mvwprintw(rrat_win, 0, 1, "RRAT");
    // TODO: print the data
    // TODO: highlight data that has changed since the last cycle
    wrefresh(rat_win);
    wrefresh(rrat_win);
}

void draw_prf(){
    box(prf_win, 0, 0);
    mvwprintw(prf_win, 0, 1, "PRF");
    // TODO: print the data
    // TODO: highlight data that has changed since the last cycle
    wrefresh(prf_win);
}

void draw_menu(){
    mvaddstr(ymax / 2 - 2, xmax / 2 - 18, "__     _______ _   _ ____  _____ ____");
    mvaddstr(ymax / 2 - 1, xmax / 2 - 18, "\\ \\   / /_   _| | | | __ )| ____|  _ \\");
    mvaddstr(ymax / 2, xmax / 2 - 18, " \\ \\ / /  | | | | | |  _ \\|  _| | |_) |");
    mvaddstr(ymax / 2 + 1, xmax / 2 - 18, "  \\ V /   | | | |_| | |_) | |___|  _ <");
    mvaddstr(ymax / 2 + 2, xmax / 2 - 18, "   \\_/    |_|  \\___/|____/|_____|_| \\_\\");
    wrefresh(stdscr);
}

void draw_display(){
    mvwprintw(display_win, 0, 1, "CLOCK");
    mvwprintw(display_win, 1, 1, "cycle:");
    mvwprintw(display_win, 1, 8, "%d", curr_cycle);
    wrefresh(display_win);
}

// TODO: include display functions for system information

// main gui function
void redraw(){
    refresh();
    /*
    switch(mode){
        case 'o': draw_rob(); break;
        case 's': draw_rs(); break;
        case 'r': draw_rat(); break;
        case 'p': draw_prf(); break;
        default: draw_menu(); break;
    }
    */
    draw_menu();
    draw_display();
    refresh();
}


// gui setup function
void setup_gui(){
    initscr();
    cbreak();
    noecho();

    nonl();
    intrflush(stdscr, FALSE);
    keypad(stdscr, TRUE);

    getmaxyx(stdscr, ymax, xmax);

    rob_win = newwin(14 * (ROB_SIZE / ((xmax-15)/9) + 1), xmax, 0, 0);

    // each entry:
    //      RS #: 3 chars
    //      FUNC UNIT: 5 chars
    //      OPERAND: 38 chars
    //      DEST PRN: 3 chars
    //      ROB index: 3 chars
    rs_win = newwin(RS_SIZE + 1, 54, 0, 0);

    rat_win = newwin(NUM_REGS + 1, 8, 0, 0);
    rrat_win = newwin(NUM_REGS + 1, 8, 0, 9);
    prf_win = newwin(PRF_SIZE + 1, 22, 0, 0);

    display_win = newwin(3, 12, ymax - 3, xmax - 12);

    refresh();
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


int processinput(){
    if(strncmp(readbuffer,"o",1) == 0){
        int i;
        sscanf(readbuffer, "o%d", &i);
        sscanf(readbuffer, "o%d %d %d %d %d %d %d %d %d %d %d %d",
            &i,
            &(rob[history_num].entries[i].dest_ARN),
            &(rob[history_num].entries[i].dest_PRN),
            &(rob[history_num].entries[i].reg_write),
            &(rob[history_num].entries[i].is_branch),
            &(rob[history_num].entries[i].PC),
            &(rob[history_num].entries[i].target),
            &(rob[history_num].entries[i].branch_direction),
            &(rob[history_num].entries[i].mispredicted),
            &(rob[history_num].entries[i].done),
            &(rob[history_num].entries[i].illegal),
            &(rob[history_num].entries[i].halt));
    }
    else if(strncmp(readbuffer,"c",1) == 0){
        int clock;
        int clock_count;
        sscanf(readbuffer, "c%h%7.0d", clock, clock_count);
        mvwprintw(stdscr, ymax - 20, 0, "clock: %d", clock);
        mvwprintw(stdscr, ymax - 10, 0, "clock_count: %d", clock_count);
    }
    else if(strncmp(readbuffer,"break",4) == 0){
        return(1);
    }
    return(0);
}


/* 
 *                               END OF DATA HANDLING
 *
 * ============================================================================
 */



/* -------------------- driver function -------------------- */
extern "C" void initcurses(int n_ways_in, int rs_size_in, int rob_size_in, int prf_size_in, int num_regs_in, int xlen_in){

    N_WAYS = n_ways_in;
    RS_SIZE = rs_size_in;
    ROB_SIZE = rob_size_in;
    PRF_SIZE = prf_size_in;
    NUM_REGS = num_regs_in;
    XLEN = xlen_in;


    if(pipe(readpipe) == -1)
        return;
    if(pipe(writepipe) == -1)
        return;

    char input = 0;
    int testbench_finished = 0;
    int mem_addr = 0;

    pid_t pid = fork();
    switch(pid){
    case 0: /* Child process */
        close(PARENT_WRITE);
        close(PARENT_READ);
        fp = fdopen(CHILD_READ, "r");
        fp2 = fopen("program.out", "w");

        setup_gui();

        // setting up main data structure
        rob = (ROB *)malloc(sizeof(ROB) * NUM_HISTORY);
        for(int i = 0; i < NUM_HISTORY; ++i){
            rob[i].entries = (ROB_ENTRY *)malloc(sizeof(ROB_ENTRY) * ROB_SIZE);
        }

        memset(readbuffer,'\0',sizeof(readbuffer));

        while(input != 'q'){
            history_num = curr_cycle % NUM_HISTORY;

            // reads input from testbench until it encounters a "break"
            int ready = 0;
            /*while(!ready && !testbench_finished){
                fgets(readbuffer, sizeof(readbuffer), fp);
                ready = processinput();
                if(strcmp(readbuffer, "DONE") == 0){
                    testbench_finished = 1;
                }
            }*/

            // writing the state of the program to a pipe
            // this will be picked up by waitforresponse()
            if(testbench_finished)
                write(CHILD_WRITE, "Z", 1);
            else{
                write(CHILD_WRITE, "n", 1);
                write(CHILD_WRITE, &mem_addr, 2);
            }

            char take_input = 1; // set while we're taking user input, 0 if testbench needs to advance

            redraw();
            // loop redraws the screen each time the user types a command
            // invalid commands will prompt no action to be taken
            //
            // current commands include:
            //      n:          go ahead one next cycle
            //      b:          go back one cycle (up to XXX cycles away from present cycle)
            //      q:          quit
            //      o:          display the rob
            //      s:          display the rs
            //      r:          display the rat and rrat
            //      p:          display the prf
            //      <Return>:   redraw the screen
            do{
                mvwprintw(stdscr, ymax - 2, 0, "take_input: %d", take_input);
                mvwprintw(stdscr, ymax - 1, 0, "testbench_finished: %d", testbench_finished);
                input = getch();
                clear();

                switch(input){
                    // include cases for each user input
                    case 'n':
                        // if we're in sync with the testbench, wait for testbench to move ahead one cycle
                        if(present_cycle == curr_cycle && !testbench_finished){
                            ++present_cycle;
                            ++curr_cycle;
                            take_input = 0;
                        }
                        // if we're not in sync with the testbench, move just the debugger ahead
                        else if(present_cycle != curr_cycle){
                            ++curr_cycle;
                            ++history_num;
                        }
                        history_num %= NUM_HISTORY;
                        mvwprintw(stdscr, ymax - 5, 0, "read_n");
                        mvwprintw(stdscr, ymax - 4, 0, "cycle: %d", curr_cycle);
                        break;
                    case 'b':
                        if(history_num != 0){
                            --curr_cycle;
                            --history_num;
                        }
                        break;
                    case 'q':
                        take_input = 0;
                        break;
                    case 'o': mode = 'o';mvwprintw(stdscr, ymax - 5, 0, "read_o"); mvwprintw(stdscr, ymax - 4, 0, "cycle: %d", curr_cycle);break;
                    case 's': mode = 's'; break;
                    case 'r': mode = 'r'; break;
                    case 'p': mode = 'p'; break;
                    case '\n':
                        break;
                }

                redraw();
            } while(take_input);
            mvwprintw(stdscr, ymax - 8, 0, "take_input: %d", take_input);
            mvwprintw(stdscr, ymax - 7, 0, "testbench_finished: %d", testbench_finished);
            mvwprintw(stdscr, ymax - 6, 0, "cycle: %d", curr_cycle);
            read(CHILD_READ, readbuffer, 1);
        }
        refresh();
        endwin();
        fflush(stdout);
        if(input == 'q'){
            fclose(fp2);
            write(CHILD_WRITE, "Z", 1);
            exit(0);
        }
        readbuffer[0] = 0;
        while(strncmp(readbuffer,"DONE",4) != 0){
            if(fgets(readbuffer, sizeof(readbuffer), fp) != NULL)
                fputs(readbuffer, fp2);
        }
        fclose(fp2);
        fflush(stdout);
        write(CHILD_WRITE, "Z", 1);
        printf("Child Done Execution\n");
        exit(0);
    default: /* Parent process */
        // close the pipes used by the child process
        close(CHILD_READ);
        close(CHILD_WRITE);

        // this line will copy stdout to PARENT_WRITE, so that
        // CHILD_READ actually reads from stdout a.k.a. the testbench
        dup2(PARENT_WRITE, 1);
        close(PARENT_WRITE);
    }
}

extern "C" int waitforresponse() {
    static int mem_start = 0;
    char c=0;
    while(c!='n' && c!='Z') read(PARENT_READ, &c, 1);
    if(c=='Z') exit(0);
    //mem_start = read(PARENT_READ, &c, 1);
    //mem_start = mem_start << 8 + read(PARENT_READ, &c, 1);
    return(mem_start);
}

extern "C" void flushproc(){
    char c = 0;
    read(PARENT_READ, &c, 1);
}
