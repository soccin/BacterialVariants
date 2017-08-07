#!/bin/bash

#
# Need to run PEMapper

## CMDS:
## ls -d /ifs/archive/GCL/hiseq/FASTQ/*/P*4298*[EF]*/S* >sampleDIRS
## getMappingSheet.sh sampleDIRS >Proj_04928_EF_sample_mapping.txt
## ../PEMapper/runPEMapperMultiDirectories.sh eColi_MG1665 Proj_04928_EF_sample_mapping.txt


SDIR="$( cd "$( dirname "$0" )" && pwd )"

if [ "$#" -lt 1 ]; then
    echo "usage: pipe.sh 1_MD.bam [i_MD.bam ...]"
    exit
fi

PROJNO=$(basename $PWD)
echo $PROJNO

BAMS=$*

JAVA=/opt/common/CentOS_6/java/jdk1.7.0_75/bin/java
GATKJAR=/opt/common/CentOS_6/gatk/GenomeAnalysisTK-3.4-0-g7e26428/GenomeAnalysisTK.jar
GENOME=/ifs/work/socci/Depot/Genomes/E.coli/K12/MG1655/eColi__MG1655.fa

STAGE1="YES"
STAGE2="YES"

if [ "$STAGE1" == "YES" ]; then

bsub -o LSF/ -n 24 -J STAGE_1_$$ -R "rusage[mem=72]" -We 59 \
    $SDIR/haplotypeCallerDMP.sh \
    $GENOME $SDIR/data/pass0.vcf NC_000913 $BAMS

bsub -o LSF/ -n 24 -J STAGE_1_$$ -R "rusage[mem=72]" -We 59 \
    $SDIR/indelRealigner.sh \
    $GENOME \
    NC_000913 \
    $BAMS

fi

bSync STAGE_1_$$

INPUTS=$(find output -name "*.bam" | awk '{print "-I "$1}')
KNOWN=$(find output -name "*.vcf")

echo KNOWN=$KNOWN
echo INPUTS=$INPUTS

if [ "$STAGE2" == "YES" ]; then

bsub -o LSF/ -n 24 -J STAGE_2_$$ -R "rusage[mem=72]" -We 59 \
$JAVA -Xms256m -Xmx48g -XX:-UseGCOverheadLimit -Djava.io.tmpdir=/scratch/socci -jar $GATKJAR \
    -T BaseRecalibrator -nct 24 -R $GENOME -knownSites $KNOWN -o recal_data.table \
    $INPUTS

for bam in $(find output -name "*.bam"); do
bsub -o LSF/ -n 2 -J STAGE_2a_$$ -R "rusage[mem=50]" -We 59 -w "post_done(STAGE_2_$$)" \
    $JAVA -Xms256m -Xmx48g -XX:-UseGCOverheadLimit -Djava.io.tmpdir=/scratch/socci \
    -jar $GATKJAR \
    -T PrintReads -R $GENOME \
    -BQSR recal_data.table \
    -I $bam -o ${bam}_recal.bam
done

fi

bSync STAGE_2a_$$


INPUTS=$(find output -name "*recal.bam")
#qsub -pe alloc 24 -N STAGE_4_$$ -l virtual_free=3G ~/Work/SGE/qCMD \
$SDIR/haplotypeCallerDMP.sh \
    $GENOME $KNOWN NC_000913 $INPUTS


##
# Annotation
#

VCF=$(ls -1rt output/*/*/haplo*vcf | tail -1)


$SDIR/snpEffAnnote.sh \
    Escherichia_coli_K_12_substr__MG1655_uid57779 \
    $VCF \
    $GENOME

$SDIR/vcf2maf0.py \
    -c haplo -i haplo___ANNOTE.vcf -o haplo___ANNOTE.maf


cat haplo___ANNOTE.maf | $SDIR/pA_Functional.py >${PROJNO}___ANNOTE__FUNCTIONAL.maf
cat ${PROJNO}___ANNOTE__FUNCTIONAL.maf | $SDIR/pA_noLow+AltHomoZ.py >${PROJNO}___ANNOTE__FUNCTIONAL__FilterB.maf

