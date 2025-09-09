#!/bin/sh
# https://www.mgaillard.fr/2022/08/27/benchmark-with-hpl.html

sudo apt install -y build-essential hwloc libhwloc-dev libevent-dev gfortran wget mc git btop zlib1g zlib1g-dev libz-dev

cd ~
git clone https://github.com/OpenMathLib/OpenBLAS.git
cd OpenBLAS

make TARGET=SANDYBRIDGE NO_AVX2=1 USE_OPENMP=1 NUM_THREADS=8
make PREFIX=$HOME/opt/OpenBLAS install

cd ~
wget https://download.open-mpi.org/release/open-mpi/v5.0/openmpi-5.0.8.tar.gz
tar xf openmpi-5.0.8.tar.gz
cd openmpi-5.0.8
CFLAGS="-O3 -march=corei7-avx -mtune=sandybridge -funroll-loops -floop-optimize" ./configure --prefix=$HOME/opt/OpenMPI
make -j $(nproc)
make install

export MPI_HOME=$HOME/opt/OpenMPI
export PATH=$PATH:$MPI_HOME/bin
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$MPI_HOME/lib:$HOME/opt/OpenBLAS/lib

cd ~
wget https://netlib.sandia.gov/benchmark/hpl/hpl-2.3.tar.gz
gunzip hpl-2.3.tar.gz
tar xvf hpl-2.3.tar
mv hpl-2.3 ~/hpl

sudo ln -s /usr/bin/gfortran /usr/bin/g77

cd ~/hpl

# Создание Makefile для i7-3770
cat > Make.linux << 'EOF'
SHELL        = /bin/sh
CD           = cd
CP           = cp
LN_S         = ln -s
MKDIR        = mkdir
RM           = /bin/rm -f
TOUCH        = touch
ARCH         = linux
TOPdir       = $(HOME)/hpl
INCdir       = $(TOPdir)/include
BINdir       = $(TOPdir)/bin/$(ARCH)
LIBdir       = $(TOPdir)/lib/$(ARCH)
HPLlib       = $(LIBdir)/libhpl.a 
MPdir        = $(HOME)/opt/OpenMPI
MPinc        = -I$(MPdir)/include
MPlib        = -L$(MPdir)/lib -lmpi
LAdir        = $(HOME)/opt/OpenBLAS
LAinc        = -I$(LAdir)/include
LAlib        = -L$(LAdir)/lib -lopenblas
F2CDEFS      =
HPL_INCLUDES = -I$(INCdir) -I$(INCdir)/$(ARCH) $(LAinc) $(MPinc)
HPL_LIBS     = $(HPLlib) $(LAlib) $(MPlib) -lm -lz
HPL_OPTS     = -DHPL_CALL_CBLAS
HPL_DEFS     = $(F2CDEFS) $(HPL_OPTS) $(HPL_INCLUDES)
CC           = $(MPdir)/bin/mpicc
CCNOOPT      = $(HPL_DEFS)
# ОПТИМИЗАЦИЯ: Улучшенные флаги компиляции
CCFLAGS      = $(HPL_DEFS) -fomit-frame-pointer -O3 -march=corei7-avx -mtune=sandybridge -funroll-loops -floop-optimize
LINKER       = $(MPdir)/bin/mpif77
LINKFLAGS    = $(CCFLAGS)
ARCHIVER     = ar
ARFLAGS      = r
RANLIB       = echo
EOF

# Компиляция HPL
make arch=linux

# Создание HPL.dat конфигурации для i7-3770 с 16GB памяти
cat > ~/hpl/bin/linux/HPL.dat << 'EOF'
HPLinpack benchmark input file
Innovative Computing Laboratory, University of Tennessee
HPL.out      output file name (if any)
6            device out (6=stdout,7=stderr,file)
1            # of problems sizes (N)
33000        Ns
1            # of NBs
192          NBs
0            PMAP process mapping (0=Row-,1=Column-major)
1            # of process grids (P x Q)
2            Ps
4            Qs
16.0         threshold
1            # of panel fact
2            PFACTs (0=left, 1=Crout, 2=Right)
1            # of recursive stopping criterium
4            NBMINs (>= 1)
1            # of panels in recursion
2            NDIVs
1            # of recursive panel fact.
1            RFACTs (0=left, 1=Crout, 2=Right)
1            # of broadcast
0            BCASTs (0=1rg,1=1rM,2=2rg,3=2rM,4=Lng,5=LnM)
1            # of lookahead depth
2            DEPTHs (>=0)
1            SWAP (0=bin-exch,1=long,2=mix)
64           swapping threshold
0            L1 in (0=transposed,1=no-transposed) form
0            U  in (0=transposed,1=no-transposed) form
1            Equilibration (0=no,1=yes)
8            memory alignment in double (> 0)
EOF

echo "Компиляция завершена!"
echo "Бинарный файл: ~/hpl/bin/linux/xhpl"
echo "Конфигурационный файл: ~/hpl/bin/linux/HPL.dat"

# Запуск теста производительности
echo "Запуск HPL теста на i7-3770 с 16GB памяти..."
echo "Используется 8 процессов (4 ядер + HT)"
cd ~/hpl/bin/linux

# Запуск теста с 8 процессами
$MPI_HOME/bin/mpirun --use-hwthread-cpus -np 8 --bind-to core ./xhpl > HPL.out

echo "Тест завершен!"
echo "Результаты сохранены в HPL.out"
echo "Для просмотра результатов: cat HPL.out"
