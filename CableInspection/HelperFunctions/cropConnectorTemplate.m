function template = cropConnectorTemplate(I)
%cropConnectorTemplate Crop the connector from a template image.

I = im2gray(I);

mask = imbinarize(I, graythresh(I));
mask = imopen(mask, strel("disk", 3));
mask = imfill(mask, "holes");
mask = bwareafilt(mask, 1);

props = regionprops(mask, "BoundingBox");
template = imcrop(I, props(1).BoundingBox + [-40 -40 80 80]);
end
