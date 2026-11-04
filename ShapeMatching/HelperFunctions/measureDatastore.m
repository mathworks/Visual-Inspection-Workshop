function measurementResults = measureDatastore(imds,fileNames,measurementFcn)
% Run one measurement function across an image datastore and add image metadata.
    measurementResults = table();
    reset(imds);
    for imageIdx = 1:numel(imds.Files)
        imageMeasurements = measurementFcn(readimage(imds,imageIdx));
        if isempty(imageMeasurements)
            continue
        end

        imageMeasurements.ImageIndex = repmat(imageIdx,height(imageMeasurements),1);
        imageMeasurements.ImageName = repmat(fileNames(imageIdx),height(imageMeasurements),1);
        imageMeasurements = movevars(imageMeasurements,["ImageIndex","ImageName"],Before=1);
        measurementResults = [measurementResults; imageMeasurements]; %#ok<AGROW>
    end
end
