function smoothed = smoothKeypoints(current, previous)
% smoothKeypoints - simple exponential smoothing on keypoint coordinates
    if isempty(previous) || ~isfield(previous,'points') || ~isfield(current,'points')
        smoothed = current; return; 
    end
    alpha = 0.4; % smoothing factor
    A = current.points; B = previous.points;
    % Align sizes
    n = min(size(A,1), size(B,1));
    C = A;
    C(1:n, :) = alpha * A(1:n, :) + (1 - alpha) * B(1:n, :);
    smoothed = current; smoothed.points = C;
end



