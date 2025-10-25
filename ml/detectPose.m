function keypoints = detectPose(I)
% detectPose - Unified wrapper to obtain 2D body keypoints for a single person.
% Uses a pre-trained model from Deep Learning Toolbox.
    persistent detector personDetector;

    keypoints = struct('names',{{}}, 'points',[], 'scores',[]);
    if nargin < 1 || isempty(I)
        return;
    end
    
    % Initialize detectors only once
    if isempty(detector) || isempty(personDetector)
        try
            disp('Initializing pose and person detectors...');
            detector = hrnetObjectKeypointDetector;
            personDetector = peopleDetector;
            disp('Detectors ready.');
        catch ME
            disp(['Initialization error: ' ME.message]);
            return;
        end
    end
    
    try
        % Detect the person first to get the bounding box
        [bboxes, ~, ~] = detect(personDetector, I);
        
        if isempty(bboxes)
            disp('No person detected.');
            return;
        end
        
        % Select the largest bounding box if multiple people are detected
        [~, idx] = max(bboxes(:,3).*bboxes(:,4));
        bbox = bboxes(idx, :);

        % Detect keypoints within the bounding box
        [pts, scores, valid] = detect(detector, I, bbox);

        allNames = {'nose', 'neck', 'right_shoulder', 'right_elbow', 'right_wrist', ...
                    'left_shoulder', 'left_elbow', 'left_wrist', 'right_hip', ...
                    'right_knee', 'right_ankle', 'left_hip', 'left_knee', ...
                    'left_ankle', 'right_eye', 'left_eye', 'right_ear', 'left_ear'};
        
        validPts = pts(valid==1,:);
        validNames = allNames(valid==1);
        validScores = scores(valid==1);
        
        if ~isempty(validPts)
            keypoints.names = validNames;
            keypoints.points = validPts;
            keypoints.scores = validScores;
            disp(['Detected ' num2str(size(keypoints.points, 1)) ' keypoints.']);
        else
             disp('Keypoints not detected within bounding box.');
        end
        
    catch ME
        disp(['An error occurred in detectPose: ' ME.message]);
        % Fallback: If an unexpected error occurs
        sz = size(I);
        keypoints.names = {'center'};
        keypoints.points = [sz(2)/2, sz(1)/2];
        keypoints.scores = 0.05;
    end
end