function plotMeasurementSummary(values,xLabelText,yLabelText,titleText)
% Plot a measurement trend with a mean reference line.
    measurementIndex = 1:numel(values);
    scatter(measurementIndex,values,"filled");
    hold on;
    plot([measurementIndex(1) measurementIndex(end)],...
        [mean(values) mean(values)],LineStyle="--",LineWidth=1.5);
    hold off;
    xlabel(xLabelText);
    ylabel(yLabelText);
    title(titleText);
    legend("Measurements","Mean",Location="best");
end
