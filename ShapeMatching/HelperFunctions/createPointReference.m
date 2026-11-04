function referenceData = createPointReference(model,Rout,templatePoints)
% Store point-based measurement seeds relative to a shape-model origin.
    [originX,originY] = intrinsicToWorld(Rout,model.ModelOrigin(1),model.ModelOrigin(2));
    referenceData = struct( ...
        "TemplatePosition",templatePoints, ...
        "RelativeToModelOrigin",templatePoints - [originX originY]);
end
