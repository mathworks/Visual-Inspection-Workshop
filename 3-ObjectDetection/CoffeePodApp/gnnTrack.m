function tracks = gnnTrack(bboxes, labels, frameCount, classDef, resetFlag) %#codegen
%% Tracker Construction
% Define the tracker as a persistent variable to preserve its state between
% calls to this function
persistent tracker sampleDetection
% On the first call to the function, tracker is still not defined. The
% following lines of code will define it. Note the use of the first
% detection as a SampleDetection. When generating code, the trackerGNN
% requires a SampleDetection to allocate memory for detections and tracks
% on construction.
if isempty(tracker)    
    nClasses = length(classDef);
    sampleDetection = createSampleDetection(nClasses);

    tracker = trackerGNN(MaxNumSensors=1,MaxNumTracks=15);
    tracker.FilterInitializationFcn = @customInitcvkf;
    tracker.ConfirmationThreshold = [2 2]; 
    tracker.DeletionThreshold = [10 10]; 
    tracker.ClassFusionMethod = "Bayes";
    tracker.InitialClassProbabilities = ones(1,nClasses)/nClasses;
    tracker.ClassFusionWeight = 0; %Try others    
    tracker(sampleDetection,frameCount);
    reset(tracker)
end

if resetFlag
    reset(tracker)
end

% generate detection objects
centroids = calculateCentroidsFromBBoxes(bboxes);
numMeasurementsInFrame = size(bboxes,1);
sampleDetection{1}.Time = frameCount;
detectionsInFrame = repmat(sampleDetection, numMeasurementsInFrame, 1);
for detCount = 1:numel(detectionsInFrame) %Explicitly recalculate the size of cell array
    classID = findClassInd(classDef, labels(detCount));
    detectionsInFrame{detCount}.Measurement = centroids(detCount,:);
    detectionsInFrame{detCount}.ObjectClassID = classID;
    detectionsInFrame{detCount}.ObjectAttributes = struct(BoundingBox = bboxes(detCount,:));
end

% Perform Tracking Given Measurement
tracks = tracker(detectionsInFrame, frameCount); 

end

function [sampleDetection] = createSampleDetection(nClasses)
% Create Sample Prediction
sampleCentroid = [2 2];
sampleBox = [1 1 2 2];
sampleDetection = cell(1);
sampleDetection{1} = objectDetection(...
            0, ... % Use frame count as time
            sampleCentroid, ... % Use centroid as measurement in pixels
            MeasurementNoise = diag([5 5]), ... % Centroid measurement noise in pixels
            ObjectClassID = 1, ... % Label ID 1-5
            ObjectClassParameters = struct('ConfusionMatrix', eye(nClasses)), ...
            ObjectAttributes = struct(BoundingBox = sampleBox) ... % Attach bounding box information
            );
end

function num = findClassInd(arrayClasses, detectedClass)
num = 0;
for ii = 1:length(arrayClasses)
    if arrayClasses(ii) == detectedClass
        num = ii;
    end
end
end

function centroids = calculateCentroidsFromBBoxes(bboxes)
nBoxes = size(bboxes,1);
centroids = zeros(nBoxes, 2);
for ii = 1:nBoxes
    centroids(ii, 1) = bboxes(ii,1) + bboxes(ii,3)/2;
    centroids(ii, 2) = bboxes(ii,2) + bboxes(ii,4)/2;
end
end

function filter = customInitcvkf(detection)
    % Initialize the filter using initcvkf
    filter = initcvkf(detection);

    % Define the initial parameters (assumed or estimated)
    initialVelocity = [-8 0];% [vx; vy]
    stateCovariance = eye(4) .* [5 0.001 5 0.001];
    processNoise = eye(2) .* 0.001;

    % Set the initial state to include both position and velocity
    filter.State([2,4]) = initialVelocity;
    filter.StateCovariance = stateCovariance;
    filter.ProcessNoise = processNoise;
end