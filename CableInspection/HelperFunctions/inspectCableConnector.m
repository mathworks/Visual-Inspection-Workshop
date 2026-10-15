function result = inspectCableConnector(I)
%inspectCableConnector Run the cable connector inspection on one image.

persistent detector fixtureModel

% Loading the model files is slow, so keep them in memory after the first
% function call.
if isempty(detector)
    detectorData = load("models/connectorAnomalyDetector_patchCore.mat", "detector");
    fixtureData = load("models/connectorShapeMatchingModel.mat", "fixtureModel");
    detector = detectorData.detector;
    fixtureModel = fixtureData.fixtureModel;
end

grayImage = im2gray(I);
matchingScoreThreshold = 0.40;

% The adjusted image improves edge contrast for shape matching. The ROI is
% still cropped from the original grayscale image, so anomaly detection sees
% the same intensity style used during training.
matchImage = imadjust(grayImage);
matches = matchshape(fixtureModel, matchImage, MaxMatches=1, ...
    ScoreThreshold=matchingScoreThreshold);

result.FixtureScore = NaN;
result.RotatedBoundingBox = [];
result.ROI = [];
result.IsDefective = false;
result.Decision = "No part";
result.AnomalyScore = NaN;
result.AnomalyMap = [];
result.DisplayAnomalyMap = [];
result.Overlay = [];

if isempty(matches)
    return
end

% Use the detected pose to crop and rotate the connector into a consistent
% coordinate system before passing it to PatchCore.
result.FixtureScore = matches(1).Score;
result.RotatedBoundingBox = matches(1).RotatedBoundingBox;
result.ROI = cropCableConnectorROI(matchImage, result.RotatedBoundingBox);

% classify returns the decision, anomaly score, and anomaly map in one
% inference call.
[result.IsDefective, result.AnomalyScore, result.AnomalyMap] = ...
    classify(detector, result.ROI);

if result.IsDefective
    result.Decision = "Defective";
else
    result.Decision = "Normal";
end

result.DisplayAnomalyMap = normalizeCableAnomalyMap(result.AnomalyMap, detector);
result.Overlay = anomalyMapOverlay(result.ROI, result.DisplayAnomalyMap);
end
