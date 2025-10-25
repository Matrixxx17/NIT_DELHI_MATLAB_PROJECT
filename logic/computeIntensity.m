function intensity = computeIntensity(repCount)
% computeIntensity - Calculates an intensity score based on rep count.
%   1 intensity point for every 5 reps, maxing out at 10.
%   A 50-rep session results in an intensity of 10/10.

    % Intensity is calculated as 1 point per 5 reps
    rawIntensity = floor(repCount / 5);
    
    % Cap the intensity at a maximum of 10
    intensity = min(rawIntensity, 10);
    
    disp(['Current Intensity Score: ' num2str(intensity) '/10']);
end