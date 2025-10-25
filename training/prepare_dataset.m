function gt = prepare_dataset(datasetRoot)
% prepare_dataset - Converts a COCO-style (Roboflow/GTS) keypoint dataset to MATLAB groundTruth
% Input: datasetRoot with 'images/' and 'annotations.json' (COCO keypoints)
% Output: groundTruth object usable by trainKeypointDetector (R2023b+)

    annPath = fullfile(datasetRoot, 'annotations.json');
    imgDir  = fullfile(datasetRoot, 'images');
    if exist(annPath,'file') ~= 2
        error('annotations.json not found at %s', annPath);
    end
    if exist(imgDir,'dir') ~= 7
        error('images directory not found at %s', imgDir);
    end

    % Read COCO annotations
    S = jsondecode(fileread(annPath));
    images = S.images; annotations = S.annotations; cats = S.categories;

    % Build image file table
    imIdToFile = containers.Map('KeyType','double','ValueType','char');
    for i=1:numel(images)
        imIdToFile(images(i).id) = fullfile(imgDir, images(i).file_name);
    end

    % Assume single category with keypoints list
    if ~isempty(cats) && isfield(cats(1),'keypoints')
        keypointNames = string(cats(1).keypoints);
    else
        % Default to COCO 17
        keypointNames = string({ 'nose','left_eye','right_eye','left_ear','right_ear', ...
            'left_shoulder','right_shoulder','left_elbow','right_elbow','left_wrist','right_wrist', ...
            'left_hip','right_hip','left_knee','right_knee','left_ankle','right_ankle' });
    end

    % Build table for trainKeypointDetector
    fileNames = strings(0,1); keypointTbl = cell(0,1);
    for i=1:numel(annotations)
        a = annotations(i);
        if ~isKey(imIdToFile, a.image_id); continue; end
        file = imIdToFile(a.image_id);
        kps = reshape(a.keypoints, 3, []).'; % [x y v]
        pts = kps(:,1:2);
        vis = kps(:,3);
        % Only keep visible or labeled
        pts(vis==0, :) = NaN;
        T = array2table(pts, 'VariableNames', strcat('k', string(1:size(pts,1))));
        fileNames(end+1,1) = string(file); %#ok<AGROW>
        keypointTbl{end+1,1} = T; %#ok<AGROW>
    end

    if isempty(fileNames)
        error('No annotations parsed. Check dataset format.');
    end

    % Build groundTruth object (Keypoint label)
    source = groundTruthDataSource(table(fileNames, 'VariableNames', {'imageFilename'}));
    ldefs = keypointLabelDefinition(keypointNames);
    data = table(keypointTbl, 'VariableNames', {'Keypoints'});
    gt = groundTruth(source, ldefs, data);
end






