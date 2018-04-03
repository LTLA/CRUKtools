set -e
set -u

runfailed=${runfailed:=0}
extra=${extra:=""}
if [ -z ${ispet+x} ]
then
    echo "Error: must set PET specification" >&2
    exit 1
fi
if [ -z ${genome+x} ]
then
    echo "Error: must set genome index" >&2
    exit 1
fi
if [ -z ${fastq+x} ]
then
    echo "Error: must set FASTQ array" >&2
    exit 1
fi

# Setting up folders to store output 
# This needs to be done here, otherwise race conditions cause jobs to fail 
# when the directory is constructed in another thread just after the test.
if [ ! -e bam ]
then
    mkdir bam
fi

if [ ! -e logs ]
then
    mkdir logs
fi

# Host of regular expressions.
regex_fq="\\.(fastq|fq)"
regex_first="1\\.(fastq|fq)"
regex_cram="\\.cram$"

jname=Align$RANDOM
location=$( dirname $BASH_SOURCE )
for x in ${fastq[@]}
do
    subsec=$(basename $x)

    # Processing for FASTQ files
    if [[ $subsec =~ ${regex_fq} ]]
    then
        subsec=$(echo $subsec | sed -r "s/\\.(fastq|fq)(\\.gz)?$//")
        aligncmd="${location}/solo_align.sh -f $x -i $genome ${extra}" 

        if [[ $ispet -ne 0 ]]
        then
            if [[ $x =~ ${regex_first} ]] 
            # Skipping if it's not the first read.
            then
                subsec=$(echo $subsec | sed -r "s/_?(p|R)?1$//")
                mate=$(echo $x | sed -r "s/1\\.(fastq|fq)/2.\1/")
                aligncmd="${aligncmd} -m ${mate}"
            else
                continue
            fi
        fi
        supercmd="${aligncmd} -p ${subsec}"

    # Processing for CRAM files; first to BAM, then to (paired-end) FASTQ
    elif [[ $subsec =~ ${regex_cram} ]]
    then 
        subsec=$(echo $subsec | sed -r "s/\\.cram$//")
        aligncmd="${location}/solo_align.sh -i ${genome} -p ${subsec} ${extra}"

        if [[ $ispet -eq 0 ]]
        then
            ref=bam/temp_${subsec}.fastq
            supercmd="bash ${location}/cram2fastq.sh $x ${ref}; ${aligncmd} -f ${ref}; rm ${ref}"
        else 
            first=bam/temp_${subsec}_1.fastq
            mate=bam/temp_${subsec}_2.fastq
            supercmd="bash ${location}/cram2fastq.sh $x ${first} ${mate}; ${aligncmd} -f ${first} -m ${mate}; rm ${first} ${mate}"
        fi
    else 
        echo "do not comprehend ${subsec}"
        exit 1
    fi
 
    # Only running failed jobs, if requested.
    if [ -e logs/${subsec}.log ] && [ $runfailed -eq 1 ]
    then
        continue
    fi        

    # Deleting existing logs
    rm -f logs/${subsec}.err
    rm -f logs/${subsec}.out
    rm -f logs/${subsec}.log

    # Adding a job via SLURM.
    echo ${subsec}
    sbatch << EOT
#!/bin/bash
#SBATCH -o logs/${subsec}.out
#SBATCH -e logs/${subsec}.err
#SBATCH -n 1    
#SBATCH --mem 16000
set -e
set -u

${supercmd}

if [ -e logs/${subsec}.log ]
then
    rm -f logs/${subsec}.err
    rm -f logs/${subsec}.out
fi
EOT
done
