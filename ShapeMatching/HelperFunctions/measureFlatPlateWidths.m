function measurementResults = measureFlatPlateWidths(imToMeasure,Rout,flatPlateModel,referenceData)
% Measure every detected flat-plate width in millimeters.
    matches = matchshape(flatPlateModel,imToMeasure,MaxMatches=5,ScoreThreshold=0.7);
    measurementResults = table('Size',[0 3],...
        'VariableTypes',{'double','double','double'},...
        'VariableNames',{'MatchIndex','MatchScore','WidthInMM'});

    for matchIdx = 1:height(matches)
        tform = convertMatchTransformToWorld(matches(matchIdx).ModelOriginTransformation,Rout);
        caliperPosition = transformPointsForward(tform,referenceData.RelativeToModelOrigin);
        measurementData = caliper(imToMeasure,caliperPosition,...
            Transformation=Rout,Width=20,GradientThreshold=0.05,EdgeTransition="both");
        if isempty(measurementData.IntraEdgeDistance)
            continue
        end

        measurementResults(end+1,:) = {matchIdx,matches(matchIdx).Score,measurementData.IntraEdgeDistance(1)}; %#ok<AGROW>
    end
end
