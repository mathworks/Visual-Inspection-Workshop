function referenceData = createCircleReference(model,Rout,circleCentersInMM,circleRadiiInMM)
% Store circle seeds relative to a shape-model origin and label hole sizes.
    [originX,originY] = intrinsicToWorld(Rout,model.ModelOrigin(1),model.ModelOrigin(2));
    [sortedRadii,order] = sort(circleRadiiInMM,"ascend");
    sortedCenters = circleCentersInMM(order,:);
    numSmallHoles = max(numel(sortedRadii) - 3,0);
    holeType = [repmat("Small",numSmallHoles,1); repmat("Large",numel(sortedRadii)-numSmallHoles,1)];

    referenceData = struct( ...
        "CircleTemplatePositions",[sortedCenters sortedRadii], ...
        "CircleCentersRelativeToModelOrigin",sortedCenters - [originX originY], ...
        "CircleRadiiInMM",sortedRadii, ...
        "HoleType",holeType);
end
