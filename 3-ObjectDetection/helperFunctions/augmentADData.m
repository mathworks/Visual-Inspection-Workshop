function [data] = augmentADData(data)
    sz = size(data);
    
    % Randomly add jitter
    data = jitterColorHSV(data, Brightness=[-0.1 0.1]);

    % Randomly flip image.
    tform = randomAffine2d(XReflection=true,YReflection=true,Rotation=@myAngle);
    rout = affineOutputView(sz,tform,BoundsStyle="centerOutput");
    data = imwarp(data,tform,OutputView=rout);
    data = data;
end

function angle = myAngle()
iR = randi([0 3], 1);
angle = 90*iR;
end