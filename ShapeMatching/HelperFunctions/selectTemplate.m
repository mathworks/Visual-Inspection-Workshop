function template = selectTemplate(imageInput,plateType,cropNewTemplate)

templateImage = imread(imageInput);
if cropNewTemplate
    figure(Name="Select Shape Template Region");
    imshow(templateImage, []);
    title("Draw a tight rectangle around the "+ plateType + " connector.","Adjust as needed. Double click region when finished.")

    templateBox = drawrectangle(Color="green");
    wait(templateBox)
    template = imcrop(im2gray(templateImage), templateBox.Position);
    close(gcf)
else
    template = templateImage;
end