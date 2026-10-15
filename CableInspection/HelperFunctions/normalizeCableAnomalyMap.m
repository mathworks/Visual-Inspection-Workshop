function displayMap = normalizeCableAnomalyMap(anomalyMap, detector)
%normalizeCableAnomalyMap Scale an anomaly map for display.

threshold = double(detector.Threshold);
quietValue = 0.95 * threshold;

% Values well below the detector threshold are displayed as quiet. Values
% near or above the threshold become bright in the heatmap overlay.
displayMap = (double(anomalyMap) - quietValue) ./ (threshold - quietValue);
displayMap = min(max(displayMap, 0), 1);
end
