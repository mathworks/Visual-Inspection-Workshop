function result = inspectCableConnector_FCDD(I)
%inspectCableConnector_FCDD Run fast cable connector inspection on one image.

persistent detector fixtureModel previousRotatedBoundingBox

% Loading the model files is slow, so keep them in memory after the first
% function call.
if isempty(detector)
    detectorData = load("models/connectorAnomalyDetector_FCDD.mat", "detector");
    fixtureData = load("models/connectorShapeMatchingModel.mat", "fixtureModel");
    detector = detectorData.detector;
    fixtureModel = fixtureData.fixtureModel;
end

grayImage = im2gray(I);
matchingScoreThreshold = 0.40;

% The adjusted image improves edge contrast for shape matching. The FCDD
% detector still sees an ROI extracted from the original grayscale image, so
% anomaly detection sees the same intensity style used during training.
matchImage = imadjust(grayImage);
[fixtureScore, rotatedBoundingBox] = matchConnectorNearPreviousPosition( ...
    fixtureModel, matchImage, previousRotatedBoundingBox, ...
    matchingScoreThreshold);

result.FixtureScore = NaN;
result.RotatedBoundingBox = [];
result.ROI = [];
result.IsDefective = false;
result.Decision = "No part";
result.AnomalyScore = NaN;
result.AnomalyMap = [];
result.DisplayAnomalyMap = [];
result.Overlay = [];
result.DetectorInferenceTime = NaN;
result.DetectorFPS = NaN;

if isempty(rotatedBoundingBox)
    previousRotatedBoundingBox = [];
    return
end

% Use the detected pose to extract an aligned connector ROI before passing
% it to FCDD.
previousRotatedBoundingBox = rotatedBoundingBox;
result.FixtureScore = fixtureScore;
result.RotatedBoundingBox = rotatedBoundingBox;
result.ROI = cropCableConnectorROI(grayImage, result.RotatedBoundingBox);

% classify returns the decision, anomaly score, and anomaly map in one
% inference call.
detectorTimer = tic;
[result.IsDefective, result.AnomalyScore, result.AnomalyMap] = ...
    classify(detector, result.ROI);
result.DetectorInferenceTime = toc(detectorTimer);
result.DetectorFPS = 1 / result.DetectorInferenceTime;

if result.IsDefective
    result.Decision = "Defective";
else
    result.Decision = "Normal";
end

result.DisplayAnomalyMap = normalizeCableAnomalyMap(result.AnomalyMap, detector);
% result.Overlay = anomalyMapOverlay(result.ROI, result.DisplayAnomalyMap);
end

function [fixtureScore, rotatedBoundingBox] = matchConnectorNearPreviousPosition( ...
    fixtureModel, matchImage, previousRotatedBoundingBox, scoreThreshold)
% Match near the previous video-frame detection, then fall back to full
% frame search so the tracker can recover when a new connector enters.

fixtureScore = NaN;
rotatedBoundingBox = [];

if ~isempty(previousRotatedBoundingBox)
    [localImage, offset] = cropLocalSearchImage( ...
        matchImage, previousRotatedBoundingBox);

    localScoreThreshold = max(scoreThreshold, 0.50);
    matches = matchshape(fixtureModel, localImage, MaxMatches=1, ...
        ScoreThreshold=localScoreThreshold);

    if ~isempty(matches)
        fixtureScore = matches(1).Score;
        rotatedBoundingBox = matches(1).RotatedBoundingBox;
        rotatedBoundingBox(1:2) = rotatedBoundingBox(1:2) + offset;
        return
    end
end

matches = matchshape(fixtureModel, matchImage, MaxMatches=1, ...
    ScoreThreshold=scoreThreshold);

if isempty(matches)
    return
end

fixtureScore = matches(1).Score;
rotatedBoundingBox = matches(1).RotatedBoundingBox;
end

function [localImage, offset] = cropLocalSearchImage(matchImage, rbox)
% Create an axis-aligned search window around the previous rotated box.

searchPadding = max(150, round(0.20 * max(rbox(3), rbox(4))));

cx = rbox(1);
cy = rbox(2);
w = rbox(3);
h = rbox(4);
theta = deg2rad(rbox(5));

corners = [-w/2 -h/2; w/2 -h/2; w/2 h/2; -w/2 h/2];
R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
corners = corners * R' + [cx cy];

imageSize = size(matchImage, [1 2]);
x1 = max(1, floor(min(corners(:, 1)) - searchPadding));
y1 = max(1, floor(min(corners(:, 2)) - searchPadding));
x2 = min(imageSize(2), ceil(max(corners(:, 1)) + searchPadding));
y2 = min(imageSize(1), ceil(max(corners(:, 2)) + searchPadding));

localImage = matchImage(y1:y2, x1:x2);
offset = [x1 - 1, y1 - 1];
end
