function [state, count] = updateRepCounter(angles, state, count, exerciseType, formOK)
% updateRepCounter - Counts a rep every 10 seconds, ignoring all other conditions.

    % Initialize the timer if it doesn't exist
    if ~isfield(state,'lastCountTime')
        state.lastCountTime = now;
    end
    
    % Check if 10 seconds have elapsed
    if (now - state.lastCountTime) * 24 * 60 * 60 > 10
        count = count + 1;
        state.lastCountTime = now; % Reset the timer
        disp(['Repetition Count: ' num2str(count)]);
    end

    % The rest of the logic is now ignored as per your request.
    % We return the updated state and count.
end

function v = pickField(s, names)
    v = NaN;
    for i = 1:numel(names)
        if isfield(s, names{i})
            v = s.(names{i});
            if ~isnan(v); return; end
        end
    end
end