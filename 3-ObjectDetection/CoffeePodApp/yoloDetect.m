function [bboxes,scores,labels] = yoloDetect(matFile,image)

% Copyright 2024 The MathWorks, Inc.

persistent myDetector;

if isempty(myDetector)
    wb = waitbar(0.5, "Loading YOLOX model...");
    myDetector = vision.loadYOLOXObjectDetector(matFile);
    close(wb)
end

% Call to detect method
[bboxes,scores,labels] = detect(myDetector,image,Threshold = 0.8);
end