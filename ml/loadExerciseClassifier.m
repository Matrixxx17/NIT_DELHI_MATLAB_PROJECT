function [net, metadata] = loadExerciseClassifier()
% loadExerciseClassifier - Load trained exercise classifier if available.
% Returns empty if not found. Caches result for quick reuse.

    persistent cachedNet cachedMeta cachedOk lastCheckTs;
    if ~isempty(cachedNet) && cachedOk && (isempty(lastCheckTs) || seconds(datetime('now')-lastCheckTs) < 5)
        net = cachedNet; metadata = cachedMeta; return;
    end

    cachedOk = false; net = []; metadata = struct();
    modelPath = fullfile(pwd, 'models', 'exerciseClassifier.mat');
    if exist(modelPath,'file') ~= 2
        lastCheckTs = datetime('now'); return;
    end
    try
        S = load(modelPath);
        if isfield(S, 'bestFinal')
            net = S.bestFinal;
        elseif isfield(S, 'net')
            net = S.net;
        end
        if isfield(S, 'metadata')
            metadata = S.metadata;
        end
        if ~isempty(net)
            cachedNet = net; cachedMeta = metadata; cachedOk = true;
        end
    catch
        net = []; metadata = struct();
    end
    lastCheckTs = datetime('now');
end



