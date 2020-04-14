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

char* decode(int inst, int valid_inst);
char* decode_alu(int alu);

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
FILE * fp;
FILE * fp2;

int clock_edge = 0;
char time_wrapped = 0;

int earliest_cycle = 0; // earliest cycle that the user can go to
int present_cycle = 0; // the cycle that the testbench is on
int curr_cycle = 0; // the cycle that the debugger is showing
int history_num = 0; // the index of our history buffer, corresponds to curr_cycle

char readbuffer[1024];

/* -------------------- structs for the main hardware components -------------------- */

typedef struct rs_line_struct {
    char func[7];
    char opa_ready[2];
    char opa_value[9];
    char opb_ready[2];
    char opb_value[9];
    char dest_prn[3];
    char rob_idx[3];
    char PC[17];
} RS_LINE;

typedef struct rob_entry_struct {
    char dest_ARN[3];
    char dest_PRN[3];
    char reg_write[2];
    char is_branch[2];
    char PC[9];
    char target[9];
    char branch_direction[2];
    char mispredicted[2];
    char done[2];
    char illegal[2];
    char halt[2];
} ROB_ENTRY;



typedef struct if_struct {
    char ** insts;
    char ** pc;
} IF;

typedef struct id_struct {
    char ** insts;
    char ** pc;
} ID;

typedef struct rs_struct {
    RS_LINE * contents;
    int num_free;
} RS;

typedef struct rob_struct{
    ROB_ENTRY * entries;
    int num_free;
    int head;
    int tail;
} ROB;

typedef struct rat_struct {
    char ** prn;
    char ** freelist;
    char ** validlist;
} RAT;

typedef struct prf_struct {
    char ** value;
} PRF;

typedef struct lsq_struct {
    // TODO: include data for the lsq here
} LSQ;

typedef struct cache_struct {
    // TODO: include data for the cache here
} CACHE;

IF * if_stage;
ID * id_stage;

ROB * rob;
RS * rs;
RAT * rat;
RAT * rrat;
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
WINDOW * display_rob_win;
WINDOW * display_rs_win;
WINDOW * display_rat_prf_win;
WINDOW * clock_win;

WINDOW * if_win;
WINDOW * id_win;

WINDOW * rob_win;
WINDOW * rs_win;
WINDOW * rat_win;
WINDOW * rrat_win;
WINDOW * prf_win;

// TODO: include windows for displaying system information


/* -------------------- functions for printing each struct on screen -------------------- */

void draw_if(){
    box(if_win, 0, 0);
    IF * cif_stage = if_stage + history_num;

    mvwprintw(if_win, 0, 3, "IF");
    for(int i = 0; i < N_WAYS; ++i){
        mvwprintw(if_win, 1, 6 + 9 * i, "        ");
        mvwprintw(if_win, 2, 6 + 9 * i, "        ");
        mvwprintw(if_win, 1, 6 + 9 * i, "%s", cif_stage->insts[i]);
        mvwprintw(if_win, 2, 6 + 9 * i, "%s", cif_stage->pc[i]);
    }
    wrefresh(if_win);
}

void draw_id(){
    box(id_win, 0, 0);
    ID * cid_stage = id_stage + history_num;

    mvwprintw(id_win, 0, 3, "ID");
    for(int i = 0; i < N_WAYS; ++i){
        mvwprintw(id_win, 1, 6 + 9 * i, "        ");
        mvwprintw(id_win, 2, 6 + 9 * i, "        ");
        mvwprintw(id_win, 1, 6 + 9 * i, "%s", cid_stage->insts[i]);
        mvwprintw(id_win, 2, 6 + 9 * i, "%s", cid_stage->pc[i]);
    }
    wrefresh(id_win);
}

