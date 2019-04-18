#!/bin/bash
# ------------------------------------------------------------------
# [Adrien Assié] Qiime 16s rRNA Amplicon Pipeline
#          The default commands to process a raw file from start to
#          almost finish with Qiime
# ------------------------------------------------------------------

VERSION=0.1.0
SUBJECT=QiimeWrapper
USAGE="QimmeWrapper.sh [OPTIONS] -m metadata file"

function script_usage() {
    cat << EOF
    Qiime 16s rRNA Amplicon Pipeline parser

    Usage: $USAGE

    Options:
        Requuired
        -m|--metadata          Path to metadata file (REQUIRED)    
        
        General:
        -h|--help              Displays this help
        -i|--inputh            Path to folder only containing the following files:
                                -forward.fastq.gz
                                -reverse.fastq.gz
                                -barcodes.fastq.gz 
                                (Default folder: $INPUT)
        -o                     Output Path for main Qiime output files (Default $OUTPUT)
        -v                     Output Path for Qiime visualisation files (Default $VISFOL)
        -s|--stats             Output Path for Qiime statistical analyzes (Default $01_Qiime/stats)
        -d|--use_deblur        Use Deblur denoising algorith instead of Dada2
        -t|--taxonomy          
        -c|--classifier        Path to taxonomic reference file
        -sg|--stats-group      Which column to use for Beta diversity clustering    
        
        Modules:                By default all modules are running
        -sl|--skip-load        Skip loading raw sequences
        -sd|--skip-demux       Skip demultiplexing step
        -so|--skip-denoise     Skip denoising step
        -st|--skip-taxonomy    Skip taxonomy classification
        -ss|--skip_ABDiversity Skip Alpha and Beta diversity analyzes
        -se|--skip-export      Skip export as biom file and conversion to csv
EOF
}

# --- Options processing -------------------------------------------
set -e 

skip_load=0
skip_demux=0
skip_denoise=0
skip_ABD=0
skip_tax=0
skip_chimera=0
skip_export=0

INPUT="00_Reads"
METADATA="PLACEHOLDER"
OUTPUT="01_Qiime/Process"
VISFOL="01_Qiime/Vizualisations"
STAT="01_Qiime/stats"
TAX=1
CLASSIFIER="PLACEHOLDER"
DENOISE="DaDa2"
STATCOL="PLACEHOLDER"

# --- Functions -------------------------------------------

# Counter
counter=0
function Qcounter {
    ((counter=counter+1))
    printf "Step $counter - "; date "+%H:%M:%S"
}

# Import Data
function QiimeLoad {
    qiime tools import    --type 'EMPPairedEndSequences' \
        --input-path $INPUT \
        --output-path $OUTPUT/paired-end.qza
    Qcounter
}

# Demultiplex reads
function QiimeDemux {
    qiime demux emp-paired \
        --m-barcodes-file $METADATA \
        --m-barcodes-column BarcodeSequence \
        --i-seqs $OUTPUT/paired-end.qza \
        --o-per-sample-sequences $OUTPUT/demux-paired-end.qza \
        --p-rev-comp-mapping-barcodes
    Qcounter

    qiime demux summarize \
        --i-data $OUTPUT/demux-paired-end.qza \
        --o-visualization $VISFOL/demux.qzv
    Qcounter
}

# Denoise data and Cluster - DADA2
function QiimeClusterDaDa {
    qiime dada2 denoise-paired \
        --i-demultiplexed-seqs $OUTPUT/demux-paired-end.qza \
        --p-trunc-len-f 250 \
        --p-trunc-len-r 250 \
        --o-representative-sequences $OUTPUT/rep-seqs.qza \
        --o-table $OUTPUT/table.qza \
        --o-denoising-stats dadastats
    Qcounter

    qiime feature-table summarize \
        --i-table $OUTPUT/table.qza \
        --o-visualization $VISFOL/table.qzv \
        --m-sample-metadata-file $METADATA
    Qcounter

    qiime feature-table tabulate-seqs \
        --i-data $OUTPUT/rep-seqs.qza \
        --o-visualization $VISFOL/rep-seqs.qzv
    Qcounter
}

# Denoise data and Cluster - Deblur
function QiimeClusterDeblur {
    qiime deblur denoise-16S \
    --i-demultiplexed-seqs $OUTPUT/demux-paired-end.qza \
    --p-trunc-len-f 250 \
    --p-trunc-len-r 250 \
    --o-representative-sequences $OUTPUT/rep-seqs.qza \
    --o-table $OUTPUT/table.qza \
    --o-denoising-stats deblurstats
    Qcounter

    qiime feature-table summarize \
        --i-table $OUTPUT/table.qza \
        --o-visualization $VISFOL/table.qzv \
        --m-sample-metadata-file $METADATA
    Qcounter

    qiime feature-table tabulate-seqs \
        --i-data $OUTPUT/rep-seqs.qza \
        --o-visualization $VISFOL/rep-seqs.qzv
    Qcounter
}    

