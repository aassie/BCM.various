// Paranoid Cleanup
run("Clear Results");
if (roiManager("Count") > 0){
	roiManager("Select All");
	roiManager("Delete");
}

// Function for Channel selection
function getChannelSelections() {
    Dialog.create("Select Channels");
    Dialog.addChoice("Nucleus Channel:", newArray("C1", "C2", "C3"), "C1");
    Dialog.addChoice("Cell Background Channel:", newArray("C1", "C2", "C3"), "C2");
    Dialog.addChoice("Signal Channel:", newArray("C1", "C2", "C3"), "C3");
    Dialog.show();
    
    var nucleusChannel = Dialog.getChoice();
    var cellChannel = Dialog.getChoice();
    var signalChannel = Dialog.getChoice();
    
    return newArray(nucleusChannel, cellChannel, signalChannel);
}

// Load file
waitForUser("Please select the folder that contains your raw microscopy pictures");
wait(500);
RawInput = getDirectory("Please select the folder that contains your raw microscopy pictures");
list = getFileList(RawInput);
Soutput=RawInput+"Analysis_Output/";
File.makeDirectory(Soutput);
header = "ID,Nucleus Area, Nucleus Signal, Whole Cell Area, Whole cell signal, Cytoplasm Area, Cytoplasm signal, Cell Number (Nuclei),Cell Number (Cells),Mean Circularity,Mean AR,Mean Roundness,Note";

//Channel selection
selections = getChannelSelections();
nucleusChannel = replace(selections[0],"C","000");
cellChannel = replace(selections[1],"C","000");
signalChannel = replace(selections[2],"C","000");


