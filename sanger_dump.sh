set -e 
set -u

# Converts a folder of Sanger-derived CRAM files to their equivalent
# FASTQ files; gzips them and computes the MD5 sums.

if [ $# -ne 1 ]
then
    echo "$0 [PAIRED/SINGLE]"
    exit 1
fi

if [ $1 != "PAIRED" ] && [ $1 != "SINGLE" ]
then
    echo "$0 [PAIRED/SINGLE]"
    exit 1
fi

if [ ! -d cram ]
then
    echo "need 'cram' directory containing CRAM files"
    exit 1
fi

if [ ! -d fastq ]
then
    mkdir fastq
    lfs setstripe -s 64m -c -1 fastq/ # Adding stripe settings.
fi

location=$(dirname $BASH_SOURCE)
for cf in $(ls cram | grep ".cram$")
do 
    prefix=$(echo $cf | sed "s/\\.cram$//g")
    if [ $1 == "SINGLE" ]
    then
        xfile=fastq/${prefix}.fq
        bash ${location}/cram2fastq.sh cram/$cf $xfile
        gzip -f $xfile
    elif [ $1 == "PAIRED" ]
    then
        xfile1=fastq/${prefix}_1.fq
        xfile2=fastq/${prefix}_2.fq
        bash ${location}/cram2fastq.sh cram/$cf $xfile1 $xfile2
        gzip -f $xfile1
        gzip -f $xfile2
    fi
done

cd fastq
md5sum *.fq.gz > md5.all
cd -
exit 0
