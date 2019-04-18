/*
 * Macro to compare background fluorescence area to peak fluorescence area
 * ----
 * Adrien Assié
 * Last updated 04/18/2019
 */

#@ File (label = "Input directory", style = "directory") input
#@ File (label = "Output directory", style = "directory") output
#@ String (label = "File suffix", value = ".tif") suffix

print("Starting Macro");  
processFolder(input);

// function to scan folders/subfolders/files to find files with correct suffix
function processFolder(input) {
	list = getFileList(input);
	list = Array.sort(list);
	for (i = 0; i < list.length; i++) {
		if(File.isDirectory(input + File.separator + list[i]))
			processFolder(input + File.separator + list[i]);
		if(endsWith(list[i], suffix))
			processFile(input, output, list[i]);
	}
}

function processFile(input, output, file) {
	// Do the processing here by adding your own code.
	// Leave the print statements until things work, then remove them.
	print("Processing: " + input + File.separator + file);
	open(input + File.separator + file);
	//Convert to 16 bit gray scale
	run("16-bit");
	//Set scale on the picture; default is pixel count
	run("Set Scale...", "distance=1 known=1 unit=pixel");
	//Set measurment
	run("Set Measurements...", "area mean min limit display redirect=None decimal=3");
	//Thresolding general signal of fluorescence
	setAutoThreshold("Default dark");
	setThreshold(8, 65535);
	run("Measure");
	headings = split(String.getResultsHeadings);
	areaGeneral=getResult(headings[1]);
	j=nResults-1;
	setResult("Type", j, "General");
	updateResults();
	//Thresholding Peak signal
	setThreshold(40, 65535);
	run("Measure");
	areaPeak=getResult(headings[1]);
	j=nResults-1;
	setResult("Type", j, "Peak");
	updateResults();
	//Calculating Ratio Peak/General signal
	ratiosignal=(areaPeak/areaGeneral)*100;
	setResult("Type", nResults, "Signal Ratio");
	j=nResults-1;
	setResult("Label", j, list[i]);
	setResult("SR", j, ratiosignal);
	updateResults();
	print("Signal ratio : " + ratiosignal + "%");
	close();
}

selectWindow("Log"); 
saveAs("Results", output+"/Results.csv");
print("Saving results in: " +output+"/Results.csv");
print("---")
print("Macro done, have a nice day!");
exit()
