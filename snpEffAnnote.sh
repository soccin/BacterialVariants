#!/bin/sh
SDIR="$( cd "$( dirname "$0" )" && pwd )"

JAVA=/opt/common/CentOS_6-dev/bin/current/java
GATK=/opt/common/CentOS_6/gatk/GenomeAnalysisTK-3.4-0-g7e26428/GenomeAnalysisTK.jar

SNPEFFS=$SDIR/SNPEff/v_3.3h/snpEff

if [ ! $# -eq 3 ]; then
    echo
    echo "usage: snpEffAnnote.sh GENOME INPUT FASTQ"
    echo "Available Genomes:"
    ls $SNPEFFS/data | awk '{print "    "$1}'
    echo
    exit
fi

GENOME=$1
INPUT=$2
GENOMEFASTQ=$3
WS=SNPEffAnnote_`date +%Y%m%d_%H%M%S`
mkdir -p $WS

echo "INPUTS =" $GENOME $INPUT
echo "WorkSpace =" $WS

cd $WS
$JAVA -Xmx8G -jar $SNPEFFS/snpEff.jar eff -c $SNPEFFS/snpEff.config \
-i vcf -o gatk -v $GENOME ../$INPUT >annote.vcf
cd ..

$JAVA -Xmx8g -jar $GATK -T VariantAnnotator \
    -R $GENOMEFASTQ \
    -A SnpEff \
    --variant $INPUT \
    --snpEffFile $WS/annote.vcf \
    -o $(basename $INPUT | sed 's/.vcf//')___ANNOTE.vcf
