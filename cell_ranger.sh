set -e
set -u

# Getting all of the necessary options.
full=0
while getopts ":f" opt;
do
   case $opt in
       f) 
           full=1
           ;;
   esac
done

shift $((OPTIND-1))
if [ $# -le 2 ]
then
    echo "$0 [-f] <barcode> <annotation> [OPTIONS]"
    exit 1
fi

bc=$1
anno=$2
shift
shift
otheropts="$@"

# Setting up the working directory.
workdir=working_${bc}
if [ ! -e ${workdir} ]
then
    mkdir ${workdir}
fi

# Setting up the final output directory.
if [ ! -e results ]
then
    mkdir results
fi

newdir=results/${bc}
if [ ! -e ${newdir} ]
then
    mkdir ${newdir}
fi

# Unpacking the files into 'working' and setting up the output directory.
already_done=${workdir}/.completed
if [ ! -e ${already_done} ]
then 
    for f in $(ls fastq | grep "${bc}.*tar$")
    do
        tar xf fastq/${f} -C ${workdir}
    done
    touch ${already_done}
fi

# Executing cellranger on the new cluster.
/Users/bioinformatics/software/cellranger/cellranger-2.1.0/cellranger count \
    --id="${bc}" \
    --transcriptome="${anno}" \
    --fastqs="${workdir}" \
    --sample="${bc}" \
    ${otheropts}

# Pulling out the analysis files.
cp -L ${bc}/outs/filtered_gene_bc_matrices/*/* ${newdir}
cp -L ${bc}/outs/web_summary.html ${newdir}
cp -L ${bc}/outs/metrics_summary.csv ${newdir}

# Cleaning out the files.
rm -r ${workdir}
if [ ${full} -ne 1 ]
then
    rm -r ${bc}
fi

