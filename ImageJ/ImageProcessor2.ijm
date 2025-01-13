/*
 * IMAGE PROCESSOR 
 * v.0.3
 * Macro to compare measure signal(s) in cell, nuclei, and cytoplasm
 * ----
 * Adrien Assié
 * Last updated 09/30/2024
 */


// Paranoid Cleanup
run("Clear Results");
if (roiManager("Count") > 0){
	roiManager("Select All");
	roiManager("Delete");
}

// Ask how many signal channels to measure
Dialog.create("Input Number");
Dialog.addNumber("Not counting nuclei and background channels,\nHow many signals to measure:", 1); // Set decimal places to 0 for integer input

Dialog.show(); // Show the dialog for user input

numSignals = Dialog.getNumber(); // Correct way to get the number after Dialog.show()

print(numSignals);

// Function to generate dynamic channel options
function generateChannelOptions(numSignals) {
    var totalChannels = 2 + numSignals; // Since you want it to start from C3
    var channelsArray = newArray();
    
    for (var i = 1; i <= totalChannels; i++) {
        channelsArray[i-1] = "C" + i;
    }
    
    return channelsArray;
}

// Function for Channel selection
function getChannelSelections(numSignals) {
    channelOptions = generateChannelOptions(numSignals); // Create the dynamic array of channel options

    Dialog.create("Select Channels");

    // Add choices for Nucleus and Background Channels using the dynamically generated channel options
    Dialog.addChoice("Nucleus Channel:", channelOptions, "C1");
    Dialog.addChoice("Cell Background Channel:", channelOptions, "C2");

    // Dynamically add choices for each signal channel based on the user input
    for (var i = 0; i < numSignals; i++) {
        Dialog.addChoice("Signal Channel " + (i + 1) + ":", channelOptions, "C"+(i+3));
    }

    Dialog.show(); // Show the dialog for channel selection

    // Get Nucleus and Cell Background channels
    nucleusChannel = Dialog.getChoice();
    cellChannel = Dialog.getChoice();

    // Get the selected signal channels and store them in an array
    var signalChannels = newArray();
    for (var i = 0; i < numSignals; i++) {
        signalChannels[i] = Dialog.getChoice();
    }

    // Return the values as an array: the two individual channels plus the array of signal channels
    tmparray=newArray(nucleusChannel, cellChannel);
    returnArray = Array.concat(tmparray,signalChannels);

    return returnArray; // Return the combined array
}

// Call the function and pass the number of signal channels to select
selections = getChannelSelections(numSignals);
nucleusChannel = replace(selections[0], "C", "000");
cellChannel = replace(selections[1], "C", "000");

//Debug
Array.print(selections);

// Handle multiple signal channels
signalChannels =  newArray(numSignals);

for (var i = 0; i < numSignals; i++) {
    signalChannels[i] = replace(selections[i+2], "C", "000");
}

//Debug
Array.print(signalChannels);

// Print the channels for verification
print("Nucleus Channel: " + nucleusChannel);
print("Cell Background Channel: " + cellChannel);
for (var i = 0; i < signalChannels.length; i++) {
    print("Signal Channel " + (i + 1) + ": " + signalChannels[i]);
}
 
// generate table header
header1 = "ID";
// Handle multiple signal channels
header2 =  newArray(numSignals*6);

for (var i = 0; i < numSignals; i++) {
    header2[6*i] = "Nucleus Signal - S"+ (i+1);
    header2[6*i+1] = "Whole Cell Signal - S"+ (i+1);
    header2[6*i+2] = "Cytoplasm Signal - S"+ (i+1);
    header2[6*i+3] = "Signal Size in Nucelus - S"+ (i+1);
    header2[6*i+4] = "Signal Size in Whole Cell - S"+ (i+1);
    header2[6*i+5] = "Signal Size in Cytoplasm - S"+ (i+1);
}

header3="# Nuclei, #Cells,Mean Circularity,Mean AR,Mean Roundness,Note";

// Convert the array into a comma-separated string
header = "";

for (i = 0; i < header2.length; i++) {
    if (i == 0) {
        header = header1 + "," + header2[i];  // No comma before the first element
    } else {
        header += "," + header2[i]; // Add comma before each subsequent element
    }
}
header=header+","+header3;

print(header);

// Load file
waitForUser("Please select the folder that contains your raw microscopy pictures");
wait(500);
RawInput = getDirectory("Please select the folder that contains your raw microscopy pictures");
list = getFileList(RawInput);  // Get all files from the directory

