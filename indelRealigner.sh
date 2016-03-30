#!/bin/bash

source /home/socci/Code/Wrappers/gatk.sh

GENOME=$1
TARGET=$2
shift 2

BASE=$(basename $TARGET)
OUTDIR=output

BAMS=$*
INPUTS=$(echo $* | tr ' ' '\n' | awk '{print "-I ",$1}')

if [ "$#" -eq 1 ]; then
    OUTDIR=$OUTDIR/$(basename $1 | sed 's/.bam//')
else
    uuid=$(echo $* | md5sum - | awk '{print $1}')
    OUTDIR=$OUTDIR/$uuid
fi

OUTDIR=$OUTDIR/$BASE
mkdir -p $OUTDIR
echo "OUTDIR="$OUTDIR
echo $* | tr ' ' '\n' >$OUTDIR/bams

NCORES=24
MEM=50g

$JAVA -Xms256m -Xmx${MEM} -XX:-UseGCOverheadLimit -Djava.io.tmpdir=/scratch/socci \
    -jar $GATKJAR \
    -T RealignerTargetCreator \
    -R $GENOME -L $TARGET -S LENIENT -nt $NCORES -rf BadCigar \
    --out $OUTDIR/_group__indelRealigner.intervals \
    $INPUTS

for bam in $BAMS; do

    #qsub -pe alloc 2 -l virtual_free=50G -N gatk_IR_$$ -b y -cwd \
    $JAVA -Xms256m -Xmx48g -XX:-UseGCOverheadLimit -Djava.io.tmpdir=/scratch/socci \
        -jar $GATKJAR -T IndelRealigner \
        -R $GENOME -L $TARGET -S LENIENT \
        --targetIntervals  $OUTDIR/_group__indelRealigner.intervals \
        --maxReadsForRealignment 500000 \
        --maxReadsInMemory 3000000 \
        --maxReadsForConsensuses 5000 \
        -rf BadCigar \
        --out $OUTDIR/$(basename $bam)_indelRealigned.bam \
        -I $bam

done