#Processing Sequences
function QiimeSeqProcessing {
    #Carry out a multiple seqeunce alignment using Mafft
    qiime alignment mafft \
        --i-sequences $OUTPUT/rep-seqs.qza \
        --o-alignment $OUTPUT/aligned-rep-seqs.qza
    Qcounter
    #Mask (or filter) the alignment to remove positions that are highly variable. These positions are generally considered to add noise to a resulting phylogenetic tree.
    qiime alignment mask \
        --i-alignment $OUTPUT/aligned-rep-seqs.qza \
        --o-masked-alignment $OUTPUT/masked-aligned-rep-seqs.qza
    Qcounter
    #Create the tree using the Fasttree program
    qiime phylogeny fasttree \
        --i-alignment $OUTPUT/masked-aligned-rep-seqs.qza \
        --o-tree $OUTPUT/unrooted-tree.qza
    Qcounter
    #Root the tree using the longest root
    qiime phylogeny midpoint-root \
        --i-tree $OUTPUT/unrooted-tree.qza \
        --o-rooted-tree $OUTPUT/rooted-tree.qza
    Qcounter
}

#STATS
function QiimeDiversity {
    #Get mean frequency for first Alpha diversity analysis
    echo "Getting sequencing depth"
    mkdir -p $VISFOL/tmp/
    qiime tools export --input-path $VISFOL/table.qzv --output-path $VISFOL/tmp/
    tmean=$(grep -A 1 "1st quartile" $VISFOL/tmp/overview.html | sed -n 2p | sed "s/<[^>]*//g; s/>//g; s/ //g; s/,//g; s/\./,/g")
    mean=$(awk -v M=$tmean 'BEGIN { rounded = sprintf("%.0f", M); print rounded }')
    echo "Using " $mean " as max depth"

    #Calculate Alpha diversity/Rarefaction curves
    qiime diversity alpha-rarefaction \
        --i-table $OUTPUT/table.qza \
        --i-phylogeny $OUTPUT/rooted-tree.qza \
        --p-max-depth $mean \
        --m-metadata-file $METADATA \
        --o-visualization $VISFOL/alpha-rarefaction.qzv
    Qcounter

    # Basic stats on the different samples using metadata
    qiime diversity core-metrics-phylogenetic \
        --i-phylogeny $OUTPUT/rooted-tree.qza \
        --i-table $OUTPUT/table.qza \
        --p-sampling-depth $mean \
        --m-metadata-file $METADATA \
        --output-dir $STAT
    Qcounter

    # Test effect of rarefaction
    qiime diversity beta-rarefaction \
        --i-table $OUTPUT/table.qza \
        --i-phylogeny $OUTPUT/rooted-tree.qza \
        --p-max-depth $mean \
        --m-metadata-file $METADATA \
        --o-visualization beta-rarefaction-$mean.qzv


    #Calculate group significance with Alpha and Beta diversity
    qiime diversity alpha-group-significance \
        --i-alpha-diversity $STAT/evenness_vector.qza \
        --m-metadata-file $METADATA \
        --o-visualization $STAT/evenness-group-significance.qzv

    CNUM=$(cat $METADATA | grep $STATCOL| tr -c "[:alnum:]#_" "\n" | awk "/$STATCOL/{print NR}" | tr -c [:digit:] "," |sed "s/,$/$last/g")
    GROUP=$(cut -f $CNUM $METADATA | tail -n +2 | sort | uniq)
    for i in $GROUP;
    do qiime diversity beta-group-significance \
        --i-distance-matrix $STAT/unweighted_unifrac_distance_matrix.qza \
        --m-metadata-file $METADATA \
        --m-metadata-column Type \
        --o-visualization stats/unweighted-unifrac-$i-significance.qzv \
        --p-pairwise;
    done
}


#Classify reads with Taxonomy
function QiimeTaxonomy {
    qiime feature-classifier classify-sklearn \
        --i-classifier $CLASSIFIER \
        --i-reads $OUTPUT/rep-seqs.qza \
        --o-classification $OUTPUT/taxonomy.qza

    qiime metadata tabulate \
        --m-input-file $OUTPUT/taxonomy.qza \
        --o-visualization $VISFOL/taxonomy.qzv

    qiime taxa barplot \
        --i-table $OUTPUT/table.qza \
        --i-taxonomy $OUTPUT/taxonomy.qza \
        --m-metadata-file $METADATA \
        --o-visualization $VISFOL/taxa-bar-plots.qzv
}

