
# ImageJ macros

Macro for batch processing files using [ImageJ](https://imagej.net/Welcome) or [Fiji](https://imagej.net/Fiji)

## SignalRatio.ijm

This is a macro which will process a batch of single-channel fluorescent pictures and compare the specific fluorescence (intense values) to the overall general fluorescence.

The script goes as follow:
  1. Convert the color channel to 16bit
  2. (optional) Set a scale
  3. Get the total area of gray pixels using a low-intensity threshold value (get as much as fluorescence signal as possible)
  4. Get the specific area of high pixel intensity using a high threshold value (get only the specific signal)
  5. Calculate the signal ratio (High/low*100)
  6. Export a `Result.csv` file in the output folder

**How to Run:**
Get the SignalRatio.ijm file from GitHub.
In Image/Fiji go to `Plugins>Macro>edit`, select the file and click on run.
For some reason, it doesn't want to run with the run option but run fine through the editor.

**What to do before running the macro:**
1. Select an image or two with a positive signal
2. Transform the image into a 16bit grayscale through `Image>Type>16-bit`
3. Adjust the threshold through `Image>Adjust>Threshold` and select a window of value that will highlight most of the green signal with a minimum of noise.
4. copy those value on in the command `setThreshold(x, y);` on line 41
5. Repeat the threshold adjustment to have only your positive (peak) signal and change the x,y value in `setThreshold(x, y);` on line 49.
6. (Optional): check that the peak values are not overlapping too much with a negative control

Optional: If you know the scale of your picture (x pixel is y nm) you can edit line 36:
`run("Set Scale...", "distance=x known=y unit=pixel");`
And edit how many pixels corresponds to how many units, this will adjust the right area measurement.
Default is pixel size.

**Output:**
The macro output for each files three lines, the first gives the General values, then the Peak and finally the ratio on the third line.
Output files as the following format:

 ````
 ,Label,Area,Mean,Min,Max,MinThr,MaxThr,Type,SR
1,hfd d9 dc3-1.tif,834593,12.651,8,85,8,65535,General,0.000
2,hfd d9 dc3-1.tif,12077,56.020,40,85,40,65535,Peak,0.000
3,hfd d9 dc3.tif,0,0.000,0,0,0,0,Signal Ratio,1.447
````
**Column details:**
- First column: Column id
- `Label`: file name
- `Area`: Area in pixel (or in square unit if you adjusted the script)
- `Mean`: Mean pixel intensity in the area
- `Min`: Min pixel intensity in the area
- `Max`: Max pixel intensity in the area
- `MinThr`: Min threshold value used
- `MaxThr`: Max threshold value used
- `Type`: What Type of measurment, will be `General`,`Peak` or `Signal Ratio`
- `SR`: Signal Ratio value in percent

### Want to run this manually?
You can run the script manually following these steps:
1. Set picture scale if needed through `Analyze>Set scale`
2. Transform you color picture in a grayscale 16-bit by clicking on `Image>Type>16-bit`
3. Set the measurement information you need by clicking on `Analyze>Set Measurements`
    - You'll want to tick:  `Area`,`Mean gray value`,`Min & Max gray value`, `Limit to threshold` and `Display label`
4. Adjust the threshold through `Image>Adjust>Threshold` and select a window of value that will highlight most of the green signal with a minimum of noise.
5. Click on `Analyze>Measurement` or press `command + m`
6. Repeat the threshold adjustment to have only your positive (peak) signal 
7. Click on `Analyze>Measurement` or press `command + m`
8. Repeat for all images
9. Once done you can export the result window by `left-click` and `Select all` then copy paste the result in an excel file.

**Optional:** You don't want to select the whole image. In this case, you can use the lasso tool and select your Region of Interest before `Step 4`. 
