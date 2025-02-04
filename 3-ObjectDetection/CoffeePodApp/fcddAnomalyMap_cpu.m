function map = fcddAnomalyMap_cpu(matFile,image)

% Copyright 2024 The MathWorks, Inc.

persistent myDetector;

if isempty(myDetector)
    wb = waitbar(0.5, "Loading FCDD model...");
    myDetector = vision.loadFCDDAnomalyDetector(matFile);
    close(wb)
end

% Call to detect method
map = anomalyMap(myDetector,image, executionEnvironment="cpu");
end