function tform = convertMatchTransformToWorld(tform,Rout)
% Convert a matchshape model-origin transform into world-coordinate translation.
    [tform.Translation(1),tform.Translation(2)] = intrinsicToWorld(Rout,...
        tform.Translation(1),tform.Translation(2));
end
