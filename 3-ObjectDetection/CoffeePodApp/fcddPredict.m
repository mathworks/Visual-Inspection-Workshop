function [score, class] = fcddPredict(matFile,image) 
% Copyright 2024 The MathWorks, Inc.

persistent myDetector;

if isempty(myDetector)
    wb = waitbar(0.5, "Loading FCDD model...");
    myDetector = vision.loadFCDDAnomalyDetector(matFile);
    close(wb)
end

% Call to detect method
score = predict(myDetector,image, MiniBatchSize=10);
class = score > myDetector.Threshold;
end