#Export
function QiimeExport {
    mkdir -p $OUTPUT/export/
    qiime taxa collapse \
        --i-table $OUTPUT/table.qza \
        --i-taxonomy $OUTPUT/taxonomy.qza \
        --p-level 6 \
        --o-collapsed-table $OUTPUT/table-tax.qza

    qiime tools export \
        --input-path $OUTPUT/table-tax.qza \
        --output-path $OUTPUT/export/    
}

# --- Main -------------------------------------------------

while [ "$1" != "" ]; do
  case $1 in
     -i|--inputh)
       shift
       INPUT=$1
       ;;
     -o|--output)
       shift
       OUTPUT=$1
       ;;
     -v|--viz)
       shift
       VISFOL=$1
       ;;
     -m|--metadata)
       shift
       METADATA=$1
       ;;
     -t|--taxonomy)
       shift
       TAX=$1
       ;;  
     -c|--classifier)
       shift
       CLASSIFIER=$1
       ;;
     -h|--help)
       script_usage
       exit 0
       ;;
     -s|--stats)
       shift
       STAT=$1
       ;;
     -sg|--stats-group)
       shift
       STATCOL=$1
       ;;
     -sl|--skip-load)
       skip_load=1
       ;;
     -so|--skip-denoise)
       skip_denoise=1
       ;;
     -sd|--skip-demux)
       skip_demux=1
       ;;
     -ss|--skip-ABDiversity)
       skip_ABD=1
       ;;
     -sc|--skip-chimera)
       skip_stat=1
       ;;
     -st|--skip-taxonomy)
       skip_stat=1
       ;;
     -se|--skip-export)
       skip_export=1
       ;;
     -d|--use_deblur)
       DENOISE="Deblur"
       ;;
     *) 
       echo "invalid command: no parameter included with argument $1"
       exit 0
       ;;
  esac
  shift
done

echo "Starting Qiime Parser v1.0"

#check required arguments
if ls $METADATA 1> /dev/null 2>&1; then echo "Found Metadata file" ; else echo -e "ERROR:""\n""Please provide a metadata file with the -m option""\n" && exit; fi

#Create ouput folder
mkdir -p $OUTPUT $VISFOL $STAT

#Checking files are in input folder
echo -e "Checking for input files"
if [ $(ls -l $INPUT/ | grep -c "^") == 4 ]; then echo "."; else echo "There are more files than expected in the input folder" && exit; fi

echo -e "----" "\n"

echo "Sequences files:"
if ls $INPUT | grep -Fq "forward.fastq.gz"; then echo "Found \"forward.fastq.gz\"" ; else echo "Missing \"forward.fastq.gz\" file" && exit; fi
if ls $INPUT | grep -Fq "reverse.fastq.gz"; then echo "Found \"reverse.fastq.gz\"" ; else echo "Missing \"reverse.fastq.gz\" file" && exit; fi
if ls $INPUT | grep -Fq "barcodes.fastq.gz"; then echo "Found \"barcodes.fastq.gz\"" ; else echo "Missing \"barcodes.fastq.gz\" file" && exit; fi

echo -e "\n" "----" "\n"
echo -e "Running " $(qiime info | grep "QIIME 2 version") "\n"

if [ $skip_load == 0 ]; then QiimeLoad; else echo "You skipped Loading sequences"; fi
echo -e "\n" "----" "\n"
if [ $skip_demux == 0 ]; then QiimeDemux; else echo "You skipped Demultiplexing sequences"; fi
echo -e "\n" "----" "\n"
if [ $skip_denoise == 0 ]; 
    then if [ $DENOISE == "DaDa2" ];
        then QiimeClusterDaDa;
        echo "Running Denoising with DaDa2";
        elif [ $DENOISE == "Deblur" ];
        then QiimeClusterDeblur;
        echo "Running Denoising with Deblur"
        fi;
    else echo "You skipped Denoising sequences"; 
fi
echo -e "\n" "----" "\n"
if [ $skip_ABD == 0 ]; then QiimeDiversity; else echo "You skipped Alpha and Beta Diversity"; fi
echo -e "\n" "----" "\n"
if [ $skip_tax == 0 ]; then QiimeTaxonomy; else echo "You skipped Taxonomic classification"; fi
echo -e "\n""----" "\n"
if [ $skip_export == 0 ]; then QiimeExport; else echo "You skipped Biom and csv export"; fi

echo "Qiime Pipleine done"
