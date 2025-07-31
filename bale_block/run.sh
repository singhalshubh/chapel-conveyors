echo "1million"
echo -e "\n"
srun -N 1 -n 64 ./ig_block -n 1000000 -T 100000000
srun -N 2 -n 128 ./ig_block -n 1000000 -T 100000000
srun -N 4 -n 256 ./ig_block -n 1000000 -T 100000000
srun -N 8 -n 512 ./ig_block -n 1000000 -T 100000000
srun -N 16 -n 1024 ./ig_block -n 1000000 -T 100000000
srun -N 32 -n 2048 ./ig_block -n 1000000 -T 100000000
srun -N 64 -n 4096 ./ig_block -n 1000000 -T 100000000
srun -N 128 -n 8192 ./ig_block -n 1000000 -T 100000000
srun -N 256 -n 16384 ./ig_block -n 1000000 -T 100000000
echo -e "\n"

echo "10million"
echo -e "\n"
srun -N 1 -n 64 ./ig_block -n 10000000 -T 100000000
srun -N 2 -n 128 ./ig_block -n 10000000 -T 100000000
srun -N 4 -n 256 ./ig_block -n 10000000 -T 100000000
srun -N 8 -n 512 ./ig_block -n 10000000 -T 100000000
srun -N 16 -n 1024 ./ig_block -n 10000000 -T 100000000
srun -N 32 -n 2048 ./ig_block -n 10000000 -T 100000000
srun -N 64 -n 4096 ./ig_block -n 10000000 -T 100000000
srun -N 128 -n 8192 ./ig_block -n 10000000 -T 100000000
srun -N 256 -n 16384 ./ig_block -n 10000000 -T 100000000
echo -e "\n"

echo "100million"
echo -e "\n"
srun -N 1 -n 64 ./ig_block -n 100000000 -T 100000000
srun -N 2 -n 128 ./ig_block -n 100000000 -T 100000000
srun -N 4 -n 256 ./ig_block -n 100000000 -T 100000000
srun -N 8 -n 512 ./ig_block -n 100000000 -T 100000000
srun -N 16 -n 1024 ./ig_block -n 100000000 -T 100000000
srun -N 32 -n 2048 ./ig_block -n 100000000 -T 100000000
srun -N 64 -n 4096 ./ig_block -n 100000000 -T 100000000
srun -N 128 -n 8192 ./ig_block -n 100000000 -T 100000000
srun -N 256 -n 16384 ./ig_block -n 100000000 -T 100000000
echo -e "\n"