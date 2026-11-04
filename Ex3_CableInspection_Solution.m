%[text] # Demo 3 - Cable Connector Visual Inspection
%[text] This exercise builds a hybrid visual inspection pipeline for cable connectors. A rule-based locator finds each part and normalizes its pose before a PatchCore anomaly detector looks for defects.
%[text] 1. Load labeled images and preview the classes.
%[text] 2. Locate the connector with shape matching.
%[text] 3. Crop and rotate the connector into a consistent ROI.
%[text] 4. Detect defects with a PatchCore anomaly detector. \
%[text:tableOfContents]{"heading":"Table of Contents"}
FolderDir = "CableInspection";
dataDir = fullfile(FolderDir, "Data");
cropDataDir = fullfile(FolderDir,"Data_Crops");
unzip(dataDir+".zip", FolderDir);
unzip(cropDataDir+".zip", FolderDir);
addpath(genpath(FolderDir))

rng(0)
normalClass = "good";
defectClasses = ["broken", "crossed"];
allClasses = [normalClass, defectClasses];
%%
%[text] ## 1. Load and preview the labeled image data
%[text] Use [imageDatastore](matlab:doc('imageDatastore')) to load images from class folders. The folder names become labels, which lets us quickly count the data and preview one image from each class.
%[text] IncludeSubfolders=true includes all three class folders, and LabelSource="foldernames" assigns each image its good, broken, or crossed label.
imds = imageDatastore(dataDir, IncludeSubfolders=true, ...
    LabelSource="foldernames");

countEachLabel(imds)

previewFiles = [
    randomImageFile(dataDir, "good")
    randomImageFile(dataDir, "broken")
    randomImageFile(dataDir, "crossed")];

figure(Name="Raw connector images", Position=[100 100 1100 420])
tiledlayout(1, 3, Padding="compact", TileSpacing="compact")
for k = 1:numel(previewFiles)
    nexttile
    imshow(imread(previewFiles(k)), [])
    className = string(imds.Labels(find(string(imds.Files) == previewFiles(k), 1)));
    title(className)
end
%%
%[text] ## 2. Create or load a shape model
%[text] A [shapemodel](matlab:doc('shapemodel')) learns the connector outline from a template image. The model acts as the part locator and returns both a matching score and a rotated bounding box for the detected connector pose.
%[text] Set drawNewTemplate to true if you want to draw the template rectangle interactively. Keep it false to use the helper that crops the pre-made template.
%[text] A tight rectangle around the plastic housing keeps the template focused on the connector shape and limits background detail that could affect matching.
drawNewTemplate = false; %[control:checkbox:2a70]{"position":[19,24]}

templateImage = imread(fullfile(dataDir, "good", "img0.png"));

if isequal(drawNewTemplate, true)
    figure(Name="Draw connector template")
    imshow(templateImage, [])
    title("Draw a rectangle around the connector, then double-click it")

    templateBox = drawrectangle(Color="green");
    wait(templateBox)
    template = imcrop(im2gray(templateImage), templateBox.Position);
    close(gcf)
else
    template = cropConnectorTemplate(templateImage);
end

fixtureModel = shapemodel(template, RotationRange=[-60 60], ...
    ClassName="Connector");

figure(Name="Shape-matching template", Position=[100 100 900 420])
tiledlayout(1, 2, Padding="compact", TileSpacing="compact")
nexttile
imshow(templateImage, [])
title("Source image")
nexttile
imshow(template, [])
title("Connector template")
%%
%[text] ## 3. Locate connectors with shape matching
%[text] Use [matchshape](matlab:doc('matchshape')) to search for the connector template in each raw image. The matching score threshold controls how confident the match must be before the part is accepted.
%[text] Lowering the threshold accepts weaker shape matches; raising it can reject valid connectors. This score measures part localization, not whether the connector is defective.
matchingScoreThreshold = 0.5; %[control:slider:1e68]{"position":[26,29]}

