/*
 *  pipe_print.c - Print instructions as they pass through the verisimple
 *                 pipeline.  Must compile with the '+vc' vcs flag.
 *
 *  Doug MacKay <dmackay@umich.edu> Fall 2003
 *
 *  Updated for RISC-V by C Jones, Winter 2019
 */

#include <stdio.h>
#include "DirectC.h"

#define NOOP_INST 0x00000013

static FILE* ppfile = NULL;

char* decode(int inst, int valid_inst){
  int opcode, funct3, funct7, funct12;
  char* str;
  
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

void print_header(char* str)
{
  if (ppfile == NULL)
    ppfile = fopen("processor.out", "w");

  fprintf(ppfile, "%s", str);
}

void print_cycles(int time_in, int cycle_count)
{
  /* we'll enforce the printing of a header */
  if (ppfile != NULL)
    fprintf(ppfile, "\n%10d %5d:", time_in, cycle_count);
}


void print_stage(char* div, int inst, int valid_inst)
{
  char *str = decode(inst, valid_inst);

  if (ppfile != NULL)
    fprintf(ppfile, "%s %2d  %-8s", div, valid_inst, str);
}

void print_valids(int opa_valid, int opb_valid)
{
  if(ppfile != NULL){
    fprintf(ppfile, "% 2d %2d", opa_valid, opb_valid);
  }
}

void print_opaopb(int opa_valid, int opb_valid, int rs1_value, int rs2_value)
{
  if (ppfile != NULL)
    fprintf(ppfile,"%2d %12x %2d %12x", opa_valid, rs1_value, opb_valid, rs2_value);
}


void print_rs(char* div, int inst, int valid_inst, int num_free, int load_in_hub, int is_free_hub, int ready_hub)
{
  char* str = decode(inst, valid_inst);

  if (ppfile != NULL)
    fprintf(ppfile, "%s%8s %4d %04x %04x %04x", div, str, num_free, load_in_hub, is_free_hub, ready_hub);

}

void print_rob(char* div, int except, int direction, int PC, int num_free, int dest_ARN_out, int valid_out)
{
  
  if (ppfile != NULL)
    fprintf(ppfile, "%s%4d  %08x%4d %2d   %-4d %2d", div, direction, PC, num_free, except, dest_ARN_out, valid_out);

}

void print_ex_out(char* div, int alu_result, int valid, int alu_occupied, int brand_results, int NPC){
  if(ppfile != NULL)
    fprintf(ppfile, "%s%3d %8x %2d %2d %2x   ", div, valid, alu_result, alu_occupied, brand_results,NPC);
}

void print_close()
{
  fprintf(ppfile, "\n");
  fclose(ppfile);
  ppfile = NULL;
}

void print_reg(int wb_reg_wr_data_out_hi, int wb_reg_wr_data_out_lo,
                  int wb_reg_wr_idx_out, int wb_reg_wr_en_out)
{
  if (ppfile == NULL)
    return;

  if(wb_reg_wr_en_out)
    if((wb_reg_wr_data_out_hi==0)||
       ((wb_reg_wr_data_out_hi==-1)&&(wb_reg_wr_data_out_lo<0)))
      fprintf(ppfile, "r%d=%d  ",wb_reg_wr_idx_out,wb_reg_wr_data_out_lo);
    else 
      fprintf(ppfile, "r%d=0x%x%x  ",wb_reg_wr_idx_out,
              wb_reg_wr_data_out_hi,wb_reg_wr_data_out_lo);

}

void print_membus(int proc2mem_command, int mem2proc_response,
                  int proc2mem_addr_hi, int proc2mem_addr_lo,
                  int proc2mem_data_hi, int proc2mem_data_lo)
{
  if (ppfile == NULL)
    return;

  switch(proc2mem_command)
  {
    case 1: fprintf(ppfile, "BUS_LOAD  MEM["); break;
    case 2: fprintf(ppfile, "BUS_STORE MEM["); break;
    default: return; break;
  }
  
  if((proc2mem_addr_hi==0)||
     ((proc2mem_addr_hi==-1)&&(proc2mem_addr_lo<0)))
    fprintf(ppfile, "%d",proc2mem_addr_lo);
  else
    fprintf(ppfile, "0x%x%x",proc2mem_addr_hi,proc2mem_addr_lo);
  if(proc2mem_command==1)
  {
    fprintf(ppfile, "]");
  } else {
    fprintf(ppfile, "] = ");
    if((proc2mem_data_hi==0)||
       ((proc2mem_data_hi==-1)&&(proc2mem_data_lo<0)))
      fprintf(ppfile, "%d",proc2mem_data_lo);
    else
      fprintf(ppfile, "0x%x%x",proc2mem_data_hi,proc2mem_data_lo);
  }
  if(mem2proc_response) {
    fprintf(ppfile, " accepted %d",mem2proc_response);
  } else {
    fprintf(ppfile, " rejected");
  }
}
