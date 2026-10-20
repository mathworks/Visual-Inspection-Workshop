%[text] # Detect, Localize, and Measure Industrial Parts with Shape Matching
%[text] This example shows a workflow for detecting metal parts with shape-based matching and then converting those detections into calibrated, real-world measurements:
%[text] 1. Leveraging **image rectification** with known camera calibration to return measurements directly in millimeters.
%[text] 2. **Shape models** to recover the pose of each part despite multiple instances and placements (e.g. translation, orientation).
%[text] 3. **Edge-aware measurement tools** such as `uicaliper`, `uifitangle,` and `uifitcircle` snap to the local edges in the search image instead of reusing template points. \
%%
%[text:tableOfContents]{"heading":"Table of Contents"}
%%
%[text] ## 1. Data Setup
%[text] ### Load Data and Calibrated World Coordinates
%[text] The MetalEdge data set already contains rectified images of three part classes: a flat plate, a notched plate, and a plate with holes. The checkerboard image and saved camera parameters provide the mapping from pixels into millimeters for the corresponding imaging setup.
%[text] Load dataset if it hasn't already been loaded.
if isfolder("MetalEdge")
    disp("The MetalEdge dataset already exists in this directory.");
else
    zipFile = matlab.internal.examples.downloadSupportFile("visualinspection","data/MetalEdge.zip");
    unzip(zipFile,pwd);
end
%[text] Use `imageDatastore` to handle and apply operations to the image dataset.
imageDir = fullfile("MetalEdge","searchImagesRectified");
searchImageDatastore = imageDatastore(imageDir);
[~,filenamesstr,~] = fileparts(string(searchImageDatastore.Files));
%[text] Apply known calibration and compute rectification map we can apply to all subsequent images taken with the same camera setup.
calibrationData = load("AdditionalDataFiles/cameraParamsCorrectedScale.mat");
checkerboardIm = imread("AdditionalDataFiles/CheckerboardImage.jpg");
[imagePoints,~] = detectCheckerboardPoints(checkerboardIm);
mmPerInch = 25.4; % Known conversion factor
worldPoints = calibrationData.cameraParams.WorldPoints * mmPerInch;
camExtrinsics = estimateExtrinsics(imagePoints,worldPoints,calibrationData.cameraParams.Intrinsics);
[~,Rout] = imageToWorldPlane(checkerboardIm,calibrationData.cameraParams.Intrinsics,camExtrinsics);
rectifyMap = imageToWorldPlaneMapping(calibrationData.cameraParams.Intrinsics,camExtrinsics);
%%
%[text] ### Preview Rectified Search Data Images
montage(searchImageDatastore)
%%
%[text] Browse individual images within the dataset.
imageIndex = 12; %[control:spinner:72f6]{"position":[14,16]}
imshow(readimage(searchImageDatastore,imageIndex));
title(filenamesstr(imageIndex))
%%
%[text] ## 2. Create Shape Models for the Three Part Classes
%[text] Load our three reference images. Each model is learned from a single template image and then reused across the search set.
templateDir = fullfile("MetalEdge","TemplatesRectified");
templateFiles = struct( ...
    FlatPlate=fullfile(templateDir,"snapshot18.png"), ...
    NotchPlate=fullfile(templateDir,"snapshot14.png"), ...
    HolesPlate=fullfile(templateDir,"snapshot15.png"));
