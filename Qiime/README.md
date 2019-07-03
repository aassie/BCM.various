# Qiime related scripts

## QimmeWrapper.sh

It's a Qiime 16s rRNA Amplicon Pipeline wrapper

This script use 16S rRNA amplicon sequencing file from Illumina and assume you have followed the Earth Microbiome Sequencing project protocol ([link](http://www.earthmicrobiome.org/protocols-and-standards/16s/).

**Requirement**

- A text file tab delimited that will serve as metadata input for the analysis.
- Assuming that you have three sequencing file they need to be placed in a input folder (Default 00_Reads), the file need to be renamed (or simlinked) as forward.fastq.gz reverse.fastq.gz and barcodes.fastq.gz.

````
    Usage: QimmeWrapper.sh [OPTIONS] -m metadata file

    Options:
        Required
        -m|--metadata          Path to metadata file (REQUIRED)    
        
        General:
        -h|--help              Displays this help
        -i|--input            Path to folder only containing the following files:
                                -forward.fastq.gz
                                -reverse.fastq.gz
                                -barcodes.fastq.gz 
                                (Default folder: 00_Reads)
        -o|--output            Output Path for main Qiime output files (Default 01_Qiime/Process)
        -v|--viz               Output Path for Qiime visualisation files (Default 01_Qiime/Vizualisations)
        -s|--stats             Output Path for Qiime statistical analyzes (Default 01_Qiime/stats)
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
````
