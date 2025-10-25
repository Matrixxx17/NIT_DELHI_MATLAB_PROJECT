% final_fitness_tracker_V13.m
% Connects to the mobile device, logs 10 seconds of ACCELERATION and POSITION data,
% calculates DAS, Speed, Distance, Calories, and the Comprehensive Fitness Score (CFS).
% --- 1. CONFIGURATION AND CONSTANTS ---
DEVICE_NAME = "Redmi Note 12 5G"; % <-- CRITICAL: REPLACE THIS with your actual device name
TRACKING_DURATION_S = 10; % 10 seconds for quick testing 
FS = 10; % Assumed sampling frequency
G = 9.81; % Acceleration due to gravity (m/s^2)
dt = 1 / FS; % Time step
% User Profile (Hardcoded for MET Calculation)
USER_WEIGHT_KG = 75; % <--- Adjust this weight for accurate calorie calculation (in kg)
USER_AGE = 30; % Placeholder age, used for potential future complex formulas
% Metabolic Equivalent of Task (MET) Values (kcal/kg/hour)
MET_AT_REST = 1.0;
MET_WALKING = 3.0;
MET_RUNNING = 8.3;
% Scoring and Thresholds
ACCEL_THRESHOLD = 0.5; % m/s^2 for DAS movement detection
TARGET_ACTIVE_TIME_S = 3600; % 60 min target for DAS=10
MAX_DAS = 10;
MAX_CFS = 15;
R_EARTH = 6371000; % Earth radius in meters
% Geocoding Constants (For converting Lat/Lon to address)
% Initial State Accumulators (These persist in a full app)
accumulated_active_time_s = 0;
total_cumulative_distance_m = 0; % Total distance accumulator
total_calories = 0;
try
    % --- Step 1: Connect to Mobile Device (Robust check) ---
    clear M; % This ensures a new connection is established every time and fixes the "Unrecognized method" error
    fprintf('Step 1: Creating new connection to mobile device "%s"...\n', DEVICE_NAME);
    M = mobiledev(DEVICE_NAME); 
    
    % --- Step 2: Start Dual Sensor Logging ---
    fprintf('Step 2: Starting Acceleration and Position (GPS) logging.\n');
    M.AccelerationSensorEnabled = 1; % Enable acceleration
    M.PositionSensorEnabled = 1; % Enable GPS
    M.logging = 1; % Start logging in the background
    fprintf('------------------------------------------------------------------\n');
    fprintf('** Device logging for the next %d seconds. MOVE your device! **\n', TRACKING_DURATION_S);
    fprintf('------------------------------------------------------------------\n');
    pause(TRACKING_DURATION_S); 
    
    % --- Step 3: Stop Logging and Retrieve Data ---
    M.logging = 0; 
    [a, ~] = accellog(M); % Retrieve logged acceleration data
    [lat, lon, ~, ~, ~, ~, ~] = poslog(M); % Retrieve logged position data
    
    % Clear logs for next session
    discardlogs(M); 
    
    fprintf('Step 3: Data retrieved and logging stopped.\n');
    
    % --- 4. DATA PROCESSING AND METRIC CALCULATION ---
    
    % 4A. Step Counting and Activity State from Acceleration
    if isempty(a)
        final_state = 'ERROR: NO ACCEL DATA';
        steps = 0;
        Active_Time_s_period = 0;
        TotalDistance_Report = 0;
        total_calories = 0;
        peak_speed = 0;
    else
        % Remove gravity component and calculate dynamic magnitude
        dynamic_a = a;
        dynamic_a(:,3) = a(:,3) - G;
        dynamic_mag = sqrt(sum(dynamic_a.^2, 2));
        
        % Step Counting Algorithm: Use MinPeakHeight to filter out noise
        % Adjust MinPeakHeight and MinPeakDistance for your device
        [pks, locs] = findpeaks(dynamic_mag, 'MinPeakProminence', 0.5, 'MinPeakDistance', 0.2*FS, 'MinPeakHeight', 0.8);
        steps = length(locs);
        
        % Determine state based on step count
        if steps > 5 % Heuristic: More than 0.5 steps per second suggests walking
            final_state = 'WALKING';
            MET_Value = MET_WALKING;
        elseif steps > 0
            final_state = 'LIGHT ACTIVITY';
            MET_Value = MET_AT_REST + (MET_WALKING - MET_AT_REST) / 2; % Intermediate MET
        else
            final_state = 'AT REST';
            MET_Value = MET_AT_REST;
        end
        
        % Calculate Total Active Time based on walking state
        if strcmp(final_state, 'WALKING')
            Active_Time_s_period = TRACKING_DURATION_S;
        else
            Active_Time_s_period = 0;
        end
        
        % Calculate Total Calories based on the final determined state
        total_calories = (MET_Value * USER_WEIGHT_KG / 3600) * TRACKING_DURATION_S;
        
        % Estimate Distance from Steps (Heuristic: 0.75 meters/step)
        TotalDistance_Report = steps * 0.75;
        if TRACKING_DURATION_S > 0
            peak_speed = TotalDistance_Report / TRACKING_DURATION_S;
        else
            peak_speed = 0;
        end
    end
    
    % --- 5. SCORING (DAS & CFS) ---
    DailyActiveTimeSeconds = accumulated_active_time_s + Active_Time_s_period;
    DAS_raw = (DailyActiveTimeSeconds / TARGET_ACTIVE_TIME_S) * 10;
    DAS = min(MAX_DAS, DAS_raw);
    
    % CFS: DAS (Max 10) + Distance Score (Max 5 for 1 km)
    Distance_Score = min(5, (TotalDistance_Report / 1000) * 5); 
    CFS = round((DAS + Distance_Score), 2); 
    
    % Final Display Values
    TotalActiveMinutes = round(DailyActiveTimeSeconds / 60);
    
    % --- 6. FINAL DISPLAY REPORT ---
    fprintf('\n======================================================\n');
    fprintf('  REAL-TIME ADVANCED FITNESS TRACKER REPORT\n');
    fprintf('======================================================\n');
    fprintf('  Duration Sampled: %d seconds\n', TRACKING_DURATION_S);
    fprintf('  \n');
    % --- State and Metrics ---
    fprintf('--- ACTIVITY & VELOCITY METRICS ---\n');
    fprintf('  Total Steps Counted:         %d\n', steps);
    fprintf('  Estimated Peak Speed:        %.2f m/s\n', peak_speed);
    fprintf('  Total Active Time (DAS):     %.1f seconds\n', Active_Time_s_period);
    fprintf('  Total Distance Covered (Est.): %.2f meters\n', TotalDistance_Report);
    fprintf('  Total Calories Burned:       %.2f (MET-based)\n', total_calories);
    fprintf('  Final Activity State:        %s\n', final_state);
    fprintf('  \n');
    
    % --- Fitness Scores ---
    fprintf('--- FITNESS SCORES ---\n');
    fprintf('  Daily Activity Score (DAS): %.2f / %d\n', DAS, MAX_DAS);
    fprintf('  *Comprehensive Fitness Score (CFS): %.2f / %d*\n', CFS, MAX_CFS);
    fprintf('======================================================\n');
    
catch ME
    % Handle connection or device errors gracefully
    fprintf('\nAn error occurred during execution:\n');
    fprintf('%s\n', ME.message);
    if isequal(ME.identifier, 'MATLAB:UndefinedFunction') && contains(ME.message, 'mobiledev')
        fprintf('ACTION REQUIRED: The MATLAB Support Package for Mobile Sensing may be missing.\n');
    end
end