%[text] Interactively crop the areas of interest for each plate type. (If not cropped, the full template image will be used instead.)
cropNewTemplate = false; %[control:checkbox:0c1e]{"position":[19,24]}
flatPlate = selectTemplate(templateFiles.FlatPlate,"FlatPlate",cropNewTemplate);
notchPlate = selectTemplate(templateFiles.NotchPlate,"NotchPlate",cropNewTemplate);
holesPlate = selectTemplate(templateFiles.HolesPlate,"HolesPlate",cropNewTemplate);
%[text] Generate the template based on the cropped region. 
modelFlatPlate = shapemodel(flatPlate,ClassName="FlatPlate",GradientThreshold=[0.03 0.06]);
modelNotchPlate = shapemodel(notchPlate,ClassName="NotchPlate",GradientThreshold=[0.03 0.06]);
modelHolesPlate = shapemodel(holesPlate,ClassName="HolesPlate",GradientThreshold=[0.03 0.06]);
%%
%[text] Visualize the resulting templates.
%[text] %[text:anchor:TMP_1942] **Flat Plate Model**
show(modelFlatPlate);
%[text] **Notch Plate Model**
show(modelNotchPlate);
%[text] **Holes Plate Model**
show(modelHolesPlate);
%%
%[text] ## 3. Define Measurement Seeds on the Template Images
%[text] Each measurement is defined once on a calibrated template image, stored relative to the corresponding shape-model origin, and then transferred to every detected instance for a corresponding new measurement.
%[text] ### Flat Plate - Width Measurement
newFig = figure(Visible="on"); newViewer = viewer2d(newFig); % Put figure in separate window
%[text] Plot the rectified image and set the uicaliper reference position to measure the width of the flat plate template.
hFlatPlateTemplate = imageshow(flatPlate,Transformation=Rout,Parent=newViewer);
hFlatPlateTemplate.Parent.SpatialUnits = "mm";
hFlatPlateTemplate.Parent.Title = "Place the uicaliper and adjust as needed. Click the Done button when done.";

if cropNewTemplate % If templates were cropped, use corresponding cropped images.
    mycaliper = uicaliper(hFlatPlateTemplate,Width=20,GradientThreshold=0.05,EdgeTransition="both");
    waitForInteractiveClick(newFig);
%[text] Store the caliper position in world units relative to the shape template.
    flatPlateWidthReferencePosition = mycaliper.Position;
    close(newFig)
else % If templates weren't manually cropped, default to full template image reference position.
    flatPlateWidthReferencePosition = [35.3587 81.4320; 157.3548 52.6831];
    uicaliper(hFlatPlateTemplate,Position=flatPlateWidthReferencePosition,...
        Width=20,GradientThreshold=0.05,EdgeTransition="both");
end

flatPlateReference = createPointReference(modelFlatPlate,Rout,flatPlateWidthReferencePosition);
%%
%[text] ### Notch Plate - Angle Measurement
%[text] Plot the rectified image and set the uifitangle position to measure the angle of the upper right corner of the notch plate template.
newFig = figure(Visible="on"); newViewer = viewer2d(newFig); % Put figure in separate window
hNotchPlateTemplate = imageshow(notchPlate,Transformation=Rout,Parent=newViewer);
hNotchPlateTemplate.Parent.SpatialUnits = "mm";
hNotchPlateTemplate.Parent.Title = "Place angle with 3 points: (1) Vertex (2) 1st Ray Point (3) 2rd Ray Point.";

if cropNewTemplate % If templates were cropped, use corresponding cropped images.
    myangle = uifitangle(hNotchPlateTemplate,Snap=true); 
    waitForInteractiveClick(newFig);
%[text] Store the `uifitangle` position in world units relative to the shape template.
    notchPlateAngleReferencePosition = myangle.Position;
    close(newFig)
else % If templates weren't manually cropped, default to full template image reference position.
    notchPlateAngleReferencePosition = [ ...
        121.9886   88.2263
        144.1233   36.2013
        122.5412  -17.7993];
    uifitangle(hNotchPlateTemplate,Position=notchPlateAngleReferencePosition,Snap=true);
