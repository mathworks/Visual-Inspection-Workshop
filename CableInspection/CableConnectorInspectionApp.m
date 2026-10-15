function fig = CableConnectorInspectionApp
%CableConnectorInspectionApp Browse cable connector inspection results.

addpath("helperFunctions")

dataDir = "Data";
classNames = ["good", "broken", "crossed"];
imds = imageDatastore(fullfile(dataDir, classNames), ...
    IncludeSubfolders=true, LabelSource="foldernames");

files = string(imds.Files);
labels = string(imds.Labels);

fig = uifigure(Name="Cable Connector Inspection", ...
    Position=[100 100 1250 760]);

main = uigridlayout(fig, [1 2]);
main.ColumnWidth = {260, "1x"};

side = uigridlayout(main, [7 1]);
side.Layout.Column = 1;
side.RowHeight = {"fit", "fit", "fit", "1x", "fit", "fit", 170};

classLabel = uilabel(side, Text="Image Class");
classLabel.Layout.Row = 1;

classDropDown = uidropdown(side, ...
    Items=["all", classNames], Value="all", ...
    ValueChangedFcn=@(~, ~) updateList);
classDropDown.Layout.Row = 2;

listLabel = uilabel(side, Text="List of Images");
listLabel.Layout.Row = 3;

imageList = uilistbox(side, ValueChangedFcn=@(~, ~) updateImage);
imageList.Layout.Row = 4;

randomButton = uibutton(side, Text="Random", ...
    ButtonPushedFcn=@(~, ~) chooseRandomImage);
randomButton.Layout.Row = 5;

detailsLabel = uilabel(side, Text="Image Results");
detailsLabel.Layout.Row = 6;

details = uitextarea(side, Editable="off");
details.Layout.Row = 7;

axesGrid = uigridlayout(main, [2 2]);
axesGrid.Layout.Column = 2;

rawAxes = uiaxes(axesGrid);
roiAxes = uiaxes(axesGrid);
overlayAxes = uiaxes(axesGrid);
mapAxes = uiaxes(axesGrid);

title(rawAxes, "Part Detection")
title(roiAxes, "Cropped Image")
title(overlayAxes, "Defective/Normal")
title(mapAxes, "Anomaly Map")

for ax = [rawAxes, roiAxes, overlayAxes, mapAxes]
    ax.XTick = [];
    ax.YTick = [];
    axis(ax, "image")
end

updateList

    function updateList
        selectedClass = string(classDropDown.Value);
        if selectedClass == "all"
            visible = true(size(files));
        else
            visible = labels == selectedClass;
        end

        visibleFiles = files(visible);
        visibleLabels = labels(visible);

        names = strings(numel(visibleFiles), 1);
        for k = 1:numel(visibleFiles)
            [~, name, ext] = fileparts(visibleFiles(k));
            names(k) = visibleLabels(k) + "/" + name + ext;
        end

        imageList.Items = cellstr(names);
        imageList.ItemsData = cellstr(visibleFiles);

        if ~isempty(visibleFiles)
            imageList.Value = char(visibleFiles(1));
            updateImage
        end
    end

    function chooseRandomImage
        if isempty(imageList.ItemsData)
            return
        end
        idx = randi(numel(imageList.ItemsData));
        imageList.Value = imageList.ItemsData{idx};
        updateImage
    end

    function updateImage
        imageFile = string(imageList.Value);
        knownClass = labels(files == imageFile);

        I = imread(imageFile);
        result = inspectCableConnector(I);

        imshow(I, [], Parent=rawAxes)
        hold(rawAxes, "on")
        if ~isempty(result.RotatedBoundingBox)
            if result.IsDefective
                boxColor = "r";
            else
                boxColor = "g";
            end
            plotRotatedBox(rawAxes, result.RotatedBoundingBox, boxColor, 2)
        end
        hold(rawAxes, "off")
        title(rawAxes, sprintf("Shape Matching, Matching Score: %.3f", ...
            result.FixtureScore), Interpreter="none")

        imshow(result.ROI, [], Parent=roiAxes)
        title(roiAxes, "Cropped Image, Class: " + knownClass, Interpreter="none")

        imshow(result.Overlay, [], Parent=overlayAxes)
        title(overlayAxes, "Anomaly Prediction: " + result.Decision, ...
            Interpreter="none")

        imshow(result.DisplayAnomalyMap, [], Parent=mapAxes)
        colormap(mapAxes, "hot")
        title(mapAxes, sprintf("Anomaly Map, Score: %.3f", ...
            result.AnomalyScore), Interpreter="none")

        details.Value = [
            "File: " + getFileName(imageFile)
            ""
            "Image class: " + knownClass
            "Prediction: " + result.Decision
            ""
            "Matching Score: " + sprintf("%.3f", result.FixtureScore)
            "Anomaly Score: " + sprintf("%.3f", result.AnomalyScore)
            ];
    end
end

function plotRotatedBox(ax, rbox, color, lineWidth)
cx = rbox(1);
cy = rbox(2);
w = rbox(3);
h = rbox(4);
theta = deg2rad(rbox(5));

corners = [-w/2 -h/2; w/2 -h/2; w/2 h/2; -w/2 h/2; -w/2 -h/2];
R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
points = corners * R' + [cx cy];

plot(ax, points(:, 1), points(:, 2), Color=color, LineWidth=lineWidth)
end

function name = getFileName(file)
[~, stem, ext] = fileparts(file);
name = stem + ext;
end
