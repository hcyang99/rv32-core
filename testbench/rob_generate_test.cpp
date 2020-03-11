
#include "DirectC.h"
#include "mt19937-64.c"

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <inttypes.h>

#define NUM_TESTS 1000


// test case legend:
//      for 0 to n_ways:
//          CDB_ROB_idx[clog2(ROB_size)]
//          CDB_valid
//          
//          branch direction resolver
//              direction
//              target[XLEN]
//              ROB_idx[clog2(ROB_size)]
//              valid
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

typedef struct rob_en{
    uint64_t destARN;
    uint64_t destPRN;
    uint64_t reg_write;
    uint64_t is_branch;
    uint64_t PC;
    uint64_t target;
    uint64_t branch_direction;
    uint64_t target_valid;
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

    uint64_t CDB_ROB_idx[16];
    uint64_t CDB_valid[16];

    // branch direction
    uint64_t direction[16];
    uint64_t target[16];
    uint64_t ROB_idx[16];
    uint64_t branch_valid[16];

    // inst
    uint64_t dest_ARN[16];
    uint64_t dest_PRN[16];
    uint64_t reg_write[16];
    uint64_t is_branch[16];
    uint64_t valid[16];
    uint64_t PC[16];
    uint64_t inst_target[16];
    uint64_t target_valid[16];
    uint64_t prediction[16];
   
}rob_inputs;

int N_WAYS;
int ROB_SIZE;
int PRF_SIZE;
int NUM_REGS;
int XLEN;

void generate_correct(rob_struct * , rob_inputs * , FILE *);

extern "C" void generate_test(int n_ways_in, int rob_size_in, int prf_size_in, int num_regs_in, int xlen_in){
    // assume we never have more than 16 ways
    FILE *fptr = fopen("rob_test.mem", "w");
    FILE *cor_fptr = fopen("rob_test.correct", "w");

    N_WAYS = n_ways_in;
    ROB_SIZE = rob_size_in;
    PRF_SIZE = prf_size_in;
    NUM_REGS = num_regs_in;
    XLEN = xlen_in;

    rob_entry * arr = malloc(sizeof(rob_entry) * ROB_SIZE);
    rob_struct rob{arr, 0, 0, ROB_SIZE};

    rob_inputs inputs;

    /*int n_ways = 3;
    int rob_size = 16;
    int prf_size = 64;
    int num_regs = 48;
    unsigned int xlen = 63;*/

    // dumb variable DUMB
    uint64_t xlen_mod = 1;
    xlen_mod <<= XLEN;
    xlen_mod --;
    if(xlen == 64) xlen_mod = -1;

    for(int i = 0; i < NUM_TESTS; ++i){
        for(int j = 0; j < N_WAYS; ++j){
            inputs.CDB_ROB_idx[j] = ROB_SIZE == rob.num_free ? 0 : ((rand() % (ROB_SIZE - rob.num_free)) + head) % ROB_SIZE;
            inputs.CDB_valid[j] = ROB_SIZE == rob.num_free ? 0 : rand() % 2;

            inputs.direction[j] = rand() % 2;
            inputs.target[j] = genrand64_int64() % xlen_mod;
            inputs.ROB_idx[j] = ROB_SIZE == rob.num_free ? 0 : ((rand() % (ROB_SIZE - rob.num_free)) + head) % ROB_SIZE;
            inputs.branch_valid[j] = ROB_SIZE == rob.num_free ? 0 : rand() % 2;

            inputs.dest_ARN[j] = rand() % NUM_REGS;
            inputs.dest_PRN[j] = rand() % PRF_SIZE;
            inputs.reg_write[j] = rand() % 2;
            inputs.is_branch[j] = rand() % 2;
            inputs.valid[j] = (j < rob.num_free) ? 1 : 0;
            inputs.PC[j] = genrand64_int64() % xlen_mod;
            inputs.inst_target[j] = genrand64_int64() % xlen_mod;
            inputs.target_valid[j] = rand() % 2;
            inputs.prediction[j] = rand() % 2;


            fprintf(fptr, "%016x\n", inputs.CDB_ROB_idx[j]);
            fprintf(fptr, "%016x\n", inputs.CDB_valid[j]);

            fprintf(fptr, "%016x\n", inputs.direction[j]);
            fprintf(fptr, "%016" PRIx64 "\n", inputs.target[j]);
            fprintf(fptr, "%016x\n", inputs.ROB_idx[j]);
            fprintf(fptr, "%016x\n", inputs.branch_valid[j]);

            fprintf(fptr, "%016x\n", inputs.dest_ARN[j]);
            fprintf(fptr, "%016x\n", inputs.dest_PRN[j]);
            fprintf(fptr, "%016x\n", inputs.reg_write[j]);
            fprintf(fptr, "%016x\n", inputs.is_branch[j]);
            fprintf(fptr, "%016x\n", inputs.valid[j]);
            fprintf(fptr, "%016" PRIx64 "\n", inputs.PC[j]);
            fprintf(fptr, "%016" PRIx64 "\n", inputs.inst_target[j]);
            fprintf(fptr, "%016x\n", inputs.target_valid[j]);
            fprintf(fptr, "%016x\n", inputs.prediction[j]);
        }
        // TODO: call generate correct
        generate_correct(&rob, &inputs, cor_fptr);
    }
    fclose(fptr);
    fclose(cor_fptr);
}




// output legend:
//      tail_ptr
//      from 0 to n_ways
//          inst
//              dest_ARN[clog2(NUM_REGS)]
//              dest_PRN[clog2(PRF_size)]
//              valid
//      num_free
void generate_correct(rob_struct * rob, rob_inputs * inputs, FILE * fptr){
    // dispatch logic
    for(int i = 0; i < N_WAYS; ++i){
        if(inputs->valid[i]){
            rob_entry new_entry;
            new_entry.destARN = inputs->destARN[i];
            new_entry.destPRN = inputs->destPRN[i];
            new_entry.reg_write = inputs->reg_write[i];
            new_entry.is_branch = inputs->is_branch[i];
            new_entry.PC = inputs->PC[i];
            new_entry.target = inputs->target[i];
            new_entry.branch_direction = inputs->prediction[i];
            new_entry.target_valid = inputs->target_valid[i];
            new_entry.mispredicted = 0;
            new_entry.done = 0;


            rob->entries[rob->tail_ptr] = new_entry;
            rob->tail_ptr = rob->tail_ptr == ROB_SIZE - 1 ? 0 : rob->tail_ptr + 1;
            --rob->num_free;
        }
       
    }
    
    fprintf("%016x\n", rob->tail_ptr);


    // CDB fun logic
    for(int i = 0; i < N_WAYS; ++i){
        if(inputs->CDB_valid[i]){
            
        }
    }


    // commit logic
    for(int i = 0; i < N_WAYS; ++i){
        fprintf("%016x\n", rob->entries[head].destARN);
        fprintf("%016x\n", rob->entries[head].destPRN);
        fprintf("%016x\n", rob->entries[head].reg_write & rob->entries[head].done);
        if(rob->entries[head].done){
            if(rob->entries[head].mispredicted){
                rob->num_free = ROB_SIZE;
                rob->tail_ptr = rob->head_ptr;
                rob->entries[head].done = 0;
            }
            else{
                ++rob->num_free;
                rob->head_ptr = rob->head_ptr == ROB_SIZE - 1 ? 0 : rob->head_ptr + 1;
            }
        }
    }
    fprintf("%016x\n", rob->num_free);


}