
#include "DirectC.h"
#include "mt19937-64.c"
// TODO: credit the authors of the 64-bit Mersene Twister implementation
// (i mean, it's in that c file, aint that enough?)

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>

// global variables
int N_WAYS;
int ROB_SIZE;
int PRF_SIZE;
int NUM_REGS;
int XLEN;
int NUM_TESTS;

// struct definitions
typedef struct rob_en{
    uint64_t dest_ARN;
    uint64_t dest_PRN;
    uint64_t reg_write;
    uint64_t is_branch;
    uint64_t PC;
    uint64_t target;
    uint64_t branch_direction;
    uint64_t mispredicted;
    // TODO: include load and store stuff
    uint64_t done;
}rob_entry;

typedef struct rob_struc{
    rob_entry * entries;
    uint64_t head_ptr;
    uint64_t tail_ptr;
    uint64_t num_free;
}rob_struct;

typedef struct inp{

    // there's more data in the CDB itself, but this is all that we care about
    uint64_t CDB_ROB_idx;
    uint64_t CDB_valid;

    // branch data
    uint64_t CDB_direction;
    uint64_t CDB_target;

    // inst
    uint64_t dest_ARN;
    uint64_t dest_PRN;
    uint64_t reg_write;
    uint64_t is_branch;
    uint64_t valid;
    uint64_t PC;
    uint64_t inst_target;
    uint64_t prediction;
   
}rob_inputs;

// function declarations
void generate_correct(rob_struct * , rob_inputs * , FILE *);

// test case legend:
//      for 0 to n_ways:
//          CDB_ROB_idx[clog2(ROB_size)]
//          CDB_valid
//          
//          CDB_direction
//          CDB_target[XLEN]
//          
//          inst
//              dest_ARN[clog2(NUM_REGS)]
//              dest_PRN[clog2(PRF_size)]
//              reg_write
//              is_branch
//              valid
//              PC[XLEN]
//              inst_target[XLEN]
//              prediction

// "main" function that gets called from the testbench
// generates a test file that will serve as input to the rob verilog module
// simultaneously makes calls to generate_correct to also generate the correct output
extern "C" void generate_test(int n_ways_in, int rob_size_in, int prf_size_in, int num_regs_in, int xlen_in, int num_tests_in){
    // "rob_test.mem" is the test file, and "rob_test.correct" is the correct output
    FILE *fptr = fopen("rob_test.mem", "w");
    FILE *cor_fptr = fopen("rob_test.correct", "w");

    // setting the global variables for use in other functions
    N_WAYS = n_ways_in;
    ROB_SIZE = rob_size_in;
    PRF_SIZE = prf_size_in;
    NUM_REGS = num_regs_in;
    XLEN = xlen_in;
    NUM_TESTS = num_tests_in;

    // initializing the structs based on input
    rob_entry * arr = (rob_entry *)malloc(sizeof(rob_entry) * ROB_SIZE);
    rob_struct rob{arr, 0, 0, ROB_SIZE};

    rob_inputs * inputs = (rob_inputs *)malloc(sizeof(rob_inputs) * N_WAYS);

    // dumb variable DUMB
    // for some reason a literal being shifted by a variable breaks...
    // xlen_mod is just a bit array of all 1's, with length XLEN
    uint64_t xlen_mod = 1;
    xlen_mod <<= XLEN;
    xlen_mod --;
    if(XLEN == 64) xlen_mod = -1;

    // a small array we use to make sure that we don't broadcast to the same rob index
    // from more than one CDB's in the same cycle
    int * taken_robs = (int*)malloc(sizeof(int) * N_WAYS);

    // here's the main test case generation
    // the logic is fairly simple:
    //      generate random inputs to everything (including CDB) except for the following:
    //          - CDB_ROB_idx:      must be a valid, in-use rob entry
    //          - CDB_ROB_valid:    usually random, except for when the rob is empty
    //              - if current idx is already used, set to 0
    //          - valid:            usually 1, except for when the rob is full
    //      these exceptions ensure that the rob isn't trying to take instructions if it's full,
    //      and that the rob is getting valid input from the CDB
    for(int i = 0; i < NUM_TESTS; ++i){
        for(int j = 0; j < N_WAYS; ++j){
            // rand % num_entries, then adjusted to be in the correct range
            inputs[j].CDB_ROB_idx   = ROB_SIZE == rob.num_free ? 0 : ((rand() % (ROB_SIZE - rob.num_free)) + rob.head_ptr) % ROB_SIZE;

            // loops through taken_robs, set rob_taken to false (and thus setting valid to false)
            // if we notice the same rob index in that list
            // 
            // this will make sure that we're not broadcasting to the same rob entry from two
            // different CDB's in the same cycle
            int rob_taken = 0;
            for(int k = 0; k < j; ++k){
                if(taken_robs[k] == inputs[j].CDB_ROB_idx) rob_taken = 1;
            }
            inputs[j].CDB_valid     = ROB_SIZE == rob.num_free  ? 0 :
                                      rob_taken                 ? 0 : rand() % 2;

            // taken_robs is full of either a rob index being broadcasted to, or -1
            taken_robs[j]           = inputs[j].CDB_valid       ? inputs[j].CDB_ROB_idx : -1;

            inputs[j].CDB_direction = rand() % 2;
            inputs[j].CDB_target    = genrand64_int64() % xlen_mod;

            inputs[j].dest_ARN      = rand() % NUM_REGS;
            inputs[j].dest_PRN      = rand() % PRF_SIZE;
            inputs[j].reg_write     = rand() % 2;
            inputs[j].is_branch     = rand() % 2;
            inputs[j].valid         = (j < rob.num_free) ? 1 : 0;
            inputs[j].PC            = genrand64_int64() % xlen_mod;
            inputs[j].inst_target   = genrand64_int64() % xlen_mod;
            inputs[j].prediction    = rand() % 2;


            fprintf(fptr, "%016x\n",            inputs[j].CDB_ROB_idx);
            fprintf(fptr, "%016x\n",            inputs[j].CDB_valid);

            fprintf(fptr, "%016x\n",            inputs[j].CDB_direction);
            fprintf(fptr, "%016" PRIx64 "\n",   inputs[j].CDB_target);

            fprintf(fptr, "%016x\n",            inputs[j].dest_ARN);
            fprintf(fptr, "%016x\n",            inputs[j].dest_PRN);
            fprintf(fptr, "%016x\n",            inputs[j].reg_write);
            fprintf(fptr, "%016x\n",            inputs[j].is_branch);
            fprintf(fptr, "%016x\n",            inputs[j].valid);
            fprintf(fptr, "%016" PRIx64 "\n",   inputs[j].PC);
            fprintf(fptr, "%016" PRIx64 "\n",   inputs[j].inst_target);
            fprintf(fptr, "%016x\n",            inputs[j].prediction);
        }
        generate_correct(&rob, inputs, cor_fptr);
    }
    // closing the file pointers to avoid leaks
    fclose(fptr);
    fclose(cor_fptr);

    // free the dynamically allocated stuff
    free(arr);
    free(inputs);
    free(taken_robs);
}




