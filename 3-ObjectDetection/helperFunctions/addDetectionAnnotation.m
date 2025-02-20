function [annotatedImage] = addDetectionAnnotation(data, bboxPred, labelPred, scorePred)
%UNTITLED Summary of this function goes here
%   Detailed explanation goes here

I = data{1};
bbox = data{2};
label = data{3};

annotatedImage = insertShape(I,"Rectangle",bbox);
labelPos = bbox(:,[1 2]); labelPos(:,2) = labelPos(:,2) + bbox(:,4);
annotatedImage = insertText(annotatedImage,labelPos,string(label), "FontSize", 20);

colorOut = ["red", "green"];
[labelIdx, ~, assignment] = vision.internal.detector.assignDetectionsToGroundTruth(bboxPred, bbox, 0.5, scorePred);
predColorIdx = ones(length(labelIdx), 1);
matchedPredictions = labelIdx == 1;
assignedGTruths = assignment(assignment ~= 0);
goodMatches = labelPred(matchedPredictions) == label(assignedGTruths);
predColorIdx(matchedPredictions) = goodMatches + 1;
predColors = colorOut(predColorIdx);

annotatedImage = insertObjectAnnotation(annotatedImage,"Rectangle",bboxPred, ...
    labelPred,"Color",predColors, "FontSize", 20);
annotatedImage = imresize(annotatedImage,2);
end