function [alerts, formOK, predictedExercise] = evaluateFormRules(angles, keypoints, exerciseType)
% evaluateFormRules - Placeholder that ignores form.
 
    formOK = true; % Always true, as per the new simplified logic
    predictedExercise = 'PushUp';
    
    disp('Form Check:');
    disp(alerts);
end

function v = pickField(s, names)
    v = NaN;
    for i=1:numel(names)
        if isfield(s, names{i})
            v = s.(names{i});
            if ~isnan(v); return; end
        end
    end
end