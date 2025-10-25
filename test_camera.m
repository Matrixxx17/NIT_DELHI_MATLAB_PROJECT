% test_camera.m - Safe camera testing with proper error handling
clear all;
close all;

try
    % List available cameras
    cams = webcamlist;
    disp('Available cameras:');
    for i = 1:length(cams)
        disp([num2str(i) ': ' cams{i}]);
    end
    
    if isempty(cams)
        disp('No cameras found!');
        return;
    end
    
    % Try to connect to camera 1
    disp('Connecting to camera 1...');
    cam = webcam(1);
    
    % Take a snapshot
    disp('Taking snapshot...');
    img = snapshot(cam);
    
    % Check image properties
    disp(['Image size: ' num2str(size(img))]);
    disp(['Image class: ' class(img)]);
    disp(['Image range: ' num2str(min(img(:))) ' to ' num2str(max(img(:)))]);
    
    % Resize to standard size
    targetSize = [480, 640];
    if size(img,1) ~= targetSize(1) || size(img,2) ~= targetSize(2)
        disp('Resizing image...');
        img_resized = imresize(img, targetSize);
    else
        img_resized = img;
    end
    
    % Display the image
    figure('Name', 'Camera Test');
    imshow(img_resized, []);
    title(['Camera: ' cam.Name ' (Resized to ' num2str(size(img_resized)) ')']);
    
    % Clean up
    clear cam;
    disp('Camera test completed successfully!');
    
catch err
    disp(['Error: ' err.message]);
    disp('Camera test failed.');
    
    % Clean up on error
    try
        clear cam;
    catch
    end
end



