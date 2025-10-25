function detector = train_pose_model(datasetRoot, outDir)
% train_pose_model - Fine-tune a keypoint detector from a COCO-like dataset.
% Requires R2023b+ with Computer Vision & Deep Learning toolboxes.
% - datasetRoot: path containing 'images/' and 'annotations.json' (COCO)
% - outDir: folder to save trained detector (models/poseDetector.mat)

    if nargin < 2 || isempty(outDir)
        outDir = fullfile(pwd, 'models');
    end
    if ~exist(outDir,'dir'); mkdir(outDir); end

    gt = prepare_dataset(datasetRoot);

    % Split train/val
    rng(42);
    num = height(gt.DataSource.Source);
    idx = randperm(num);
    nTrain = round(0.9 * num);
    trainIdx = idx(1:nTrain); valIdx = idx(nTrain+1:end);
    gtTrain = subset(gt, trainIdx);
    gtVal   = subset(gt, valIdx);

    % Model options
    options = trainingOptions('adam', ...
        'InitialLearnRate', 1e-4, ...
        'MaxEpochs', 30, ...
        'MiniBatchSize', 8, ...
        'Shuffle','every-epoch', ...
        'Plots','training-progress', ...
        'ValidationData', gtVal, ...
        'ValidationFrequency', 100, ...
        'ExecutionEnvironment','auto');

    % Backbone selection (lightweight)
    try
        backbone = resnet18; %#ok<NASGU>
        base = 'resnet18';
    catch
        backbone = []; base = 'auto'; %#ok<NASGU>
    end

    % Train keypoint detector (API introduced in R2023b+)
    try
        detector = trainKeypointDetector(gtTrain, 'backbone', base, 'TrainingOptions', options);
    catch err
        error('trainKeypointDetector failed: %s', err.message);
    end

    % Save model
    outPath = fullfile(outDir, 'poseDetector.mat');
    save(outPath, 'detector');
    fprintf('Saved trained detector to %s\n', outPath);
end






