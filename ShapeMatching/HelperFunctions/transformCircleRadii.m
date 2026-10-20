function radiiInMM = transformCircleRadii(tform,circleCentersRelativeToModelOrigin,circleRadiiInMM)
% Transform circle radii under the recovered similarity transform.
    transformedCenters = transformPointsForward(tform,circleCentersRelativeToModelOrigin);
    outerPoints = circleCentersRelativeToModelOrigin + [circleRadiiInMM zeros(numel(circleRadiiInMM),1)];
    transformedOuterPoints = transformPointsForward(tform,outerPoints);
    radiiInMM = vecnorm(transformedOuterPoints - transformedCenters,2,2);
end