end
notchPlateReference = createPointReference(modelNotchPlate,Rout,notchPlateAngleReferencePosition);
%%
%[text] ### Holes Plate - Radii Measurement
%[text] For the holes plate, the initial circle positions can be fully automated using the `imfindcircles` functionality. 
[centers,radii] = imfindcircles(holesPlate,[15 50],ObjectPolarity="dark",Sensitivity=0.85);
%[text] Save the circle locations in world units relative to the shape template.
radiusWorld = radii * Rout.PixelExtentInWorldX;
[worldCentersX,worldCentersY] = intrinsicToWorld(Rout,centers(:,1),centers(:,2));
holesPlateCentersInMM = [worldCentersX worldCentersY];
holesPlateReference = createCircleReference(modelHolesPlate,Rout,holesPlateCentersInMM,radiusWorld);
%[text] Visualize results, and measure the circle radii using `uifitcircle`, which can auto-snap to the circle edges. 
hHolesPlateTemplate = imageshow(holesPlate,Transformation=Rout);
hHolesPlateTemplate.Parent.SpatialUnits = "mm";
for holeIdx = 1:size(holesPlateReference.CircleTemplatePositions,1)
    uifitcircle(hHolesPlateTemplate,Position=holesPlateReference.CircleTemplatePositions(holeIdx,:),Snap=true);
end
%%
%[text] ## 4. Shape Match and Transfer Measurements to New Image
%[text] ### Transfer a Caliper Measurement and Measure Flat Plate Width in Millimeters
%[text] The flat-plate width is the simplest case: use `matchshape` to recover pose, transfer the reference caliper, and measure in millimeters on the rectified image.
searchImage = imread(fullfile(imageDir,filenamesstr(1)+".png")); %[control:dropdown:44b0]{"position":[40,55]}
flatPlateMatches = matchshape(modelFlatPlate,searchImage,MaxMatches=5,ScoreThreshold=0.7);
flatPlateDemoResults = measureFlatPlateWidths(searchImage,Rout,modelFlatPlate,flatPlateReference);

hFlatPlateSearchMeasurement = imageshow(searchImage,Transformation=Rout);
hFlatPlateSearchMeasurement.Parent.SpatialUnits = "mm";
hFlatPlateSearchMeasurement.Parent.Title = "Match(es) Found: " + string(height(flatPlateMatches));
for matchIdx = 1:height(flatPlateMatches)
    tform = convertMatchTransformToWorld(flatPlateMatches(matchIdx).ModelOriginTransformation,Rout);
    caliperPosition = transformPointsForward(tform,flatPlateReference.RelativeToModelOrigin);
    uicaliper(hFlatPlateSearchMeasurement,Position=caliperPosition,...
        Width=20,GradientThreshold=0.05,EdgeTransition="both");
end
disp(flatPlateDemoResults);
%%
%[text] ### Transfer an Angle Seed and Snap to the Local Edges for Notch Plate Corner
%[text] The `uifitangle` reference position (three points defining vertex, first ray point, and second ray point) can similarly be transferred and act as initialization points for the automated edge snapping algorithm.
searchImage = imread(fullfile(imageDir,filenamesstr(34)+".png")); %[control:dropdown:96de]{"position":[40,56]}
notchPlateMatches = matchshape(modelNotchPlate,searchImage,MaxMatches=5,ScoreThreshold=0.7);

hNotchPlateSearchMeasurement = imageshow(searchImage,Transformation=Rout);
hNotchPlateSearchMeasurement.Parent.SpatialUnits = "mm";
hNotchPlateSearchMeasurement.Parent.Title = "Match(es) Found: " + string(height(notchPlateMatches));
for matchIdx = 1:height(notchPlateMatches)
    tform = convertMatchTransformToWorld(notchPlateMatches(matchIdx).ModelOriginTransformation,Rout);
    anglePosition = transformPointsForward(tform,notchPlateReference.RelativeToModelOrigin);
    uifitangle(hNotchPlateSearchMeasurement,Position=anglePosition,Snap=true);