figure(Name="Shape matching results", Position=[100 100 1100 420])
tiledlayout(1, 3, Padding="compact", TileSpacing="compact")
for k = 1:numel(previewFiles)
    I = imread(previewFiles(k));
    matchImage = imadjust(im2gray(I));
    matches = matchshape(fixtureModel, matchImage, ...
        MaxMatches=1, ScoreThreshold=matchingScoreThreshold);

    nexttile
    imshow(I, [])
    if isempty(matches)
        title("No matches, Lower the threshold")
    else
        hold on
        drawRotatedBox(matches(1).RotatedBoundingBox, "g", 2)
        hold off
        className = string(imds.Labels(find(string(imds.Files) == previewFiles(k), 1)));
        matchScore = sprintf(", Matching score %.3f", matches(1).Score);
        title(className + matchScore)
    end
end
%%
%[text] ## 4. Crop and align connector ROIs
%[text] The anomaly detector expects every connector in the same pose. The ROI helper uses the rotated bounding box from shape matching to sample a 256-by-512 upright ROI directly from the original image.
%[text] The same alignment and ROI extraction operation was already applied to every image in Data\_Crops. Those normalized crops are the images used to train and evaluate PatchCore.
figure(Name="Normalized connector ROIs", Position=[100 100 1100 420])
tiledlayout(1, 3, Padding="compact", TileSpacing="compact")
for k = 1:numel(previewFiles)
    I = imread(previewFiles(k));
    matchImage = imadjust(im2gray(I));
    matches = matchshape(fixtureModel, matchImage, ...
        MaxMatches=1, ScoreThreshold=matchingScoreThreshold);

    nexttile
    if isempty(matches)
        imshow(I, [])
        title("No matches, Lower the threshold")
    else
        roi = cropCableConnectorROI(I, matches(1).RotatedBoundingBox);
        imshow(roi, [])
        className = string(imds.Labels(find(string(imds.Files) == previewFiles(k), 1)));
        title(className + ", cropped ROI")
    end
end
%%
%[text] ## 5. Train or load a PatchCore anomaly detector
%[text] Create a [patchCoreAnomalyDetector](matlab:doc('patchCoreAnomalyDetector')) and train it with [trainPatchCoreAnomalyDetector](matlab:doc('trainPatchCoreAnomalyDetector')). PatchCore learns from normal connector ROIs and flags images whose features look unusual.
%[text] For the workshop, trainNewDetector lets you choose between live training and loading the pre-trained detector so the rest of the exercise can run quickly.
%[text] Build the training datastore from the aligned crops so the detector learns connector appearance with less variation from position and rotation. Folder names provide the class labels for splitting and evaluation.
roiImds = imageDatastore(cropDataDir, ...
    IncludeSubfolders=true, LabelSource="foldernames");
%[text] Use only good images for training. The calibration and test sets include both normal and defective examples: calibration selects the decision threshold, while the separate test set measures performance on held-out images.
[dsTrain, dsCal, dsTest] = splitAnomalyData(roiImds, defectClasses);
fprintf("Training images: %d\n", numel(dsTrain.Files))
fprintf("Calibration images: %d\n", numel(dsCal.Files))
fprintf("Test images: %d\n", numel(dsTest.Files))
%%
%[text] Set trainNewDetector to true to train PatchCore from the cropped ROIs. Keep it false to load the pre-made detector and continue quickly.
%[text] The resnet18 backbone extracts image features. CompressionRatio=0.1 with random subsampling keeps a smaller feature memory for inference, trading memory size against the detail retained from normal training images.
trainNewDetector = false; %[control:checkbox:9bf4]{"position":[20,25]}

if isequal(trainNewDetector, true)
    detector = patchCoreAnomalyDetector(Backbone="resnet18");
    detector = trainPatchCoreAnomalyDetector(dsTrain, detector, ...
        CompressionRatio=0.1, SubsamplingStrategy="random");
else
    detectorModelFile = fullfile("models", "connectorAnomalyDetector_patchCore.mat");
    load(detectorModelFile, "detector")
