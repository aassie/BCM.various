#Put all the gbk file in a name list

ls 01_GB/*.gbk > name.list.txt

#The script below will check the gbk file, split them in single one and rewrite the .dat file properly
Name=($(gsed 's/01_GB\///g' name.list.txt))
TAB=$'\t'
Npars=${#Name[@]}
for ((i=000; i<Npars; i++)); 
    do Name2=$(echo ${Name[$i]} | gsed "s/\.gbk//g");
    mkdir -p ./02_Pathologic/$Name2; 
done

for ((i=0; i<Npars; i++)); 
    do ((j=i+1));
    Name2=$(echo ${Name[$i]} | gsed "s/\.gbk//g");
    awk -v n=1 -v b=$Name2 -v z=$Name2 '/^\/\//{close("./02_Pathologic/"z"/"b"_"n".gbk");n++;next} {print > ("./02_Pathologic/"z"/"b"_"n".gbk")}' ./01_GB/$Name2.gbk;
    c=0;
    for b in ./02_Pathologic/$Name2/$Name2_*.gbk; 
        do ((c=$c+1));
       d=$(echo $b| gsed "s/\.\/02_Pathologic\/$Name2\///g");
       gsed "s/^ID/ID$TAB\K$j\c$c/g; s/Contig/Contig\-$c/g; s/TYPE/TYPE$TAB\:Contig/g; s/ANNOT-FILE/ANNOT-FILE$TAB$d/g" Sample2.dat >> ./02_Pathologic/$Name2/genetic-elements.dat;
    done;
done

#Process organims.dat from either the gbk file if taxon and organim are set or from a ref database file, in this case Metadata from Patric
for ((i=0; i<Npars; i++)); 
    do ((j=i+1));
    Name2=$(echo ${Name[$i]} | gsed "s/\.gbk//g");
    s1=$(grep "organism" ./01_GB/${Name[$i]} | head -n 1 |sed "s/\/organism=//g; s/\"//g");
    if [ -z "$s1" ]
    then
      tax=$(grep $(echo ${Name[$i]}] | cut -f1 -d "_") Metadata.patric.txt | cut -f4)
      sname=$(grep $(echo ${Name[$i]} | cut -f1 -d "_") Metadata.patric.txt | cut -f2 | gsed 's/"//g');
      sn2=$(echo $sname | cut -f 2 -d " ");
    else
      sname=$(echo $s1);
      sn2=$(echo $sname | cut -f 2 -d " ");
      s1=$(grep "taxon:" ./01_GB/${Name[$i]} | head -n 1 |sed "s/\/db_xref\=\"taxon\://g; s/\"//g");
      tax=$(echo $s1);
    fi
    echo "Processing" K$j "as" $sname;
    if [ "$sn2" == "sp." ];
    then
        abname=$(echo $sname | cut -f 1-2 -d " ");
    else
        ab1=$(echo $sname | head -c 1 | sed "s/$/\./g");
        ab2=$(echo $sname | cut -f 2 -d " ");
        abname=$(echo $ab1 $ab2);
    fi
    #s1=$(grep "strain=" ./01_GB/${Name[$i]} | head -n 1 |sed "s/\/strain=//g; s/\"//g" );
    strain=$(awk 'NF>1{print $NF}'<<<$sname)
    sname2=$(gsed "s/$strain//g; s/ strain //g" <<<$sname)
    sname=$(echo $sname2)
    sed "s/^ID/ID$TAB\K$j/g; s/^NAME/NAME$TAB$sname/g; s/ABBREV-NAME/ABBREV-NAME$TAB$abname/g; s/STRAIN/STRAIN$TAB$strain/g; s/NCBI-TAXON-ID/NCBI-TAXON-ID$TAB$tax/g; s/DBNAME/DBNAME$TAB\K$j\Cyc/g" organism-params.dat > ./02_Pathologic/$Name2/organism-params.dat;
done

ls -d path/to/individual/genbank/file/ > patholist.tab

Pname=($(awk '{print $1}' patholist.tab))
Npars=${#Pname[@]}
for ((i=0; i<Npars; i++));
    do /Users/adrien/pathway-tools/pathway-tools -tip -patho ${Pname[$i]}; 
done

#The manual state that /Users/adrien/pathway-tools/pathway-tools -tip -patho -f patholist.tab should work it doesn't
