#!/bin/sh

JAVA=/opt/java/jdk1.6.0_16/bin/java

GATK=/ifs/data/bio/tools/GATK/GenomeAnalysisTK-1.4-20-ga9671b7/GenomeAnalysisTK.jar
SNPEFFS=/ifs/data/bio/tools/SNPeff/snpEff_205.sh 

if [ ! $# -eq 2 ]; then 
    echo
    echo "usage: snpEffAnnote.sh GENOME INPUT"
    echo "Available Genomes:"
    ls /ifs/data/bio/tools/SNPeff/Current/data | awk '{print "    "$1}'
    echo
    exit
fi

GENOME=$1
INPUT=$2
WS=SNPEffAnnote_`date +%Y%m%d_%H%M%S`
mkdir -p $WS

REFERENCE="NULL_REFERENCE"
case $GENOME in
	GRCh37.64)
	REFERENCE=/ifs/data/bio/Genomes/H.sapiens/hg19/human_hg19.fa
	;;
	hg19)
	REFERENCE=/ifs/data/bio/Genomes/H.sapiens/hg19/human_hg19.fa
	;;
    NCBIM37.64)
	REFERENCE=/ifs/data/bio/Genomes/M.musculus/mm9/mouse_mm9.fa
	;;
	paeru.PA14)
	REFERENCE=/ifs/data/bio/Genomes/P.aeruginosa/UCBPP-PA14/NC_008463.fasta
	;;
	*)
	echo "REFERENCE NOT DEFINE FOR THIS GENOME"
	exit
	;;
esac

echo "INPUTS =" $GENOME $INPUT
echo "WorkSpace =" $WS

cd $WS
$SNPEFFS eff -i vcf -o vcf -chr chr -v -noLog $GENOME ../$INPUT \
    | sed 's/2.0.5d (build 2012-01-19)/2.0.5 (build 2012-01-12)/' >annote.vcf
cd ..

$JAVA -Xmx32g -jar $GATK -T VariantAnnotator \
    -R $REFERENCE -et NO_ET \
    -A SnpEff \
    --variant $INPUT \
    --snpEffFile $WS/annote.vcf \
    -o ${INPUT%%.vcf}___ANNOTE.vcf