// output legend:
//      tail_ptr
//      from 0 UP TO n_ways (only print when instructions commit)
//          inst
//              dest_ARN[clog2(NUM_REGS)]
//              dest_PRN[clog2(PRF_size)]
//              valid
//      num_free

void generate_correct(rob_struct * rob, rob_inputs * inputs, FILE * fptr){
    // dispatch logic
    for(int i = 0; i < N_WAYS; ++i){
        if(inputs[i].valid){
            // largely just copy from input, save for mispredicted and done bits
            rob_entry new_entry;
            new_entry.dest_ARN = inputs[i].dest_ARN;
            new_entry.dest_PRN = inputs[i].dest_PRN;
            new_entry.reg_write = inputs[i].reg_write;
            new_entry.is_branch = inputs[i].is_branch;
            new_entry.PC = inputs[i].PC;
            new_entry.target = inputs[i].inst_target;
            new_entry.branch_direction = inputs[i].prediction;
            new_entry.mispredicted = 0;
            new_entry.done = 0;


            // add the new_entry, which moves the tail, changes num_free, and of course
            // the contents of the rob
            rob->entries[rob->tail_ptr] = new_entry;
            rob->tail_ptr = rob->tail_ptr == ROB_SIZE - 1 ? 0 : rob->tail_ptr + 1;
            --rob->num_free;
        }
       
    }
    
    fprintf(fptr, "%016x\n", rob->tail_ptr);


    // CDB fun logic
    for(int i = 0; i < N_WAYS; ++i){
        if(inputs[i].CDB_valid){
            rob_entry * rob_i = &rob->entries[inputs[i].CDB_ROB_idx];
            rob_i->branch_direction = inputs[i].CDB_direction;
            rob_i->target = inputs[i].CDB_target;
            rob_i->done = 1;
        }
    }


    // commit logic
    for(int i = 0; i < N_WAYS; ++i){
        if(rob->entries[rob->head_ptr].done){
            if(rob->entries[rob->head_ptr].mispredicted){
                rob->num_free = ROB_SIZE;
                rob->tail_ptr = rob->head_ptr;
                rob->entries[rob->head_ptr].done = 0;
            }
            else{
                ++rob->num_free;
                rob->head_ptr = rob->head_ptr == ROB_SIZE - 1 ? 0 : rob->head_ptr + 1;
            }
        }
        else{
            fprintf(fptr, "%016x\n", rob->entries[rob->head_ptr].dest_ARN);
            fprintf(fptr, "%016x\n", rob->entries[rob->head_ptr].dest_PRN);
            fprintf(fptr, "%016x\n", rob->entries[rob->head_ptr].reg_write & rob->entries[rob->head_ptr].done);
        }
    }
    fprintf(fptr, "%016x\n", rob->num_free);


}