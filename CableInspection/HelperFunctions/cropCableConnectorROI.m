function roi = cropCableConnectorROI(I, rbox)
%cropCableConnectorROI Extract an aligned connector ROI.

roiSize = [256 512];
I = im2gray(I);

% matchshape returns a rotated bounding box as:
% [centerX centerY width height angleDegrees].
cx = rbox(1);
cy = rbox(2);
w = rbox(3);
h = rbox(4);
angle = rbox(5);

% Include a little context around the connector, then trim the outer edge of
% that context in the final ROI to reduce cable and background pixels.
pad = round(0.12 * max(w, h));
sourceWidth = w + 2*pad;
sourceHeight = h + 2*pad;
roiWidth = 0.84 * sourceWidth;
roiHeight = 0.84 * sourceHeight;

% Estimate a neutral fill value for any sampled points outside the camera
% frame. Most of the image is background, so the global median is stable.
backgroundValue = median(double(I(:)), "omitnan");

% Map original image coordinates into a connector-centered, upright
% coordinate system. The output view samples the final ROI directly, so the
% image is aligned and cropped in one interpolation step.
theta = deg2rad(angle);
c = cos(theta);
s = sin(theta);

imageToROI = affine2d([
    c, -s, 0
    s,  c, 0
    -c*cx - s*cy, s*cx - c*cy, 1]);

outputView = imref2d(roiSize, ...
    [-roiWidth/2 roiWidth/2], [-roiHeight/2 roiHeight/2]);

roi = imwarp(I, imageToROI, OutputView=outputView, ...
    InterpolationMethod="bilinear", FillValues=backgroundValue);

% Repeat the grayscale channel so the ROI can be processed by RGB
% backbones.
roi = repmat(roi, 1, 1, 3);
end
