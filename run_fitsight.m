% run_fitsight - Launcher for FitSight App
% Usage: Press Run or type run_fitsight in Command Window

% Ensure project folders are on path relative to this file
rootDir = fileparts(mfilename('fullpath'));
addpath(genpath(rootDir));

% Launch the app
FitSightApp();

