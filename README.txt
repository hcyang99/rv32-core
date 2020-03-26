This is a repo of milestone #1.
We have implemented the whole RS module in rs.sv and fully debugged the RS_Line module in RS_Line.sv.
The testbench for RS_Line module is rs_test.sv.

command to run simulation:
make
command to run synthesis:
make syn
command to run code coverage analysis:
make coverage

We are doing an N-way superscaler and set N = 3 currently. In the testbench, we randomized the valid bits for opa 
and opb and randomized both the valid bits and data in the 3 CDB ports. The line coverage for the RS_Line module 
has been up to 100. 