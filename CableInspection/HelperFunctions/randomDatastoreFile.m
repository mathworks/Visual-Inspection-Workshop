function [imageFile, imageClass] = randomDatastoreFile(imds)
%randomDatastoreFile Pick one random image from an image datastore.

classNames = string(categories(imds.Labels));
imageClass = classNames(randi(numel(classNames)));

files = string(imds.Files(string(imds.Labels) == imageClass));
imageFile = files(randi(numel(files)));
end