end
%%
%[text] ## 6. Calibrate the anomaly score threshold
%[text] Use the [predict](matlab:doc('predict')) method to compute anomaly scores on the calibration set. The first histogram lets you inspect the score separation and try a manual threshold.
%[text] Higher scores indicate stronger departures from the learned normal appearance. Keep the scores paired with the calibration labels to compare normal and defective examples.
calibrationScores = predict(detector, dsCal);

calibrationLabels = string(dsCal.Labels);
normalCalibrationScores = calibrationScores(calibrationLabels == normalClass);
defectCalibrationScores = calibrationScores(ismember(calibrationLabels, defectClasses));
normalCalibrationBinEdges = min(normalCalibrationScores): 0.03: max(normalCalibrationScores);
defectCalibrationBinEdges = min(defectCalibrationScores): 0.03: max(defectCalibrationScores);
fprintf("Inference on calibration data completed.")
%%
figure(Name="PatchCore calibration scores", Position=[100 100 850 420])
grid on
xlabel("Anomaly score")
ylabel("Number of images")
title("PatchCore calibration")
legend(Location="best")

histogram(normalCalibrationScores, BinEdges=normalCalibrationBinEdges, ...
    FaceColor=[0.20 0.55 0.90], ...
    DisplayName="Normal")
hold on
histogram(defectCalibrationScores, BinEdges=defectCalibrationBinEdges, ...
    FaceColor=[0.90 0.30 0.20], ...
    DisplayName="Defective")
%[text] Place the yellow line between the normal and defective score groups to explore a manual cutoff. This slider changes the illustration; the next section sets the detector's actual threshold.
threshold = 1.6; %[control:slider:6f8f]{"position":[13,16]}
xline(threshold, "y--", LineWidth=2, ...
    DisplayName=sprintf("Threshold %.3f", threshold))
hold off
%%
%[text] Manual thresholding is useful for intuition, but the deployed detector should store a repeatable threshold. Here [anomalyThreshold](matlab:doc('anomalyThreshold')) chooses the value that maximizes the F1 score on the calibration data.
%[text] MaxF1Score balances precision and recall on the calibration set. Assigning the result to detector.Threshold makes subsequent classify calls use that cutoff.
detector.Threshold = anomalyThreshold(dsCal.Labels, calibrationScores, ...
    defectClasses, "MaxF1Score");

figure(Name="PatchCore calibration scores", Position=[100 100 850 420])
grid on
xlabel("Anomaly score")
ylabel("Number of images")
title("PatchCore calibration")
legend(Location="best")

histogram(normalCalibrationScores, BinEdges=normalCalibrationBinEdges, ...
    FaceColor=[0.20 0.55 0.90], ...
    DisplayName="Normal")
hold on
histogram(defectCalibrationScores, BinEdges=defectCalibrationBinEdges, ...
    FaceColor=[0.90 0.30 0.20], ...
    DisplayName="Defective")
xline(detector.Threshold, "y--", LineWidth=2, ...
    DisplayName=sprintf("Threshold %.3f", detector.Threshold))
hold off
fprintf("PatchCore threshold: %.3f\n", detector.Threshold)
%%
%[text] ## 7. Evaluate PatchCore on cropped test ROIs
%[text] Use [classify](matlab:doc('classify')) to label held-out cropped ROIs. This evaluates the anomaly detector after pose normalization, before adding raw-image shape matching back into the pipeline.
%[text] classify applies the calibrated threshold to produce defect decisions. Comparing those decisions with the known test labels measures detection performance without using the test set to choose the threshold.
predictedLabels = classify(detector, dsTest);
patchCoreMetrics = evaluateAnomalyDetection(predictedLabels, ...
    dsTest.Labels, defectClasses);
%%
%[text] ## 8. Visualize one PatchCore prediction
%[text] Run this section repeatedly. Each run selects a random test crop and calls [classify](matlab:doc('classify')) once to return the decision, anomaly score, and anomaly map for display.
[patchCoreFile, patchCoreKnownClass] = randomDatastoreFile(dsTest);
patchCoreROI = imread(patchCoreFile);

[isDefective, anomalyScore, anomalyMap] = classify(detector, patchCoreROI);
%[text] The three outputs answer different questions: is the connector defective, how unusual is the image overall, and where are the unusual regions? The overlay displays the spatial anomaly map.

