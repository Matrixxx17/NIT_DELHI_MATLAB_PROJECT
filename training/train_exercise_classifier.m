function bestModel = train_exercise_classifier(datasetRoot, outDir)
% train_exercise_classifier - Transfer-learn a CNN to classify exercise form
% for three classes: squats, pushup, jumping jack. Evaluates multiple
% pretrained backbones (ResNet/MobileNet/ShuffleNet), selects the best by
% validation accuracy, then retrains on train+val and saves the model.
%
% Inputs:
%   - datasetRoot: folder containing subfolders per split and class, e.g.
%       datasetRoot/
%         train/{squats,pushup,jumpingjack}
%         val/{squats,pushup,jumpingjack}
%         test/{squats,pushup,jumpingjack} (optional)
%   - outDir: directory to save models/metadata. Defaults to models/
%
% Output:
%   - bestModel: DAGNetwork or dlnetwork of the selected, retrained model
%
% Requires: Computer Vision Toolbox, Deep Learning Toolbox

    if nargin < 2 || isempty(outDir)
        outDir = fullfile(pwd, 'models');
    end
    if ~exist(outDir,'dir'); mkdir(outDir); end

    % Load datasets using folder names as labels
    trainDir = fullfile(datasetRoot, 'train');
    valDir   = fullfile(datasetRoot, 'val');
    testDir  = fullfile(datasetRoot, 'test');
    if exist(trainDir,'dir') ~= 7 || exist(valDir,'dir') ~= 7
        error('Expected train/ and val/ subfolders at %s', datasetRoot);
    end

    imdsTrain = imageDatastore(trainDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');
    imdsVal   = imageDatastore(valDir,   'IncludeSubfolders', true, 'LabelSource', 'foldernames');
    hasTest = exist(testDir,'dir') == 7;
    if hasTest
        imdsTest = imageDatastore(testDir, 'IncludeSubfolders', true, 'LabelSource', 'foldernames'); %#ok<NASGU>
    end

    % Sanity checks
    classes = categories(imdsTrain.Labels);
    if numel(classes) < 3
        warning('Found %d classes; expected at least 3 (squats, pushup, jumpingjack).', numel(classes));
    end
    fprintf('Classes: %s\n', strjoin(string(classes), ', '));

    % Define candidate backbones and input sizes
    candidates = {
        @() iTryLoad('resnet18'),       [224 224 3], 'resnet18';
        @() iTryLoad('mobilenetv2'),    [224 224 3], 'mobilenetv2';
        @() iTryLoad('resnet50'),       [224 224 3], 'resnet50';
        @() iTryLoad('shufflenet'),     [224 224 3], 'shufflenet';
    };

    % Training common options
    baseOptions = trainingOptions('adam', ...
        'InitialLearnRate', 1e-4, ...
        'MiniBatchSize', 32, ...
        'MaxEpochs', 10, ...
        'Shuffle', 'every-epoch', ...
        'Verbose', false, ...
        'Plots', 'none', ...
        'ValidationData', imdsVal);

    % Evaluate each backbone
    results = struct('name',{},'valAccuracy',{},'net',{},'inputSize',{});
    for i=1:size(candidates,1)
        loader = candidates{i,1};
        inputSize = candidates{i,2};
        name = candidates{i,3};
        net = loader();
        if isempty(net)
            fprintf('Skipping %s (not available)\n', name);
            continue;
        end
        fprintf('Adapting %s...\n', name);
        lgraph = iReplaceFinalLayers(net, numel(classes));
        augmenter = iAugmenter(inputSize(1:2));
        augTrain = augmentedImageDatastore(inputSize(1:2), imdsTrain, 'DataAugmentation', augmenter);
        augVal   = augmentedImageDatastore(inputSize(1:2), imdsVal);
        opts = baseOptions;
        opts.ValidationData = augVal; %#ok<STRNU>
        try
            trained = trainNetwork(augTrain, lgraph, opts);
            % Compute validation accuracy
            YPred = classify(trained, augVal);
            YVal  = imdsVal.Labels;
            acc = mean(YPred == YVal);
            fprintf('%s validation accuracy: %.2f%%\n', name, acc*100);
            results(end+1) = struct('name', name, 'valAccuracy', acc, 'net', trained, 'inputSize', inputSize); %#ok<AGROW>
        catch err
            warning('Training %s failed: %s', name, err.message);
        end
    end

    if isempty(results)
        error('No backbone could be trained. Ensure required support packages are installed.');
    end

    % Pick best model
    [~, bestIdx] = max([results.valAccuracy]);
    best = results(bestIdx);
    fprintf('Best backbone: %s (val acc %.2f%%)\n', best.name, best.valAccuracy*100);

    % Retrain best on train+val for a few more epochs
    allDS = imageDatastore({trainDir, valDir}, 'IncludeSubfolders', true, 'LabelSource', 'foldernames');
    augmenter = iAugmenter(best.inputSize(1:2));
    augAll = augmentedImageDatastore(best.inputSize(1:2), allDS, 'DataAugmentation', augmenter);
    optsFinal = trainingOptions('adam', ...
        'InitialLearnRate', 5e-5, ...
        'MiniBatchSize', 32, ...
        'MaxEpochs', 10, ...
        'Shuffle', 'every-epoch', ...
        'Verbose', false, ...
        'Plots', 'none');
    lgraphBest = layerGraph(best.net.Layers);
    bestFinal = trainNetwork(augAll, lgraphBest, optsFinal);

    % Save model and metadata
    outPath = fullfile(outDir, 'exerciseClassifier.mat');
    metadata = struct();
    metadata.classes = classes;
    metadata.backbone = best.name;
    metadata.inputSize = best.inputSize;
    metadata.validationAccuracy = best.valAccuracy;
    save(outPath, 'bestFinal', 'metadata');
    fprintf('Saved trained classifier to %s\n', outPath);

    bestModel = bestFinal;
end

function net = iTryLoad(whichNet)
    try
        switch lower(whichNet)
            case 'resnet18'
                net = resnet18();
            case 'resnet50'
                net = resnet50();
            case 'mobilenetv2'
                net = mobilenetv2();
            case 'shufflenet'
                net = shufflenet();
            otherwise
                net = [];
        end
    catch
        net = [];
    end
end

function lgraph = iReplaceFinalLayers(net, numClasses)
    if isa(net, 'DAGNetwork')
        lgraph = layerGraph(net);
        % Identify last learnable layer and classification layers
        [learnableLayer, classLayer] = iFindReplaceableLayers(lgraph);
        newLearnable = iNewLearnableLayer(learnableLayer, numClasses);
        newClass = classificationLayer('Name','new_classoutput');
        lgraph = replaceLayer(lgraph, learnableLayer.Name, newLearnable);
        lgraph = replaceLayer(lgraph, classLayer.Name, newClass);
    else
        error('Unsupported network type: %s', class(net));
    end
end

function [learnableLayer, classLayer] = iFindReplaceableLayers(lgraph)
    % Find last learnable layer
    if ~isempty(findLayersOfType(lgraph,'fullyConnectedLayer'))
        learnableLayer = lgraph.Layers(find(arrayfun(@(L) isa(L,'nnet.cnn.layer.FullyConnectedLayer'), lgraph.Layers), 1, 'last'));
    else
        learnableLayer = lgraph.Layers(find(arrayfun(@(L) isa(L,'nnet.cnn.layer.Convolution2DLayer') && L.NumFilters == 1000, lgraph.Layers), 1, 'last'));
    end
    classLayer = lgraph.Layers(find(arrayfun(@(L) isa(L,'nnet.cnn.layer.ClassificationOutputLayer'), lgraph.Layers), 1, 'last'));
end

function newL = iNewLearnableLayer(oldL, numClasses)
    if isa(oldL,'nnet.cnn.layer.FullyConnectedLayer')
        newL = fullyConnectedLayer(numClasses, 'Name', 'new_fc', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10);
    elseif isa(oldL,'nnet.cnn.layer.Convolution2DLayer')
        newL = convolution2dLayer(1, numClasses, 'Name', 'new_conv', 'WeightLearnRateFactor', 10, 'BiasLearnRateFactor', 10);
    else
        error('Unsupported learnable layer type: %s', class(oldL));
    end
end

function augmenter = iAugmenter(inputSize)
    augmenter = imageDataAugmenter( ...
        'RandRotation', [-10 10], ...
        'RandXTranslation', [-10 10], ...
        'RandYTranslation', [-10 10], ...
        'RandXScale', [0.9 1.1], ...
        'RandYScale', [0.9 1.1], ...
        'RandXReflection', true);
end