end
%%
%[text] ### Transfer Circle Seeds and Snap to Hole Boundaries for Holes Plate
%[text] For the plate with holes, the reference circle centers and radii are transferred from the template pose to the detected pose. `uifitcircle` then refines each hole directly from the edge data in the search image.
searchImage = imread(fullfile(imageDir,filenamesstr(6)+".png")); %[control:dropdown:8ab2]{"position":[40,55]}
holesPlateMatches = matchshape(modelHolesPlate,searchImage,MaxMatches=5,ScoreThreshold=0.7);

hHolesPlateSearchMeasurement = imageshow(searchImage,Transformation=Rout);
hHolesPlateSearchMeasurement.Parent.SpatialUnits = "mm";
hHolesPlateSearchMeasurement.Parent.Title = "Match(es) Found: " + string(height(holesPlateMatches));
for matchIdx = 1:height(holesPlateMatches)
    tform = convertMatchTransformToWorld(holesPlateMatches(matchIdx).ModelOriginTransformation,Rout);
    circleCenters = transformPointsForward(tform,holesPlateReference.CircleCentersRelativeToModelOrigin);
    circleRadii = transformCircleRadii(tform,...
        holesPlateReference.CircleCentersRelativeToModelOrigin,...
        holesPlateReference.CircleRadiiInMM);
    for holeIdx = 1:size(circleCenters,1)
        uifitcircle(hHolesPlateSearchMeasurement,Position=[circleCenters(holeIdx,:),circleRadii(holeIdx)],Snap=true);
    end