if isDefective
    patchCoreDecision = "Defective";
else
    patchCoreDecision = "Normal";
end

displayMap = normalizeCableAnomalyMap(anomalyMap, detector);
overlay = anomalyMapOverlay(patchCoreROI, displayMap);

reuseFigure("PatchCore test result", [100 100 1200 420], ...
    "PatchCoreTestResult");

t = tiledlayout(1, 2, Padding="compact", TileSpacing="compact");
title(t, "Refresh Section to Inspect New Image")
nexttile
imshow(patchCoreROI, [])
title("Known class: " + patchCoreKnownClass, Interpreter="none")

nexttile
imshow(overlay, [])
title(sprintf("Prediction: %s | Score: %.3f", ...
    patchCoreDecision, anomalyScore), Interpreter="none")
%%
%[text] ## 9. Run the full raw-image inspection pipeline
%[text] This section puts the pieces together on one original camera image. "inspectCableConnector" loads the pretrained models, runs shape matching, extracts an aligned ROI, and then applies PatchCore to the normalized connector.
%[text] The type command displays the helper's implementation for inspection. The helper loads its saved models, so training or calibrating the detector variable above does not update the model used by this full pipeline.
type inspectCableConnector
%[text] 
%%
%[text] Run this section repeatedly. Each run selects a random image and calls the "inspectCableConnector" function to apply the visual inspection pipeline to it, then it displays the results. 
knownClass = allClasses(randi(numel(allClasses)));
imageFile = randomImageFile(dataDir, knownClass);
I = imread(imageFile);

result = inspectCableConnector(I);

reuseFigure("Single-image inspection result", [100 100 1250 430], ...
    "SingleImageInspectionResult");
showCableInspectionResult(I, result, knownClass)
%%
%[text] ## 10. Explore results in the inspection app
%[text] Open the app to browse test images and inspect the intermediate outputs side by side. The app uses the pretrained models loaded by inspectCableConnector.
runAppDemo = false; %[control:checkbox:9921]{"position":[14,19]}

if isequal(runAppDemo, true)
    CableConnectorInspectionApp;
end
%%
%[text] ## 11. Visual inspection on video feed
%[text] Set runVideoDemo to true to run the same pipeline on a recorded video. MP4 frames are uint8, and the demo uses the pretrained models loaded by inspectCableConnector. For this section we are using a FCDD anomaly detector model instead of PatchCore. While PatchCore can train in a very short time, the size of the model and inference efficiency is highly dependent on the number of images used to train the model. In the Visual Inspection Toolbox we have other models like Student-Teacher and FCDD, which are especially suitable for real-time applications. They are trained on the same dataset used previously, which only includes "normal" data, and while they take slightly longer to train, they remain very small in size and can run inference at much faster rates. 
runVideoDemo = false; %[control:checkbox:6b82]{"position":[16,21]}

if isequal(runVideoDemo, true)
    videoFile = fullfile("Data", "Video", "CableConnectorsVideo.mp4");
    frameSkip = 2;
    playCableInspectionVideo(videoFile, frameSkip)
end

%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline","rightPanelPercent":28.7}
%---
%[control:checkbox:2a70]
%   data: {"defaultValue":false,"label":"drawNewTemplate","run":"Section"}
%---
%[control:slider:1e68]
%   data: {"defaultValue":0,"label":"matchingScoreThreshold","max":1,"min":0,"run":"Section","runOn":"ValueChanged","step":0.01}
%---
%[control:checkbox:9bf4]
%   data: {"defaultValue":false,"label":"trainNewDetector","run":"Section"}
%---
%[control:slider:6f8f]
%   data: {"defaultValue":0,"label":"threshold","max":2,"min":0,"run":"Section","runOn":"ValueChanged","step":0.1}
%---
%[control:checkbox:9921]
%   data: {"defaultValue":true,"label":"runVideoDemo","run":"Section"}
%---
%[control:checkbox:6b82]
%   data: {"defaultValue":true,"label":"runVideoDemo","run":"Section"}
%---