// Create an empty array to store only .nd2 files
nd2Files = newArray();

// Loop through the file list and filter .nd2 files
for (i = 0; i < list.length; i++) {
    if (endsWith(list[i], ".nd2")) {
        // Add .nd2 files to the new array
        nd2Files = Array.concat(nd2Files, list[i]);
    }
}

// Output folder
Soutput = RawInput + "Analysis_Output/";
File.makeDirectory(Soutput);

// Print the filtered .nd2 files
for (i = 0; i < nd2Files.length; i++) {
    print(nd2Files[i]);
}

list=nd2Files;

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
	print(newTitle);
	
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
		print("Found nuclei");'
	}else{
		isNucleusSelection=-1;
		Note1="No Nuclei detected";
		print(Note1);
	}
	//print(isNucleusSelection);

	//Process Cell channel
	selectImage(newTitle+"-"+cellChannel);
	setThreshold(95, 65535, "raw");
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
	print("Found cell background");
	}else{
		isCellSelection=-1;
		Note2=" No Cells detected";
		print(Note2);
	}
	//print(isCellSelection);
	if (roiManager("Count") ==2 ){
		//create a cytoplasm section
		print("Create a cytoplasm selection");
		roiManager("Select", newArray(0,1));
		roiManager("XOR");
		roiManager("Add");
		roiManager("Select", 2);
		roiManager("Rename", "Cytoplasm");
	}
	
	//Process signal channel
	chanelmeasures=newArray(signalChannels.length*6);
	for(c=0;c<signalChannels.length;c++){
		selectImage(newTitle+"-"+signalChannels[c]);
		//print(newTitle+"-"+signalChannels[c]);
		if ((isNucleusSelection != -1) & (isCellSelection != -1)){
			//print("Double section debug");
			roiManager("Select", newArray(0,1,2));
			roiManager("Measure");	
			meanInsideNucleus = getResult("Mean", 0);
			areaInsideNucleus = getResult("Area", 0);
			
			meanWholeCell = getResult("Mean", 1);
			areaWholeCell = getResult("Area", 1);
			
			meanCyto = getResult("Mean", 2);
			areaCyto = getResult("Area", 2);
		} else if ((isNucleusSelection == -1) & (isCellSelection == -1)){
			meanInsideNucleus = 0;
			areaInsideNucleus = 0;
			
			meanWholeCell = 0;
			areaWholeCell = 0;
				
			meanCyto = 0;
			areaCyto = 0;
			Note3=" Nothing to measure";
		}else if ((isNucleusSelection == -1) && (isCellSelection != -1)){
			roiManager("Select All");
			roiManager("Measure");
			meanInsideNucleus = 0;
			areaInsideNucleus = 0;
			
			meanWholeCell = getResult("Mean", 0);
			areaWholeCell = getResult("Area", 0);
			
			meanCyto = 0;
			areaCyto = 0;
			
			Note3=" No Nucleus to measure";
		}else if ((isNucleusSelection != -1) && (isCellSelection == -1)){
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
		chanelmeasures[6*c] = meanInsideNucleus;
	    chanelmeasures[6*c+1] = meanWholeCell;
	    chanelmeasures[6*c+2] = meanCyto;
	    chanelmeasures[6*c+3] = areaInsideNucleus;
	    chanelmeasures[6*c+4] = areaWholeCell;
	    chanelmeasures[6*c+5] = areaCyto;
	    
		//print(chanelmeasures[6*c+1]);
		meanInsideNucleus = "";
		areaInsideNucleus = "";
		meanWholeCell = "";
		areaWholeCell = "";
		meanCyto = "";
		areaCyto = "";
		run("Clear Results");
		}
	
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
		//print(nuccount);
	}
	
	//Cell Shape descriptors
	if(isCellSelection != -1){
		//print(newTitle);
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
	
	//Prep the values:
	
	// Convert the array into a comma-separated string
	var channelArray = "";
	for (k = 0; k < chanelmeasures.length; k++) {
	    if (k == 0) {
	        channelArray = ""+ chanelmeasures[k];  
	    } else {
	        channelArray += "," + chanelmeasures[k]; // Add comma before each subsequent element
	    }
	}
	
	// Concatenate the array values with the existing string
	results = newTitle+","+ channelArray +","+nuccount+","+cellcount+","+meanCircularity+","+meanAR+","+meanRound+","+Note;
	
	//Variable cleanup
	newTitle="";
	channelArray="";
	chanelmeasures="";
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

