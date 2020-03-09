
//#include "DirectC.h"
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


int main(/*int n_ways, int rob_size, int prf_size, int num_regs, int xlen*/){
    // assume we never have more than 16 ways
    uint64_t CDB_ROB_idx[16];
    uint64_t CDB_valid[16];

    // branch direction
    uint64_t direction[16];
    uint64_t target[16];
    uint64_t ROB_idx[16];

    // inst
    uint64_t dest_ARN[16];
    uint64_t dest_PRN[16];
    uint64_t reg_write[16];
    uint64_t is_branch[16];
    uint64_t valid[16];
    uint64_t PC[16];
    uint64_t inst_target[16];
    uint64_t prediction[16];

    FILE *fptr = fopen("rob_test.mem", "w");

    int n_ways = 3;
    int rob_size = 16;
    int prf_size = 64;
    int num_regs = 48;
    int xlen = 63;

    // dumb variable DUMB
    uint64_t xlen_mod = 1;
    xlen_mod = xlen_mod << xlen;

    printf("%u\n", xlen);
    printf("%" PRIi64 "\n", xlen_mod);

    for(int i = 0; i < NUM_TESTS; ++i){
        for(int j = 0; j < n_ways; ++j){
            CDB_ROB_idx[j] = rand() % rob_size;
            CDB_valid[j] = 1 % 2;

            direction[j] = rand() % 2;
            target[j] = rand() % xlen_mod;
            ROB_idx[j] = rand() % rob_size;

            dest_ARN[j] = rand() % num_regs;
            dest_PRN[j] = rand() % prf_size;
            reg_write[j] = rand() % 2;
            is_branch[j] = rand() % 2;
            valid[j] = rand() % 2;
            PC[j] = rand() % xlen_mod;
            inst_target[j] = rand() % xlen_mod;
            prediction[j] = rand() % 2;

            fprintf(fptr, "%x\n", CDB_ROB_idx[j]);
            fprintf(fptr, "%u\n\n", CDB_valid[j]);

            fprintf(fptr, "%x\n", direction[j]);
            fprintf(fptr, "%x\n", target[j]);
            fprintf(fptr, "%x\n\n", ROB_idx[j]);

            fprintf(fptr, "%x\n", dest_ARN[j]);
            fprintf(fptr, "%x\n", dest_PRN[j]);
            fprintf(fptr, "%x\n", reg_write[j]);
            fprintf(fptr, "%x\n", is_branch[j]);
            fprintf(fptr, "%x\n", valid[j]);
            fprintf(fptr, "%x\n", PC[j]);
            fprintf(fptr, "%x\n", inst_target[j]);
            fprintf(fptr, "%x\n\n\n\n", prediction[j]);
        }
    }
}