function playCableInspectionVideo(videoFile, frameSkip, defectRegionThreshold)
%playCableInspectionVideo Run the inspection pipeline on a recorded video.

if nargin < 2
    frameSkip = 3;
end
if nargin < 3
    defectRegionThreshold = 0.35;
end

reader = VideoReader(videoFile);

stopRequested = false;
fig = figure(Name="Cable connector video inspection", ...
    Position=[100 100 1150 700], CloseRequestFcn=@stopVideo);
ax = axes(Parent=fig);
displayImage = [];
displayTitle = [];

frameNumber = 0;
currentPartDefectScores = [];
lastDetectorFPS = NaN;
while isvalid(fig) && ~stopRequested
    if ~hasFrame(reader)
        reader.CurrentTime = 0;
        frameNumber = 0;
        currentPartDefectScores = [];
        continue
    end

    frame = readFrame(reader);
    frameNumber = frameNumber + 1;

    % Skip frames to make playback faster during the workshop.
    if mod(frameNumber - 1, frameSkip) ~= 0
        continue
    end

    % Process window-close events before running inference on the next
    % displayed frame.
    drawnow limitrate
    if stopRequested || ~isvalid(fig) || ~isvalid(ax)
        break
    end

    result = inspectCableConnector_FCDD(frame);
    if isfield(result, "DetectorFPS") && isfinite(result.DetectorFPS)
        lastDetectorFPS = result.DetectorFPS;
    else
        result.DetectorFPS = lastDetectorFPS;
    end

    % The user may close the figure while the current frame is processing.
    if stopRequested || ~isvalid(fig) || ~isvalid(ax)
        break
    end

    if isempty(result.RotatedBoundingBox)
        currentPartDefectScores = [];
        result.VideoDefectScore = NaN;
    else
        currentFrameDefectScore = rightSideAnomalyScore(result.DisplayAnomalyMap);
        currentPartDefectScores(end+1) = currentFrameDefectScore; %#ok<AGROW>
        result.VideoDefectScore = median(currentPartDefectScores);
    end
    result = applyVideoDecision(result, defectRegionThreshold);
    annotatedFrame = annotateVideoFrame(frame, result);
    titleText = sprintf("Frame %d - %s - defect score %.2f", ...
        frameNumber, result.Decision, result.VideoDefectScore);

    if isempty(displayImage) || ~isvalid(displayImage)
        displayImage = imshow(annotatedFrame, [], Parent=ax);
        displayTitle = title(ax, titleText, Interpreter="none");
    else
        displayImage.CData = annotatedFrame;
        if isempty(displayTitle) || ~isvalid(displayTitle)
            displayTitle = title(ax, titleText, Interpreter="none");
        else
            displayTitle.String = titleText;
        end
    end
    drawnow limitrate
end

    function stopVideo(src, ~)
        stopRequested = true;
        delete(src)
    end
end

function result = applyVideoDecision(result, defectRegionThreshold)
% The global PatchCore score is sensitive to the lighting difference between
% the still images and the video. For the crossed-connector video demo, the
% defect appears as a strong anomaly on the right side of the cropped part,
% so the decision uses that localized map score and smooths it across the
% current part passage.
if isfinite(result.VideoDefectScore)
    result.IsDefective = result.VideoDefectScore >= defectRegionThreshold;
    if result.IsDefective
        result.Decision = "Defective";
    else
        result.Decision = "Normal";
    end
end
end

function score = rightSideAnomalyScore(displayMap)
% crossed-connector defects appear near the terminal side of the ROI. Use
% the right side of the normalized anomaly map as a stable video cue.
[~, w] = size(displayMap);
rightColumns = round(0.70 * w):w;
score = mean(double(displayMap(:, rightColumns)), "all");
end

function annotatedFrame = annotateVideoFrame(frame, result)
% Convert the video frame to uint8 RGB for display annotation. VideoReader
% returns uint8 frames for MP4 files, and this conversion is also safe for
% MJ2 files that may decode as uint16.
annotatedFrame = im2uint8(frame);
if size(annotatedFrame, 3) == 1
    annotatedFrame = repmat(annotatedFrame, 1, 1, 3);
end

if isempty(result.RotatedBoundingBox)
    annotatedFrame = insertText(annotatedFrame, [20 20], "No part", ...
        FontSize=24, BoxColor=[220 160 0], TextColor="white", ...
        BoxOpacity=0.75);
    annotatedFrame = insertDetectorFPSText(annotatedFrame, result);
    return
end

if result.IsDefective
    % Only show the anomaly heatmap when the part is defective. Normal
    % frames stay visually clean and only show the detected part outline.
    annotatedFrame = overlayMapInRotatedBox( ...
        annotatedFrame, result.RotatedBoundingBox, ...
        result.AnomalyMap, result.DisplayAnomalyMap);
    boxColor = "red";
else
    boxColor = "green";
end

polygon = rotatedBoxPolygon(result.RotatedBoundingBox);
annotatedFrame = insertShape(annotatedFrame, "Polygon", polygon, ...
    Color=boxColor, LineWidth=5);

labelText = sprintf("%s | defect score %.2f | match %.3f", ...
    result.Decision, result.VideoDefectScore, result.FixtureScore);
