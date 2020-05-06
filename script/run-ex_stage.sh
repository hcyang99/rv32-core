#!/bin/bash 


make mult_stage.vg SOURCES=verilog/mult.sv DESIGN_NAME=mult_stage
make mult.vg SOURCES=verilog/mult.sv DESIGN_NAME=mult
make alu.vg SOURCES=verilog/ex_stage.sv DESIGN_NAME=alu
make brcond.vg SOURCES=verilog/ex_stage.sv DESIGN_NAME=brcond
make ex_stage.vg SOURCES=verilog/ex_stage.sv DESIGN_NAME=ex_stage