function showCableInspectionResult(I, result, knownClass)
%showCableInspectionResult Display the raw image, ROI, and anomaly overlay.

t = tiledlayout(2, 2, Padding="compact", TileSpacing="compact");
title(t, "Refresh Section to Inspect New Image")

nexttile
imshow(I, [])
hold on
if result.IsDefective
    boxColor = "r";
else
    boxColor = "g";
end
drawRotatedBox(result.RotatedBoundingBox, boxColor, 2)
hold off
title(sprintf("Matching Score: %.3f", ...
    result.FixtureScore), Interpreter="none")

nexttile
imshow(result.ROI, [])
title("Cropped Image, Class: " + knownClass, Interpreter="none")

nexttile
imshow(result.Overlay, [])
title("Anomaly Prediction: " + result.Decision, Interpreter="none")

nexttile
imshow(result.DisplayAnomalyMap, [])
colormap(gca, "hot")
title(sprintf("Anomaly Map, Score: %.3f", result.AnomalyScore), ...
    Interpreter="none")
end
