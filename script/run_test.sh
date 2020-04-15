#!/bin/bash
for file in test_progs/*.s; do
filename=$(echo $file | cut -d '/' -f2 | cut -d'.' -f1)
echo "Running $filename"
# build assembly
make assembly SOURCE=$file > /dev/null
# echo "Running $filename"
# simulate assembly
make > /dev/null
# echo "Saving $filename output"
# save program.out and writeback.out
mv program.out ./outputs/$filename.program.out
mv writeback.out ./outputs/$filename.writeback.out
done

for file in test_progs/*.c; do
filename=$(echo $file | cut -d '/' -f2 | cut -d'.' -f1)
echo "Running $filename"
# build program
make program SOURCE=$file > /dev/null
# echo "Running $filename"
# simulate assembly
make > /dev/null
# echo "Saving $filename output"
# save program.out and writeback.out
mv program.out ./outputs/$filename.program.out
mv writeback.out ./outputs/$filename.writeback.out
done

fail=0
for file in outputs/*.writeback.out; do
filename=$(echo $file | cut -d '/' -f2 | cut -d'.' -f1)
# # diff the writebacks
# diff -q $file "models/$filename.writeback.out" > /dev/null
# if [ $? -ne 0 ] 
# then
#     # failed if different
#     echo "$filename failed!!!"
#     fail=1
#     continue
# fi
# diff lines starting with "@@@" only
cat "models/$filename.writeback.out" | grep "REG" > model.temp
cat "outputs/$filename.writeback.out" | grep "REG" > out.temp
diff -q out.temp model.temp > /dev/null
if [ $? -ne 0 ] 
then
    echo "$filename failed!!!"
    fail=1
fi
rm out.temp model.temp
done

if [ $fail -eq 0 ]
then
    echo "All test passed."
fi