//Process files
for (i=0; i<list.length; i++){
	Note1="";
	Note2="";
	Note3="";
	//First set thresholds
	run("Bio-Formats Importer", "open=" + RawInput + list[i] + " autoscale color_mode=Default view=Hyperstack stack_order=XYCZT");
	
	getDimensions(width, height, channels, slices, frames);
	//print(channels);
	name=File.nameWithoutExtension();
	// Remove space in name
	newTitle = replace(name, " ", "_");
	rename(newTitle);
	
	//Normalize background and split channel
	run("Subtract Background...", "rolling=50 stack");
	run("Stack to Images");
	
	//Processing nucleus signal
	selectImage(newTitle+"-"+nucleusChannel);
	
	//run("Threshold...");
	setThreshold(80, 65535, "raw");
	setOption("BlackBackground", true);
	run("Convert to Mask");
	run("Despeckle");
	run("Create Selection");
	if( selectionType() != -1 ){
		roiManager("Add");
		roiManager("Select", 0);
		roiManager("Rename", "Nucleus");
		roiManager("Deselect");
		isNucleusSelection=0;
	}else{
		isNucleusSelection=-1;
		Note1="No Nuclei detected";
	}

	//Process Cell channel
	selectImage(newTitle+"-"+cellChannel);
	setThreshold(80, 65535, "raw");
	run("Convert to Mask");
	run("Despeckle");
	//Clean noise further
	run("Remove Outliers...", "radius=5 threshold=50 which=Bright");
	run("Create Selection");
	if( selectionType() != -1 ){
		roiManager("Add");
		wait(20);
		roiManager("Select", roiManager("Count")-1);
		roiManager("Rename", "Cells");
		isCellSelection=0;
	}else{
		isCellSelection=-1;
		Note2=" No Cells detected";
	}
	
	selectImage(newTitle+"-"+signalChannel);
	if (roiManager("Count") ==2 ){
		//Process signal channel
		//create a cytoplasm section
		roiManager("Select", newArray(0,1));
		roiManager("XOR");
		roiManager("Add");
		roiManager("Select", 2);
		roiManager("Rename", "Cytoplasm");
		roiManager("Select", newArray(0,1,2));
		roiManager("Measure");

	
		meanInsideNucleus = getResult("Mean", 0);
		areaInsideNucleus = getResult("Area", 0);
		
		meanWholeCell = getResult("Mean", 1);
		areaWholeCell = getResult("Area", 1);
		
		meanCyto = getResult("Mean", 2);
		areaCyto = getResult("Area", 2);
	} else{
		if ((isNucleusSelection != -1) & (isCellSelection != -1)){
			
			meanInsideNucleus = 0;
			areaInsideNucleus = 0;
			
			meanWholeCell = 0;
			areaWholeCell = 0;
			
			meanCyto = 0;
			areaCyto = 0;
			Note3=" Nothing to measure";
		}else{
		if ((isNucleusSelection == -1) && (isCellSelection != -1)){
			roiManager("Select All");
			roiManager("Measure");
			meanInsideNucleus = 0;
			areaInsideNucleus = 0;
			
			meanWholeCell = getResult("Mean", 0);
			areaWholeCell = getResult("Area", 0);
			
			meanCyto = 0;
			areaCyto = 0;
			
			Note3=" No Nucleus to measure";
		}else{
		if ((isNucleusSelection != -1) && (isCellSelection == -1)){
			roiManager("Select All");
			roiManager("Measure");
			meanInsideNucleus = getResult("Mean", 0);
			areaInsideNucleus = getResult("Area", 0);
			
			meanWholeCell = 0;
			areaWholeCell = 0;
			
			meanCyto = 0;
			areaCyto = 0;
			Note3=" No cell to measure";
		}
		}
	}}
	
	roiManager("Select All");
	roiManager("Delete");
	
	//Counting nuclei if possible
	if(isNucleusSelection != -1){
		selectImage(newTitle+"-"+nucleusChannel);
		setThreshold(80, 65535, "raw");
		run("Watershed");
		run("Analyze Particles...", "size=50-Infinity clear add");
		nuccount=roiManager("count");
		roiManager("Select All");
		roiManager("Delete");
	}
	
	//Cell Shape descriptors
	if(isCellSelection != -1){
		print(newTitle);
		selectImage(newTitle+"-"+cellChannel);
		setThreshold(80, 65535, "raw");
		run("Watershed");
		run("Set Measurements...", "area mean shape display redirect=None decimal=3");
		run("Analyze Particles...", "size=50-Infinity display clear add include");
		cellcount=roiManager("count");
		
		// Analyze particles and include shape descriptors
		// Initialize the sum of circularity
		sumCircularity = 0;
		sumAR = 0;
		sumround = 0;
	
	    // Loop through each ROI to get the circularity
	    for (j = 0; j < cellcount; j++) {
	        roiManager("Select", j);
	        circularity = getResult("Circ.", j); 
	        AR = getResult("AR", j);
	        roundness = getResult("Round", j);
	        sumCircularity += circularity;
	        sumAR += AR;
	        sumround += roundness;
	    }
	
	    // Calculate the mean circularity
	    meanCircularity = sumCircularity / cellcount;
	    meanAR = sumAR / cellcount;
	    meanRound = sumround / cellcount;
	    roiManager("Select All");
		roiManager("Delete");
		run("Clear Results");
	}
	//Create result string
	resultsFilePath = Soutput+File.separator+"results_file.csv";
	Note=Note1+Note2+Note3;
	results = newTitle+","+areaInsideNucleus + "," +meanInsideNucleus + "," + areaWholeCell+ "," + meanWholeCell+ "," +areaCyto+ "," +meanCyto+","+nuccount+","+cellcount+","+meanCircularity+","+meanAR+","+meanRound+","+Note;
	
	//Variable cleanup
	newTitle="";
	areaInsideNucleus="";
	meanInsideNucleus="";
	areaWholeCell="";
	meanWholeCell="";
	areaCyto="";
	meanCyto="";
	cellcount="";
	Note1="";
	Note2="";
	Note3="";
	nuccount="";
	meanCircularity="";
	meanAR="";
	meanRound="";
	
	//Print results to file
	if (File.exists(resultsFilePath)) {
	    // Append the results
	    File.append(results, resultsFilePath);
	} else {
	    // Create the file and add the header and results
	    File.saveString(header +"\n"+ results+"\n", resultsFilePath);
	}
	
	run("Close All");
	run("Collect Garbage");	
}

waitForUser("Script is done");
