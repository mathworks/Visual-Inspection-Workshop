function measurementResults = measureNotchPlateAngles(imToMeasure,Rout,notchPlateModel,referenceData)
% Measure every detected notch angle in degrees.
    matches = matchshape(notchPlateModel,imToMeasure,MaxMatches=5,ScoreThreshold=0.7);
    measurementResults = table('Size',[0 3],...
        'VariableTypes',{'double','double','double'},...
        'VariableNames',{'MatchIndex','MatchScore','AngleInDegrees'});

    for matchIdx = 1:height(matches)
        tform = convertMatchTransformToWorld(matches(matchIdx).ModelOriginTransformation,Rout);
        anglePosition = transformPointsForward(tform,referenceData.RelativeToModelOrigin);
        measurementData = fitangle(imToMeasure,anglePosition,Snap=true,Transformation=Rout);
        if isempty(measurementData.Theta)
            continue
        end

        measurementResults(end+1,:) = {matchIdx,matches(matchIdx).Score,measurementData.Theta}; %#ok<AGROW>
    end
end
