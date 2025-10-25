function saveSession(summary, outDir)
% saveSession - writes a MAT file per session and appends CSV log

    if nargin < 2 || isempty(outDir)
        outDir = fullfile(pwd,'sessions');
    end
    if ~exist(outDir,'dir'); mkdir(outDir); end

    ts = datestr(summary.timestamp, 'yyyymmdd_HHMMSS');
    matfilePath = fullfile(outDir, sprintf('session_%s.mat', ts));
    save(matfilePath, 'summary');

    % CSV append
    csvPath = fullfile(outDir, 'sessions.csv');
    row = { char(summary.timestamp), summary.exercise, summary.durationSec, summary.reps, summary.intensity, ...
        summary.diet.kcal, summary.diet.protein_g, summary.diet.carbs_g, summary.diet.fats_g, ...
        iSafe(summary,'heightCm',NaN), iSafe(summary,'weightKg',NaN), iSafe(summary,'goal','') };
    headers = {'timestamp','exercise','durationSec','reps','intensity','kcal','protein_g','carbs_g','fats_g','heightCm','weightKg','goal'};
    if ~exist(csvPath,'file')
        fid = fopen(csvPath,'w');
        fprintf(fid, '%s\n', strjoin(headers, ','));
    else
        fid = fopen(csvPath,'a');
    end
    fprintf(fid, '%s,%s,%.0f,%d,%.2f,%d,%d,%d,%d,%.0f,%.0f,%s\n', row{:});
    fclose(fid);
end

function v = iSafe(s, field, default)
    if isfield(s, field)
        v = s.(field);
    else
        v = default;
    end
end




