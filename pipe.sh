#!/bin/bash

#./PEMapper/pipe.sh eColi_MG1665 /ifs/archive/GCL/hiseq/FASTQ/VIC_2219_000000000-AGKGN/Project_4298_B/Sample_BW30270
#./PEMapper/pipe.sh eColi_MG1665 /ifs/archive/GCL/hiseq/FASTQ/VIC_2219_000000000-AGKGN/Project_4298_B/Sample_K761ER765E

SDIR="$( cd "$( dirname "$0" )" && pwd )"

BAMS=$*

JAVA=/opt/common/CentOS_6/java/jdk1.7.0_75/bin/java
GATKJAR=/opt/common/CentOS_6/gatk/GenomeAnalysisTK-3.4-0-g7e26428/GenomeAnalysisTK.jar
GENOME=/ifs/work/socci/Depot/Genomes/E.coli/K12/MG1655/eColi__MG1655.fa

if [ "" ]; then
echo "Do not re-run"
exit

bsub -o LSF/ -n 24 -J STAGE_1_$$ -R "rusage[mem=72]" -We 59 \
    $SDIR/haplotypeCallerDMP.sh \
    $GENOME $SDIR/data/pass0.vcf NC_000913 $BAMS

bsub -o LSF/ -n 24 -J STAGE_1_$$ -R "rusage[mem=72]" -We 59 \
    $SDIR/indelRealigner.sh \
    $GENOME \
    NC_000913 \
    $BAMS
fi

#HOLDID=$(~/bin/qstatFull | awk -v TAG=STAGE_1_$$ '$3==TAG{print $1}' | xargs  | tr ' ' ',')
#echo HOLDID=$HOLDID
#qSYNC $HOLDID
#sleep 60

INPUTS=$(find output -name "*.bam" | awk '{print "-I "$1}')
KNOWN=$(find output -name "*.vcf")

echo KNOWN=$KNOWN
echo INPUTS=$INPUTS

bsub -o LSF/ -n 24 -J STAGE_2_$$ -R "rusage[mem=72]" -We 59 \
$JAVA -Xms256m -Xmx48g -XX:-UseGCOverheadLimit -Djava.io.tmpdir=/scratch/socci -jar $GATKJAR \
    -T BaseRecalibrator -nct 24 -R $GENOME -knownSites $KNOWN -o recal_data.table \
    $INPUTS

for bam in $(find output -name "*.bam"); do
bsub -o LSF/ -n 2 -J STAGE_3_$$ -R "rusage[mem=50]" -We 59 -w "post_done(STAGE_2_$$)" \
    $JAVA -Xms256m -Xmx48g -XX:-UseGCOverheadLimit -Djava.io.tmpdir=/scratch/socci \
    -jar $GATKJAR \
    -T PrintReads -R $GENOME \
    -BQSR recal_data.table \
    -I $bam -o ${bam}_recal.bam
done

exit

#HOLDID=$(~/bin/qstatFull | awk -v TAG=STAGE_3_$$ '$3==TAG{print $1}' | xargs  | tr ' ' ',')
#echo HOLDID=$HOLDID
#qSYNC $HOLDID
#sleep 60

INPUTS=$(find output -name "*recal.bam")
#qsub -pe alloc 24 -N STAGE_4_$$ -l virtual_free=3G ~/Work/SGE/qCMD \
    ./haplotypeCallerDMP.sh \
    $GENOME $KNOWN NC_000913 $INPUTS


exit
##
# Annotation
#

./snpEffAnnote.sh \
    Escherichia_coli_K_12_substr__MG1655_uid57779
    output/100616c4a3f7c8475c05bd9f7cab28be/NC_000913/haplo.vcf \
    /ifs/data/bio/Genomes/E.coli/K12/MG1655/eColi__MG1655.fa

~/Work/SeqAna/Pipelines/BIC/variants_pipeline/maf/vcf2maf0.py \
    -c haplo -i haplo___ANNOTE.vcf -o haplo___ANNOTE.maf

PROJNO=proj_4298_B

cat haplo___ANNOTE.maf | ./pA_Functional.py >${PROJNO}___ANNOTE__FUNCTIONAL.maf
cat ${PROJNO}___ANNOTE__FUNCTIONAL.maf | ./pA_noLow+AltHomoZ.py >${PROJNO}___ANNOTE__FUNCTIONAL__FilterB.maf

