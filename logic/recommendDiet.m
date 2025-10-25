function diet = recommendDiet(weightKg, heightCm, goal, repCount, durationMin)
% recommendDiet - simple macro calculator based on pushup calorie burn

    if nargin < 5; durationMin = 20; end
    if nargin < 4; repCount = 0; end
    
    % Calorie calculation based on provided logic: 3.5 kcal per 10 pushups
    caloriesPerRep = 3.5 / 10;
    kcal = caloriesPerRep * repCount;
    
    % Use a hardcoded calorie value for the meal recommendation if needed
    if kcal < 150
        recommendedMealKcal = 150;
    else
        recommendedMealKcal = kcal;
    end
    
    % Adjust macros by intensity: higher intensity => more carbs
    intensityScore = min(repCount * 0.2, 10);
    
    % Clamp protein intake to a reasonable range
    protein_g = clamp(1.6 * weightKg, 1.2 * weightKg, 2.2 * weightKg);
    
    carbs_g =  weightKg * (3.0 + 0.9 * intensityScore);
    fats_g = 0.8 * weightKg;

    % Update the final calorie count for the diet struct
    diet = struct('kcal', round(recommendedMealKcal), 'protein_g', round(protein_g), ...
        'carbs_g', round(carbs_g), 'fats_g', round(fats_g));
end

function base = estimateBaseCalories(weightKg, heightCm)
    % Very rough BMR-like proxy to keep demo simple
    base = 22.0 * (heightCm/100)^2 * 24 * 0.8; % ~0.8*BMI*24
    % ensure reasonable range
    base = max(1200, min(2600, base));
end

function v = clamp(x, lo, hi)
    v = min(hi, max(lo, x));
end