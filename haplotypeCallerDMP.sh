#!/bin/bash

source /home/socci/Code/Wrappers/gatk.sh

GENOME=$1
DBSNP=$2
TARGET=$3
shift 3

BASE=$(basename $TARGET)
OUTDIR=output

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
OUTVCF=$OUTDIR/haplo.vcf
echo $* | tr ' ' '\n' >$OUTDIR/bams

NCORES=24
MEM=50g

MAPQ=20

$JAVA -Xms512m -Xmx${MEM} -XX:-UseGCOverheadLimit \
	-Djava.io.tmpdir=/scratch/socci \
	-jar $GATKJAR \
	-T HaplotypeCaller \
	--num_cpu_threads_per_data_thread $NCORES \
	-R $GENOME \
	-L $TARGET \
	--dbsnp $DBSNP \
	-stand_call_conf 20 \
	-stand_emit_conf 20 \
	--downsampling_type NONE \
	--annotation AlleleBalanceBySample \
	--annotation ClippingRankSumTest \
	-mmq $MAPQ \
	-rf DuplicateRead \
	-rf FailsVendorQualityCheck \
	-rf NotPrimaryAlignment \
	-rf BadMate \
	-rf MappingQualityUnavailable \
	-rf UnmappedRead \
	-rf BadCigar \
	--out $OUTVCF \
	$INPUTS
