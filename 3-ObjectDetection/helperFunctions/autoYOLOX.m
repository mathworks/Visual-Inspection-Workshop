function autoLabels = autoYOLOX(I)

persistent yolox
 
if isempty(yolox)
    detector = load("yoloxDetector.mat");
    yolox = detector.net; 
end
 
[bboxPred,~,labelPred] = detect(yolox, I);

autoLabels = struct('Name',{},'Type',{}, 'Position',{});

for ii = 1:length(labelPred)
    autoLabels(ii).Name      = labelPred(ii);
    autoLabels(ii).Type      = labelType('Rectangle');
    autoLabels(ii).Position  = bboxPred(ii,:);
end

end