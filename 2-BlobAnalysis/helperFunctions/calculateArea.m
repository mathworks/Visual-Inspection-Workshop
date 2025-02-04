function [properties] = calculateArea(BW_in)
% Auto-generated by imageRegionAnalyzer app on 19-Dec-2024
properties = regionprops('table', BW_in, 'Area');
[~, maxInd] = max(properties.Area);
properties = properties{maxInd, 1};
end