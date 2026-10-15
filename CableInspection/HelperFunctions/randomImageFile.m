function imageFile = randomImageFile(dataDir, className)
%randomImageFile Pick one random image from a class folder.

files = dir(fullfile(dataDir, className, "*.png"));
imageFile = string(fullfile(files(1).folder, files(randi(numel(files))).name));
end