void draw_rob(){
    box(rob_win, 0, 0);

    int entries_per_row = (xmax - 15) / 9;
    int num_rows = ROB_SIZE / entries_per_row + 1;
    ROB * crob = rob + history_num;

    mvwprintw(rob_win, 0, xmax / 2, "ROB");
    for(int i = 0; i < num_rows; ++i){
        mvwprintw(rob_win, 1 + 13 * i, 1, "entry#: ");
        mvwprintw(rob_win, 2 + 13 * i, 1, "dest_arn: ");
        mvwprintw(rob_win, 3 + 13 * i, 1, "dest_prn: ");
        mvwprintw(rob_win, 4 + 13 * i, 1, "reg_write: ");
        mvwprintw(rob_win, 5 + 13 * i, 1, "is_branch: ");
        mvwprintw(rob_win, 6 + 13 * i, 1, "PC: ");
        mvwprintw(rob_win, 7 + 13 * i, 1, "target: ");
        mvwprintw(rob_win, 8 + 13 * i, 1, "direction: ");
        mvwprintw(rob_win, 9 + 13 * i, 1, "mispredict: ");
        mvwprintw(rob_win, 10 + 13 * i, 1, "done: ");
        mvwprintw(rob_win, 11 + 13 * i, 1, "illegal: ");
        mvwprintw(rob_win, 12 + 13 * i, 1, "halt: ");
    }

    for(int i = 0; i < ROB_SIZE; ++i){
        int curr_row = 13 * (i / entries_per_row);
        mvwprintw(rob_win, 1 + curr_row, 13 + ((i % entries_per_row) * 9), "    ");

        wattron(rob_win, COLOR_PAIR(6));
        if(i == crob->head)
            mvwprintw(rob_win, 1 + curr_row, 13 + ((i % entries_per_row) * 9), "HEAD");
        else if(i == crob->tail)
            mvwprintw(rob_win, 1 + curr_row, 13 + ((i % entries_per_row) * 9), "TAIL");
        else{
            wattroff(rob_win, COLOR_PAIR(6));
            mvwprintw(rob_win, 1 + curr_row, 13 + ((i % entries_per_row) * 9), "%d", i);
        }
        wattroff(rob_win, COLOR_PAIR(6));

        mvwprintw(rob_win, 2 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].dest_ARN);
        mvwprintw(rob_win, 3 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].dest_PRN);
        mvwprintw(rob_win, 4 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].reg_write);
        mvwprintw(rob_win, 5 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].is_branch);
        mvwprintw(rob_win, 6 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].PC);
        mvwprintw(rob_win, 7 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].target);
        mvwprintw(rob_win, 8 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].branch_direction);
        mvwprintw(rob_win, 9 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].mispredicted);
        mvwprintw(rob_win, 10 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].done);
        mvwprintw(rob_win, 11 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].illegal);
        mvwprintw(rob_win, 12 + curr_row, 13 + ((i % entries_per_row) * 9), "%s", crob->entries[i].halt);
    }

    mvwprintw(rob_win, num_rows * 13, 1, "                           ");
    mvwprintw(rob_win, num_rows * 13, 1, "head:%d tail:%d num_free:%d", crob->head, crob->tail, crob->num_free);
    // TODO: highlight data that has changed since the last cycle
    wrefresh(rob_win);
}

void draw_rs(){
    box(rs_win, 0, 0);

    RS * crs = rs + history_num;

    mvwprintw(rs_win, 0, 28, "RS");
    mvwprintw(rs_win, 1, 1, "RS#");
    mvwprintw(rs_win, 1, 5, "FUNC");
    mvwprintw(rs_win, 1, 12, "RDY");
    mvwprintw(rs_win, 1, 16, "OPA");
    mvwprintw(rs_win, 1, 33, "RDY");
    mvwprintw(rs_win, 1, 37, "OPB");
    mvwprintw(rs_win, 1, 54, "PRN");
    mvwprintw(rs_win, 1, 58, "ROB");
    mvwprintw(rs_win, 1, 62, "PC");

    for(int i = 0; i < RS_SIZE; ++i){
        mvwprintw(rs_win, i + 2, 1, "%d", i);
        mvwprintw(rs_win, i + 2, 5, "      ");
        mvwprintw(rs_win, i + 2, 5, "%s", crs->contents[i].func);
        mvwprintw(rs_win, i + 2, 12, "%s", crs->contents[i].opa_ready);
        mvwprintw(rs_win, i + 2, 16, "%s", crs->contents[i].opa_value);
        mvwprintw(rs_win, i + 2, 33, "%s", crs->contents[i].opb_ready);
        mvwprintw(rs_win, i + 2, 37, "%s", crs->contents[i].opb_value);
        mvwprintw(rs_win, i + 2, 54, "%s", crs->contents[i].dest_prn);
        mvwprintw(rs_win, i + 2, 58, "%s", crs->contents[i].rob_idx);
        mvwprintw(rs_win, i + 2, 62, "%s", crs->contents[i].PC);
    }
    // TODO: highlight data that has changed since the last cycle
    wrefresh(rs_win);
}