annotatedFrame = insertText(annotatedFrame, [20 20], labelText, ...
    FontSize=24, BoxColor=boxColor, TextColor="white", BoxOpacity=0.75);
annotatedFrame = insertDetectorFPSText(annotatedFrame, result);
end

function annotatedFrame = insertDetectorFPSText(annotatedFrame, result)
if isfield(result, "DetectorFPS") && isfinite(result.DetectorFPS)
    fpsText = sprintf("FCDD %.1f FPS", result.DetectorFPS);
else
    fpsText = "FCDD -- FPS";
end

position = [size(annotatedFrame, 2) - 20, 20];
annotatedFrame = insertText(annotatedFrame, position, fpsText, ...
    FontSize=24, BoxColor="black", TextColor="white", BoxOpacity=0.70, ...
    AnchorPoint="RightTop");
end

function frameOut = overlayMapInRotatedBox(frameIn, rbox, anomalyMap, displayAnomalyMap)
frameOut = frameIn;

% Match the display overlay size to the central plastic crop that was used
% for anomaly detection.
pad = round(0.12 * max(rbox(3), rbox(4)));
targetWidth = max(1, round(0.84 * (rbox(3) + 2*pad)));
targetHeight = max(1, round(0.84 * (rbox(4) + 2*pad)));

colorMap = rescaleVideoAnomalyMap(anomalyMap, displayAnomalyMap);
colorMap = imresize(colorMap, [targetHeight targetWidth]);
mapIndex = max(1, min(256, round(1 + 255 * colorMap)));
mapColors = jet(256);
heat = reshape(mapColors(mapIndex(:), :), [targetHeight targetWidth 3]);
heat = im2uint8(heat);

alphaMap = imresize(double(displayAnomalyMap), [targetHeight targetWidth]);
alphaMap = min(max(alphaMap, 0), 1);
alpha = 0.15 + 0.45 * alphaMap;
alpha(alphaMap <= 0) = 0;

% cropCableConnectorROI rotated the part by +angle to make it upright.
% Rotate by -angle to place the map back into the original frame.
rotatedHeat = imrotate(heat, -rbox(5), "bilinear", "loose");
rotatedAlpha = imrotate(alpha, -rbox(5), "bilinear", "loose");

centerX = round(rbox(1));
centerY = round(rbox(2));
x1 = centerX - floor(size(rotatedHeat, 2) / 2);
y1 = centerY - floor(size(rotatedHeat, 1) / 2);
x2 = x1 + size(rotatedHeat, 2) - 1;
y2 = y1 + size(rotatedHeat, 1) - 1;

frameX1 = max(1, x1);
frameY1 = max(1, y1);
frameX2 = min(size(frameOut, 2), x2);
frameY2 = min(size(frameOut, 1), y2);

if frameX2 < frameX1 || frameY2 < frameY1
    return
end

overlayX1 = frameX1 - x1 + 1;
overlayY1 = frameY1 - y1 + 1;
overlayX2 = overlayX1 + frameX2 - frameX1;
overlayY2 = overlayY1 + frameY2 - frameY1;

framePatch = double(frameOut(frameY1:frameY2, frameX1:frameX2, :));
heatPatch = double(rotatedHeat(overlayY1:overlayY2, overlayX1:overlayX2, :));
alphaPatch = rotatedAlpha(overlayY1:overlayY2, overlayX1:overlayX2);
alphaPatch = repmat(alphaPatch, 1, 1, 3);

frameOut(frameY1:frameY2, frameX1:frameX2, :) = ...
    uint8((1 - alphaPatch) .* framePatch + alphaPatch .* heatPatch);
end

function displayMap = rescaleVideoAnomalyMap(anomalyMap, displayAnomalyMap)
% Stretch each frame's raw anomaly values inside the active defect region
% so the video overlay uses more of the jet colormap.

map = double(anomalyMap);
finiteMask = isfinite(map);

if ~any(finiteMask, "all")
    displayMap = zeros(size(map));
    return
end

activeMask = finiteMask;
if nargin > 1 && ~isempty(displayAnomalyMap)
    activeDisplayMap = imresize(double(displayAnomalyMap), ...
        [size(map, 1), size(map, 2)], "nearest");
    activeMask = finiteMask & activeDisplayMap > 0;
end

if nnz(activeMask) < 2
    activeMask = finiteMask;
end

activeValues = map(activeMask);
lowValue = prctile(activeValues, 2);
highValue = prctile(activeValues, 98);

if highValue <= lowValue
    lowValue = min(activeValues);
    highValue = max(activeValues);
end

if highValue <= lowValue
    displayMap = zeros(size(map));
    return
end

displayMap = (map - lowValue) ./ (highValue - lowValue);
displayMap = min(max(displayMap, 0), 1);
displayMap(~finiteMask) = 0;
if nargin > 1 && ~isempty(displayAnomalyMap)
    displayMap(~activeMask) = 0;
end
end

function polygon = rotatedBoxPolygon(rbox)
cx = rbox(1);
cy = rbox(2);
w = rbox(3);
h = rbox(4);
theta = deg2rad(rbox(5));

corners = [-w/2 -h/2; w/2 -h/2; w/2 h/2; -w/2 h/2];
R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
corners = corners * R' + [cx cy];
polygon = reshape(corners', 1, []);
end