end
%%
%[text] ## 5. Run Batch Measurements Across the Search Set
%[text] We can now adapt the algorithms used above for batch-processing. 
%[text] The helper function `measureFlatPlateWidths` uses the `caliper` function (`uicaliper` function's programmatic counterpart). 
flatPlateMeasurementResults = measureDatastore(searchImageDatastore,filenamesstr,...
    @(im) measureFlatPlateWidths(im,Rout,modelFlatPlate,flatPlateReference));
plotMeasurementSummary(flatPlateMeasurementResults.WidthInMM,...
    "Detected Flat Plate","Width (mm)","Flat Plate Width Measurements");
%[text] Similarly, the helper function `measureNotchPlateAngles` uses the `fitangle` function instead of `uifitangle`.
notchPlateMeasurementResults = measureDatastore(searchImageDatastore,filenamesstr,...
    @(im) measureNotchPlateAngles(im,Rout,modelNotchPlate,notchPlateReference));
plotMeasurementSummary(notchPlateMeasurementResults.AngleInDegrees,...
    "Detected Notched Plate","Angle (degrees)","Notched Plate Angle Measurements");
%[text] Finally, `measureHolesPlateDiameters` utilizes the `fitcircle` function instead of `uifitcircle`.
holesPlateMeasurementResults = measureDatastore(searchImageDatastore,filenamesstr,...
    @(im) measureHolesPlateDiameters(im,Rout,modelHolesPlate,holesPlateReference,0.7));

smallHoleMeasurements = holesPlateMeasurementResults(holesPlateMeasurementResults.HoleType=="Small",:);
largeHoleMeasurements = holesPlateMeasurementResults(holesPlateMeasurementResults.HoleType=="Large",:);

plotMeasurementSummary(smallHoleMeasurements.RadiusInMM,...
    "Detected Small Hole","Radius (mm)","Small-Hole Radius Measurements");
plotMeasurementSummary(largeHoleMeasurements.RadiusInMM,...
    "Detected Large Hole","Radius (mm)","Large-Hole Radius Measurements");
%%
%[text] ## Bonus: Match Multiple Part Classes in One Search Image
%[text] A single search image can be tested against all three models, which is useful when the scene can contain different part classes at once.
multiClassImage = imread(fullfile(imageDir,"snapshot125.png"));

modelsToSearch = [modelNotchPlate,modelHolesPlate,modelFlatPlate];
matches = matchshape(modelsToSearch,multiClassImage,MaxMatches=4,ScoreThreshold=0.7);
showmatches(modelsToSearch,matches,multiClassImage,DisplayClassName=true);
%%
%[text] ## Bonus: Circle Fitting Still Works with Partial Occlusion
%[text] The transferred circle seeds still provide reliable initialization when part of a hole boundary is obscured.
%[text] In all previous sections, we used 0.7 as the score threshold for `matchshape`, but for occluded shapes where less of a template is visible, we may want to decrease this value.
sT = 0.4; % Score Threshold %[control:slider:2297]{"position":[6,9]}
occludedImage = imread(fullfile(imageDir,"snapshot138.png"));
occludedHoleMatches = matchshape(modelHolesPlate,occludedImage,MaxMatches=5,ScoreThreshold=sT);
%[text] View measurement results.
showOccludedImage = imageshow(occludedImage,Transformation=Rout);
showOccludedImage.Parent.SpatialUnits = "mm";
showOccludedImage.Parent.Title = "Match(es) Found: " + string(height(occludedHoleMatches));
numLabels = height(occludedHoleMatches) * size(holesPlateReference.CircleCentersRelativeToModelOrigin,1);
labelCentersInMM = zeros(numLabels,2);
labelStrings = cell(numLabels,1);
labelCount = 0;

for matchIdx = 1:height(occludedHoleMatches)
    tform = convertMatchTransformToWorld(occludedHoleMatches(matchIdx).ModelOriginTransformation,Rout);
    circleCenters = transformPointsForward(tform,holesPlateReference.CircleCentersRelativeToModelOrigin);
    circleRadii = transformCircleRadii(tform,holesPlateReference.CircleCentersRelativeToModelOrigin,holesPlateReference.CircleRadiiInMM);
    for holeIdx = 1:size(circleCenters,1)
        fittedCircle = uifitcircle(showOccludedImage,Position=[circleCenters(holeIdx,:),circleRadii(holeIdx)],Snap=true);
        labelCount = labelCount + 1;
        labelCentersInMM(labelCount,:) = fittedCircle.Position(1:2);
        labelStrings{labelCount,1} = num2str(holeIdx);
    end
end
%%
if cropNewTemplate
    %#ok<*UNRCH>
end
%%
%[text] *Copyright 2026 The MathWorks, Inc.*

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":20}
%---
%[control:spinner:72f6]
%   data: {"defaultValue":1,"label":"Spinner","max":38,"min":1,"run":"Section","runOn":"ValueChanging","step":1}
%---
%[control:checkbox:0c1e]
%   data: {"defaultValue":false,"label":"drawNewTemplate","run":"Section"}
%---
%[control:dropdown:44b0]
%   data: {"defaultValue":"filenamesstr(5)","itemLabels":["snapshot111","snapshot112","snapshot113","snapshot114","snapshot115","snapshot116","snapshot117","snapshot118","snapshot119","snapshot120","snapshot121","snapshot122","snapshot123","snapshot124","snapshot125","snapshot126","snapshot127","snapshot128","snapshot129","snapshot130","snapshot131","snapshot132","snapshot133","snapshot134","snapshot135","snapshot136","snapshot137","snapshot138","snapshot139","snapshot140","snapshot141","snapshot142","snapshot143","snapshot144","snapshot145","snapshot146","snapshot147","snapshot148"],"items":["filenamesstr(1)","filenamesstr(2)","filenamesstr(3)","filenamesstr(4)","filenamesstr(5)","filenamesstr(6)","filenamesstr(7)","filenamesstr(8)","filenamesstr(9)","filenamesstr(10)","filenamesstr(11)","filenamesstr(12)","filenamesstr(13)","filenamesstr(14)","filenamesstr(15)","filenamesstr(16)","filenamesstr(17)","filenamesstr(18)","filenamesstr(19)","filenamesstr(20)","filenamesstr(21)","filenamesstr(22)","filenamesstr(23)","filenamesstr(24)","filenamesstr(25)","filenamesstr(26)","filenamesstr(27)","filenamesstr(28)","filenamesstr(29)","filenamesstr(30)","filenamesstr(31)","filenamesstr(32)","filenamesstr(33)","filenamesstr(34)","filenamesstr(35)","filenamesstr(36)","filenamesstr(37)","filenamesstr(38)"],"itemsVariable":"filenamesstr","label":"Search image","run":"Section"}
%---
%[control:dropdown:96de]
%   data: {"defaultValue":"filenamesstr(29)","itemLabels":["snapshot111","snapshot112","snapshot113","snapshot114","snapshot115","snapshot116","snapshot117","snapshot118","snapshot119","snapshot120","snapshot121","snapshot122","snapshot123","snapshot124","snapshot125","snapshot126","snapshot127","snapshot128","snapshot129","snapshot130","snapshot131","snapshot132","snapshot133","snapshot134","snapshot135","snapshot136","snapshot137","snapshot138","snapshot139","snapshot140","snapshot141","snapshot142","snapshot143","snapshot144","snapshot145","snapshot146","snapshot147","snapshot148"],"items":["filenamesstr(1)","filenamesstr(2)","filenamesstr(3)","filenamesstr(4)","filenamesstr(5)","filenamesstr(6)","filenamesstr(7)","filenamesstr(8)","filenamesstr(9)","filenamesstr(10)","filenamesstr(11)","filenamesstr(12)","filenamesstr(13)","filenamesstr(14)","filenamesstr(15)","filenamesstr(16)","filenamesstr(17)","filenamesstr(18)","filenamesstr(19)","filenamesstr(20)","filenamesstr(21)","filenamesstr(22)","filenamesstr(23)","filenamesstr(24)","filenamesstr(25)","filenamesstr(26)","filenamesstr(27)","filenamesstr(28)","filenamesstr(29)","filenamesstr(30)","filenamesstr(31)","filenamesstr(32)","filenamesstr(33)","filenamesstr(34)","filenamesstr(35)","filenamesstr(36)","filenamesstr(37)","filenamesstr(38)"],"itemsVariable":"filenamesstr","label":"Search image","run":"Section"}
%---
%[control:dropdown:8ab2]
%   data: {"defaultValue":"filenamesstr(29)","itemLabels":["snapshot111","snapshot112","snapshot113","snapshot114","snapshot115","snapshot116","snapshot117","snapshot118","snapshot119","snapshot120","snapshot121","snapshot122","snapshot123","snapshot124","snapshot125","snapshot126","snapshot127","snapshot128","snapshot129","snapshot130","snapshot131","snapshot132","snapshot133","snapshot134","snapshot135","snapshot136","snapshot137","snapshot138","snapshot139","snapshot140","snapshot141","snapshot142","snapshot143","snapshot144","snapshot145","snapshot146","snapshot147","snapshot148"],"items":["filenamesstr(1)","filenamesstr(2)","filenamesstr(3)","filenamesstr(4)","filenamesstr(5)","filenamesstr(6)","filenamesstr(7)","filenamesstr(8)","filenamesstr(9)","filenamesstr(10)","filenamesstr(11)","filenamesstr(12)","filenamesstr(13)","filenamesstr(14)","filenamesstr(15)","filenamesstr(16)","filenamesstr(17)","filenamesstr(18)","filenamesstr(19)","filenamesstr(20)","filenamesstr(21)","filenamesstr(22)","filenamesstr(23)","filenamesstr(24)","filenamesstr(25)","filenamesstr(26)","filenamesstr(27)","filenamesstr(28)","filenamesstr(29)","filenamesstr(30)","filenamesstr(31)","filenamesstr(32)","filenamesstr(33)","filenamesstr(34)","filenamesstr(35)","filenamesstr(36)","filenamesstr(37)","filenamesstr(38)"],"itemsVariable":"filenamesstr","label":"Search image","run":"Section"}
%---
%[control:slider:2297]
%   data: {"defaultValue":0.4,"label":"sT","max":1,"min":0,"run":"Section","runOn":"ValueChanging","step":0.1}
%---
