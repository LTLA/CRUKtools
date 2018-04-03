#!/bin/bash 

set -e
set -u

########################################################################################
# This runs FastQC on the incoming FASTQ files, uses subread to perform alignment, and 
# then sorts the resulting BAM files.  

sortbyname=0
mate="" 
ispet=0
extra=""
fastq=""
index=""
aligntype=0
prefix="out"
handlearg=""

while getopts "ngm:x:f:i:p:h:" opt; do
    case $opt in
    n) # Sort by name.
        sortbyname=1
        ;;
    g) # Do genomic alignment.
        aligntype=1
        ;;
    m) # Mate specifier
        mate=$OPTARG
        ispet=1
        ;;
    x) # Extra argument specifier.
        extra=$OPTARG
        ;;
    f) # FASTQ specifier
        fastq=$OPTARG
        ;;
    i) # Index specifier
        index=$OPTARG
        ;;
    p) # Prefix specifier
        prefix=$OPTARG
        ;;
    h) # Number of file handles to keep open.
        handlearg="MAX_FILE_HANDLES_FOR_READ_ENDS_MAP $OPTARG"
        ;;
    esac
done

if [ "$fastq" == "" ] || [ "$index" == "" ]
then
    echo "$0 -f FASTQ -i INDEX [-m MATE -n -g -x EXTRA -p PREFIX -h NHANDLES]" >&2
    exit 1
fi

if [ $ispet -eq 1 ] && [ "$mate" == "" ]
then
    echo "Mate must be specified for PE alignment." >&2
    exit 1
fi

#######################################################################################
# Setting up folders to put stuff in.

if [ ! -e bam ]
then
    mkdir bam
fi

if [ ! -e logs ]
then
    mkdir logs
fi

#######################################################################################

ofile="bam/${prefix}.bam"
extra="${extra} -o ${ofile} -i ${index} -t ${aligntype}"

# Figuring out if it's compressed.
if [ $( echo $fastq | grep "\\.gz$" | wc -l ) -eq 1 ]
then
    extra="${extra} --gzFASTQinput"
fi

# Figuring out the Phred.
location=$( dirname $BASH_SOURCE )
if [ $( less $fastq | head -10000 | awk 'NR % 4 == 0' | python $location/guess-encoding.py | grep "Sanger" | wc -l ) -eq 1 ]
    then
        phred=3
    else 
        phred=6
fi
extra="${extra} -P ${phred}"

# Handling it, if it's PE.
if [ $ispet -eq 1 ]
then
    subread-align -r $fastq -R $mate $extra 
else
    subread-align -r $fastq $extra
fi

# Getting rid of unnecessary files (indel files, old indexes).
for stuff in ${ofile}.indel ${ofile}.indel.vcf ${ofile}.bai
do 
    if [ -e ${stuff} ]
    then
        rm ${stuff}
    fi
done

# Sorting the files and removing duplicates.
tempbam=bam/temp_${prefix}.bam
samtools sort -o $tempbam $ofile
MarkDuplicates I=$tempbam O=$ofile M=${tempbam}.txt AS=true REMOVE_DUPLICATES=false VALIDATION_STRINGENCY=SILENT ${handlearg}
rm $tempbam ${tempbam}.txt

# Re-sorting the files by name, if requested.
if [ $sortbyname -eq 1 ]
then
    samtools sort -n -o $tempbam $ofile
    mv $tempbam $ofile
else
    samtools index $ofile
fi

#######################################################################################

success=logs/${prefix}.log
touch $success
echo $( subread-align -version 2>&1 | grep "." ) "($extra)" >> $success
fastqc --version >> $success
samtools 2>&1 | grep "Version" | sed "s/^/Samtools /" >> $success
MarkDuplicates --version 2>&1 | sed "s/^/Picard version /" >> $success

#######################################################################################