void draw_rat_prf(){
    box(rat_win, 0, 0);
    box(rrat_win, 0, 0);

    mvwprintw(rat_win, 0, 1, "RAT");
    mvwprintw(rrat_win, 0, 1, "RRAT");

    RAT * crat = rat + history_num;
    RAT * crrat = rrat + history_num;

    mvwprintw(rat_win, 1, 2, "ALIAS      FREELIST     ALIAS      FREELIST  ");
    mvwprintw(rrat_win, 1, 2, "ALIAS      FREELIST     ALIAS      FREELIST  ");

    mvwprintw(rat_win, 2, 1, "ARN PRN   PRN FREE VLD  ARN PRN   PRN FREE VLD");
    mvwprintw(rrat_win, 2, 1, "ARN PRN   PRN FREE VLD  ARN PRN   PRN FREE VLD");

    int num_cols = (PRF_SIZE + 4) / ymax + 1;
    int num_rows = PRF_SIZE / num_cols;

    for(int i = 0; i < 32; ++i){
        mvwprintw(rat_win, (i % num_rows) + 3, 1 + 24 * (i / num_rows), "%3d %s", i, crat->prn[i]);
        mvwprintw(rrat_win, (i % num_rows) + 3, 1 + 24 * (i / num_rows), "%3d %s", i, crat->prn[i]);
    }

    for(int i = 0; i < PRF_SIZE; ++i){
        mvwprintw(rat_win, (i % num_rows) + 3, 11 + 24 * (i / num_rows), "%3d   %s    %s", i, crat->freelist[i], crat->validlist[i]);
        mvwprintw(rrat_win, (i % num_rows) + 3, 11 + 24 * (i / num_rows), "%3d   %s    %s", i, crat->freelist[i], crrat->validlist[i]);
    }

    // TODO: highlight data that has changed since the last cycle
    wrefresh(rat_win);
    wrefresh(rrat_win);

    box(prf_win, 0, 0);

    PRF * cprf = prf + history_num;

    mvwprintw(prf_win, 0, 8, "PRF");
    mvwprintw(prf_win, 1, 1, "PRN   VALUE  PRN   VALUE ");

    for(int i = 0; i < PRF_SIZE; ++i){
        mvwprintw(prf_win, i % num_rows + 2, 2 + 13 * (i / num_rows), "%3d %s", i, cprf->value[i]);
    }

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

void draw_legend(){
    box(legend_win, 0, 0);
    mvwaddstr(legend_win, 1, 1, "n : next cycle");
    mvwaddstr(legend_win, 2, 1, "b : previous cycle");
    mvwaddstr(legend_win, 3, 1, "o : display rob");
    mvwaddstr(legend_win, 4, 1, "s : display rs");
    mvwaddstr(legend_win, 5, 1, "r : display rat/prf");
    mvwaddstr(legend_win, 6, 1, "q : quit");
    wrefresh(legend_win);
}

void draw_display(){
    wattroff(display_rob_win, COLOR_PAIR(1));
    wattroff(display_rs_win, COLOR_PAIR(1));
    wattroff(display_rat_prf_win, COLOR_PAIR(1));

    switch(mode){
    case 'o': wattron(display_rob_win, COLOR_PAIR(1)); break;
    case 's': wattron(display_rs_win, COLOR_PAIR(1)); break;
    case 'r': wattron(display_rat_prf_win, COLOR_PAIR(1)); break;
    }

    box(display_rob_win, 0, 0);
    box(display_rs_win, 0, 0);
    box(display_rat_prf_win, 0, 0);

    mvwaddstr(display_rob_win, 1, 1, "ROB");
    mvwaddstr(display_rs_win, 1, 1, "RS");
    mvwaddstr(display_rat_prf_win, 1, 1, "RAT");

    wrefresh(display_rob_win);
    wrefresh(display_rs_win);
    wrefresh(display_rat_prf_win);
}

void draw_clock(){
    box(clock_win, 0, 0);
    mvwprintw(clock_win, 0, 4, "CLOCK");
    mvwprintw(clock_win, 1, 1, "cycle:");
    mvwprintw(clock_win, 1, 8, "   ");
    mvwprintw(clock_win, 1, 8, "%d", curr_cycle);
    mvwprintw(clock_win, 2, 1, "           ");
    mvwprintw(clock_win, 2, 1, "present:%d", present_cycle);
    mvwprintw(clock_win, 3, 1, "           ");
    mvwprintw(clock_win, 3, 1, "histnum:%d", history_num);
    wrefresh(clock_win);
}

// TODO: include display functions for system information

// main gui function
void redraw(){
    refresh();
    switch(mode){
        case 'o': draw_rob(); break;
        case 's': draw_rs(); break;
        case 'r': draw_rat_prf(); break;
        default: draw_menu(); break;
    }
    draw_if();
    draw_id();
    draw_legend();
    draw_clock();
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

    if(has_colors()){
        start_color();
        init_pair(0,COLOR_WHITE,COLOR_WHITE);
        init_pair(1,COLOR_CYAN,COLOR_BLACK);    // shell background
        init_pair(2,COLOR_YELLOW,COLOR_RED);
        init_pair(3,COLOR_RED,COLOR_BLACK);
        init_pair(4,COLOR_YELLOW,COLOR_BLUE);   // title window
        init_pair(5,COLOR_YELLOW,COLOR_BLACK);  // register/signal windows
        init_pair(6,COLOR_RED,COLOR_BLACK);
        init_pair(7,COLOR_MAGENTA,COLOR_BLACK); // pipeline window
        init_pair(8,COLOR_BLUE, COLOR_BLACK);
    }

    getmaxyx(stdscr, ymax, xmax);

    if_win = newwin(5, 8 + 9 * N_WAYS, ymax - 6, 25);
    id_win = newwin(5, 8 + 9 * N_WAYS, ymax - 6, 25 + 8 + 9 * N_WAYS);
    wattron(if_win, COLOR_PAIR(5));
    wattron(id_win, COLOR_PAIR(5));

    rob_win = newwin(14 * (ROB_SIZE / ((xmax-15)/9) + 1) + 1, xmax, 0, 0);
    rs_win = newwin(RS_SIZE + 3, 79, 0, 0);

    int num_cols = (PRF_SIZE + 4)/ ymax + 1;
    int num_rows = PRF_SIZE / num_cols + 1;

    rat_win = newwin(num_rows + 4, 24 * num_cols, 0, 0);
    rrat_win = newwin(num_rows + 4, 24 * num_cols, 0, 24 * num_cols);
    prf_win = newwin(num_rows + 4, 14 * num_cols, 0, 48 * num_cols);

    legend_win = newwin(9, 25, ymax - 9, 0);
    wattron(legend_win, COLOR_PAIR(5));
    clock_win = newwin(5, 12, ymax - 8, xmax - 12);

    display_rob_win = newwin(3, 5, ymax - 3, xmax - 21);
    display_rs_win = newwin(3, 5, ymax - 3, xmax - 14);
    display_rat_prf_win = newwin(3, 5, ymax - 3, xmax - 7);

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


int processinput(){
    if(strncmp(readbuffer,"f",1) == 0){
        IF * cif_stage = if_stage + ((history_num + 1) % NUM_HISTORY);
        int i = 0;
        char inst_str[9];
        char valid_str[2];
        sscanf(readbuffer, "f%d", &i);
        sscanf(readbuffer, "f%d %s %s %s",
                &i,
                inst_str,
                valid_str,
                cif_stage->pc[i]);
        int valid = (valid_str[0] == 'x') ? 0 : 1;
        int inst = atoi(inst_str);
        strcpy(cif_stage->insts[i], decode(inst, valid));
    }
    else if(strncmp(readbuffer,"d",1) == 0){
        ID * cid_stage = id_stage + ((history_num + 1) % NUM_HISTORY);
        int i = 0;
        char inst_str[9];
        char valid_str[2];
        sscanf(readbuffer, "d%d", &i);
        sscanf(readbuffer, "d%d %s %s %s",
                &i,
                inst_str,
                valid_str,
                cid_stage->pc[i]);
        int valid = (valid_str[0] == 'x') ? 0 : 1;
        int inst = atoi(inst_str);
        strcpy(cid_stage->insts[i], decode(inst, valid));
    }
    else if(strncmp(readbuffer,"o",1) == 0){
        ROB * crob = rob + ((history_num + 1) % NUM_HISTORY);
        if(strncmp(readbuffer+1,"p",1) == 0){
            sscanf(readbuffer, "op %d %d %d", &(crob->num_free), &(crob->head), &(crob->tail));
        }
        else{
            int i;
            sscanf(readbuffer, "o%d", &i);
            sscanf(readbuffer, "o%d %s %s %s %s %s %s %s %s %s %s %s",
                &i,
                crob->entries[i].dest_ARN,
                crob->entries[i].dest_PRN,
                crob->entries[i].reg_write,
                crob->entries[i].is_branch,
                crob->entries[i].PC,
                crob->entries[i].target,
                crob->entries[i].branch_direction,
                crob->entries[i].mispredicted,
                crob->entries[i].done,
                crob->entries[i].illegal,
                crob->entries[i].halt);
        }
    }
    else if(strncmp(readbuffer, "s", 1) == 0){
        RS * crs = rs + ((history_num + 1) % NUM_HISTORY);
        if(strncmp(readbuffer+1,"p",1) == 0){
            sscanf(readbuffer, "sp %d", &crs->num_free);
        }
        else{
            int i;
            char temp_str[7];
            sscanf(readbuffer, "s%d", &i);
            sscanf(readbuffer, "s%d %s %s %s %s %s %s %s %s",
                &i,
                temp_str,
                crs->contents[i].opa_ready,
                crs->contents[i].opa_value,
                crs->contents[i].opb_ready,
                crs->contents[i].opb_value,
                crs->contents[i].dest_prn,
                crs->contents[i].rob_idx,
                crs->contents[i].PC);
            if(temp_str[0] != 'x'){
                int alu = atoi(temp_str);
                strcpy(crs->contents[i].func, decode_alu(alu));
            }
            else{
                strcpy(crs->contents[i].func, "xxxxxx");
            }

        }
    }
    else if(strncmp(readbuffer, "r", 1) == 0){
        RAT * crat = rat + ((history_num + 1) % NUM_HISTORY);
        RAT * crrat = rrat + ((history_num + 1) % NUM_HISTORY);
        if(strncmp(readbuffer+1,"a",1) == 0){
            int i;
            sscanf(readbuffer, "ra%d", &i);
            sscanf(readbuffer, "ra%d %s %s", &i, crat->prn[i], crrat->prn[i]);
        }
        else{
            int i;
            sscanf(readbuffer, "r%d", &i);
            sscanf(readbuffer, "r%d %s %s %s %s", &i, crat->freelist[i], crat->validlist[i], crrat->freelist[i], crrat->validlist[i]);
        }
    }
    else if(strncmp(readbuffer, "p", 1) == 0){
        PRF * cprf = prf + ((history_num + 1) % NUM_HISTORY);
        int i;
        sscanf(readbuffer, "p%d", &i);
        sscanf(readbuffer, "p%d %s", &i, cprf->value[i]);
    }
    else if(strncmp(readbuffer,"c",1) == 0){
        sscanf(readbuffer, "c %d %d", &clock_edge, &present_cycle);
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
    char quit_flag = 0;
    
    char skip_cycles = 0;
    int cycle_dest = 0;

    pid_t pid = fork();
    switch(pid){
    case 0: // Child process
        close(PARENT_WRITE);
        close(PARENT_READ);
        fp = fdopen(CHILD_READ, "r");
        fp2 = fopen("program.out", "w");

        setup_gui();

        //              BIG block of mallocs
        // allocating memory for all the data structures
        if_stage    = (IF *) malloc(sizeof(IF) * NUM_HISTORY);
        id_stage    = (ID *) malloc(sizeof(ID) * NUM_HISTORY);
        rob         = (ROB *)malloc(sizeof(ROB) * NUM_HISTORY);
        rs          = (RS *) malloc(sizeof(RS) * NUM_HISTORY);
        rat         = (RAT *)malloc(sizeof(RAT) * NUM_HISTORY);
        rrat        = (RAT *)malloc(sizeof(RAT) * NUM_HISTORY);
        prf         = (PRF *)malloc(sizeof(PRF) * NUM_HISTORY);

        for(int i = 0; i < NUM_HISTORY; ++i){
            if_stage[i].insts   = (char **)malloc(sizeof(char *) * N_WAYS);
            if_stage[i].pc      = (char **)malloc(sizeof(char *) * N_WAYS);

            id_stage[i].insts   = (char **)malloc(sizeof(char *) * N_WAYS);
            id_stage[i].pc      = (char **)malloc(sizeof(char *) * N_WAYS);

            rob[i].entries      = (ROB_ENTRY *)malloc(sizeof(ROB_ENTRY) * ROB_SIZE);
            rs[i].contents      = (RS_LINE *)malloc(sizeof(RS_LINE) * RS_SIZE);

            rat[i].prn          = (char **)malloc(sizeof(char *) * 32);
            rat[i].freelist     = (char **)malloc(sizeof(char *) * PRF_SIZE);
            rat[i].validlist    = (char **)malloc(sizeof(char *) * PRF_SIZE);

            rrat[i].prn         = (char **)malloc(sizeof(char *) * 32);
            rrat[i].freelist    = (char **)malloc(sizeof(char *) * PRF_SIZE);
            rrat[i].validlist   = (char **)malloc(sizeof(char *) * PRF_SIZE);

            prf[i].value        = (char **)malloc(sizeof(char *) * PRF_SIZE);

            for(int j = 0; j < N_WAYS; ++j){
                if_stage[i].insts[j]    = (char *)(malloc(9));
                if_stage[i].pc[j]       = (char *)(malloc(9));

                id_stage[i].insts[j]    = (char *)(malloc(9));
                id_stage[i].pc[j]       = (char *)(malloc(9));
            }

            for(int j = 0; j < 32; ++j){
                rat[i].prn[j]           = (char *)malloc(3);
                rrat[i].prn[j]          = (char *)malloc(3);
            }
            for(int j = 0; j < PRF_SIZE; ++j){
                rat[i].freelist[j]      = (char *)malloc(2);
                rat[i].validlist[j]     = (char *)malloc(2);

                rrat[i].freelist[j]     = (char *)malloc(2);
                rrat[i].validlist[j]    = (char *)malloc(2);

                prf[i].value[j]         = (char *)malloc(9);
            }
        } // end of mallocs

        // clears out the readbuffer for safety reasons
        memset(readbuffer,'\0',sizeof(readbuffer));


        //                          MAIN LOOP
        // keeps looping until the user issues the 'quit' command
        // can be categorized into 3 parts:
        //      1. taking input from the testbench
        //          - this takes place by reading from fp, a file pointer that
        //              stdout is redirected to
        //          - keeps reading until it sees "break" from the testbench
        //          - will do nothing if testbench has already finished
        //      2. writing to the pipe CHILD_WRITE
        //          - waitforresponse listens to the read port of that same pipe
        //          - this means that the testbench, on every clock edge, waits
        //              for this write to happen, before moving on
        //      3. taking user input
        //          - refer to the comments there for available commands
        //          - continually takes input until either 'next' is issued while
        //              the most recent cycle is displayed or 'quit' is issued,
        while(!quit_flag){

            // part 1.
            // reads input from testbench until it encounters a "break"
            int ready = 0;
            while(!ready && !testbench_finished){
                fgets(readbuffer, sizeof(readbuffer), fp);
                ready = processinput();
                if(strcmp(readbuffer, "DONE") == 0){
                    testbench_finished = 1;
                }
            }

            curr_cycle = present_cycle;
            if(history_num == NUM_HISTORY - 1)
                time_wrapped = 1;
            history_num = present_cycle % NUM_HISTORY;

            // part 2.
            // writing the state of the program to a pipe
            // this will be picked up by waitforresponse()
            if(testbench_finished)
                write(CHILD_WRITE, "Z", 1);
            else{
                write(CHILD_WRITE, "n", 1);
                write(CHILD_WRITE, &mem_addr, 2);
            }

            // part 3.
            char take_input = 1; // set while we're taking user input, 0 if testbench needs to advance
            //if(skip_cycles && !testbench_finished && present_cycle < cycle_dest)
                //take_input = 0;

            //if(skip_cycles && cycle_dest < present_cycle)
                //history_num = cycle_dest % NUM_HISTORY;
            redraw();
            // loop redraws the screen each time the user types a command
            // invalid commands will prompt no action to be taken
            //
            // current commands include:
            //      n:          go ahead one next cycle
            //      b:          go back one cycle (up to a few cycles away from present_cycle)
            //      q:          quit
            //      o:          display the rob
            //      s:          display the rs
            //      r:          display the rat and rrat
            //      p:          display the prf
            //      <Return>:   redraw the screen
            do{
                input = getch();
                clear();

                switch(input){
                    // include cases for each user input
                    case 'n':
                        // if we're in sync with the testbench, wait for testbench to move ahead one cycle
                        if(present_cycle == curr_cycle && !testbench_finished){
                            take_input = 0;
                        }
                        // if we're not in sync with the testbench, move just the debugger ahead
                        else if(present_cycle != curr_cycle){
                            ++curr_cycle;
                            ++history_num;
                            if(history_num == NUM_HISTORY - 1)
                                time_wrapped = 1;
                            history_num %= NUM_HISTORY;
                        }
                        break;
                    case 'b':
                        if(history_num != (present_cycle % NUM_HISTORY) + 1){
                            if(history_num != 0){
                                --curr_cycle;
                                --history_num;
                            }
                            else if(time_wrapped){
                                --curr_cycle;
                                history_num = NUM_HISTORY - 1;
                            }
                        }
                        break;
                    case 'q':
                        take_input = 0;
                        quit_flag = 1;
                        break;
                    case 'o': mode = 'o'; break;
                    case 's': mode = 's'; break;
                    case 'r': mode = 'r'; break;
                    //case '\r':
                        //if(cycle_dest != 0)
                            //skip_cycles = 1;
                        //break;
                    //case 27:
                        //cycle_dest = 0;
                    //case 127:
                        //mvwaddstr(stdscr, ymax - 1, xmax / 2, "Pressed Backspace!");
                        //wrefresh(stdscr);
                        //cycle_dest /= 10;
                        //break;
                    //default:
                        //if(isdigit(input)){
                            //cycle_dest *= 10;
                            //cycle_dest += (int)input - 48;
                        //}
                }

                if(take_input)
                    redraw();
            } while(take_input);
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
    mem_start = read(PARENT_READ, &c, 1);
    mem_start = mem_start << 8 + read(PARENT_READ, &c, 1);
    return(mem_start);
}

extern "C" void flushproc(){
    char c = 0;
    read(PARENT_READ, &c, 1);
}

// YANKED from pipe_print.c
// takes an instruction in decimal and outputs the string representation
char* decode(int inst, int valid_inst){
  int opcode, funct3, funct7, funct12;
  char * str;
  
  if(!valid_inst)
    str = "-";
  else if(inst==NOOP_INST)
    str = "nop";
  else {
    opcode = inst & 0x7f;
    funct3 = (inst>>12) & 0x7;
    funct7 = inst>>25;
    funct12 = inst>>20; // for system instructions
    // See the RV32I base instruction set table
    switch (opcode) {
    case 0x37: str = "lui"; break;
    case 0x17: str = "auipc"; break;
    case 0x6f: str = "jal"; break;
    case 0x67: str = "jalr"; break;
    case 0x63: // branch
      switch (funct3) {
      case 0b000: str = "beq"; break;
      case 0b001: str = "bne"; break;
      case 0b100: str = "blt"; break;
      case 0b101: str = "bge"; break;
      case 0b110: str = "bltu"; break;
      case 0b111: str = "bgeu"; break;
      default: str = "invalid"; break;
      }
      break;
    case 0x03: // load
      switch (funct3) {
      case 0b000: str = "lb"; break;
      case 0b001: str = "lh"; break;
      case 0b010: str = "lw"; break;
      case 0b100: str = "lbu"; break;
      case 0b101: str = "lhu"; break;
      default: str = "invalid"; break;
      }
      break;
    case 0x23: // store
      switch (funct3) {
      case 0b000: str = "sb"; break;
      case 0b001: str = "sh"; break;
      case 0b010: str = "sw"; break;
      default: str = "invalid"; break;
      }
      break;
    case 0x13: // immediate
      switch (funct3) {
      case 0b000: str = "addi"; break;
      case 0b010: str = "slti"; break;
      case 0b011: str = "sltiu"; break;
      case 0b100: str = "xori"; break;
      case 0b110: str = "ori"; break;
      case 0b111: str = "andi"; break;
      case 0b001:
        if (funct7 == 0x00) str = "slli";
        else str = "invalid";
        break;
      case 0b101:
        if (funct7 == 0x00) str = "srli";
        else if (funct7 == 0x20) str = "srai";
        else str = "invalid";
        break;
      }
      break;
    case 0x33: // arithmetic
      switch (funct7 << 4 | funct3) {
      case 0x000: str = "add"; break;
      case 0x200: str = "sub"; break;
      case 0x001: str = "sll"; break;
      case 0x002: str = "slt"; break;
      case 0x003: str = "sltu"; break;
      case 0x004: str = "xor"; break;
      case 0x005: str = "srl"; break;
      case 0x205: str = "sra"; break;
      case 0x006: str = "or"; break;
      case 0x007: str = "and"; break;
      // M extension
      case 0x010: str = "mul"; break;
      case 0x011: str = "mulh"; break;
      case 0x012: str = "mulhsu"; break;
      case 0x013: str = "mulhu"; break;
      case 0x014: str = "div"; break;  // unimplemented
      case 0x015: str = "divu"; break; // unimplemented
      case 0x016: str = "rem"; break;  // unimplemented
      case 0x017: str = "remu"; break; // unimplemented
      default: str = "invalid"; break;
      }
      break;
    case 0x0f: str = "fence"; break; // unimplemented, imprecise 
    case 0x73:
      switch (funct3) {
      case 0b000:
        // unimplemented, somewhat inaccurate :(
        switch (funct12) {
        case 0x000: str = "ecall"; break;
        case 0x001: str = "ebreak"; break;
        case 0x105: str = "wfi"; break; // we just mostly care about this
        default: str = "system"; break;
        }
        break;
      case 0b001: str = "csrrw"; break;
      case 0b010: str = "csrrs"; break;
      case 0b011: str = "csrrc"; break;
      case 0b101: str = "csrrwi"; break;
      case 0b110: str = "csrrsi"; break;
      case 0b111: str = "csrrci"; break;
      default: str = "invalid"; break;
      }
      break;
    default: str = "invalid"; break;
    }
  }
  return str;
}

char * decode_alu(int alu){
    char * str = "";
    switch(alu){
    case 0: str = "ADD"; break;
    case 1: str = "SUB"; break;
    case 2: str = "SLT"; break;
    case 3: str = "SLTU"; break;
    case 4: str = "AND"; break;
    case 5: str = "OR"; break;
    case 6: str = "XOR"; break;
    case 7: str = "SLL"; break;
    case 8: str = "SRL"; break;
    case 9: str = "SRA"; break;
    case 10: str = "MUL"; break;
    case 11: str = "MULH"; break;
    case 12: str = "MULHSU"; break;
    case 13: str = "MULHU"; break;
    case 14: str = "DIV"; break;
    case 15: str = "DIVU"; break;
    case 16: str = "REM"; break;
    case 17: str = "REMU"; break;
    }
    return str;
}
