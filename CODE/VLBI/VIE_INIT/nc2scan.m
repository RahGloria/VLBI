% ************************************************************************
%   Description:
%   This function puts the data from the netCDF files into our standarized
%   format of scan structures.
%
%   Input:	
%      Both variables from the netCDF files - out_struct and nc_info.
%
%   Output:
%      The scan structure array.
% 
%   External calls: 	
%       
%   Coded for VieVS: 
%   Jul 2012 by Matthias Madzak
%
%   Revision: 
%   yyyy-mm-dd,FIRSTNAME SECONDNAME:
%   2016-06-16, M. Madzak: Errors when loading intensive sesssions: - "obs2Baseline" only provided for one for one baseline
%                                                                   - "delayFlagLikeNGS" is a skalar value
%                                                                   => Provided values are duplicated as required using repmat and a warning msg is printed to the CW
%   2016-07-06, A. Hellerschmied: Added checks for availability and validity of met. data. => Error code (error_code_invalid_met_data) in case of problems
%   2016-08-09, A. Hellerschmied: Field scan(i_scan).obs_type added.
%   2017-11-13, J.Gruber: General update. +It is now possible to choose a certain frequency band
%   2017-12-13, A. Hellerschmied: function modjuldat.m instead of date2mjd.m used.
%   2018-16-01, J.Gruber: Second redundant exception for Ion code Flag removed

% ************************************************************************
function scan=nc2scan(out_struct, nc_info, fband, wrapper_data, institution_tag)
% fprintf('nc2scan started\n')

% ##### Options #####
error_code_invalid_met_data = -999; % Error corde for missing met. data in NGS file (numerical)

%% PREALLOCATING
nScans=out_struct.head.NumScan.val; % get number of scans, stored in Head.nc
nObs=out_struct.head.NumObs.val; % actually not required, however: nice for test
                           
% substructs for internal vievs struct
subStruct_stat=struct('x', [], 'temp', [], 'pres', [], 'e', [], 'az', ...
    [], 'zd', [], 'zdry', [], 'cab', [], 'axkt', [], 'therm', [], ...
    'pantd', [], 'trop', []);
subStruct_obs=struct('i1', [], 'i2', [], 'obs', [], 'sig', [], 'com', ...
    [], 'delion', [], 'sgdion', [], 'q_code', [], 'q_code_ion', []);
scan(nScans+1)=struct('mjd', [], 'stat', [], 'tim', [], ...
    'nobs', [], 'space', [], 'obs', [], 'iso', []); % +1: not working otherwise - is deleted after loop
space0.source = zeros(3,3);
space0.xp=0; space0.yp=0; space0.era=0; space0.xnut=0; space0.ynut=0;
space0.t2c=zeros(3,3);


% ##### Get cross referencing indices from folder CrossReference #####
% obs2Baseline:
nc_filename = get_nc_filename('ObsCrossRef', wrapper_data.Observation.CrossReference.files);
obs2Baseline=double(out_struct.CrossReference.(nc_filename).Obs2Baseline.val)'; % it is also saved in netCDF file (->take it from there) nRows=nObs, nCols=2
% for (at least some) intensives: only one baseline given (as they are all equal) --> repmat
if size(obs2Baseline,1)==1
    obs2Baseline=repmat(obs2Baseline,nObs,1);
    fprintf('WARNING: obs2baseline only scalar! The provided values for one baseline are duplicated using repmat.\n');
end
obs2BaselineCell=num2cell(obs2Baseline);
% obs2Scan:
obs2Scan=double(out_struct.CrossReference.(nc_filename).Obs2Scan.val); % vector (lenght = nScans), giving scan number (as integer) nObs x 1
% scan2Station:
nc_filename = get_nc_filename('StationCrossRef', wrapper_data.Session.CrossReference.files);
scan2Station=double(out_struct.CrossReference.(nc_filename).Scan2Station.val)'; % matrix (nRows=nScans), giving stations (also the number of observations per station is counted!), nCols = nStations
% scan2Source
nc_filename = get_nc_filename('SourceCrossRef', wrapper_data.Session.CrossReference.files);
scan2Source=double(out_struct.CrossReference.(nc_filename).Scan2Source.val); % vector (nRows=nScans), giving integer source index, nCols=1

switch fband
    
    case 'GroupDelayFull_bX'
        % GroupDelayFull_bX:
        % delay, groupDelayWAmbigCell: /ObsEdit/GroupDelayFull_bX
        % sigma delay, groupDelaySigCell: /Observables/GroupDelay_bX
        % ionospheric delay, ionoDelCell: /ObsDerived/Cal_SlantPathIonoGroup_bX
        % sigma ionospheric delay, ionoDelSigCell: /ObsDerived/Cal_SlantPathIonoGroup_bX
        nc_filename = get_nc_filename({'GroupDelayFull', '_bX', institution_tag}, wrapper_data.Observation.ObsEdit.files);
        tau_folder = 'ObsEdit';
        tau_file = nc_filename;
        tau_field = 'GroupDelayFull';
        nc_filename = get_nc_filename({'GroupDelay', '_bX'}, wrapper_data.Observation.Observables.files);
        sigma_tau_folder = 'Observables';
        sigma_tau_file = nc_filename;
        sigma_tau_field = 'GroupDelaySig';
        nc_filename = get_nc_filename({'Cal-SlantPathIonoGroup', '_bX'}, wrapper_data.Observation.ObsDerived.files);
        tau_ion_folder = 'ObsDerived';
        tau_ion_file = strrep(nc_filename,'-','_');
        tau_ion_field = 'Cal_SlantPathIonoGroup';
        sigma_tau_ion_folder = 'ObsDerived';
        sigma_tau_ion_file = strrep(nc_filename,'-','_');
        sigma_tau_ion_field = 'Cal_SlantPathIonoGroupSigma';
        
    case 'GroupDelayFull_bS'
        % GroupDelayFull_bS:
        % delay, groupDelayWAmbigCell: /ObsEdit/GroupDelayFull_bS
        % sigma delay, groupDelaySigCell: /Observables/GroupDelay_bS
        % ionospheric delay, ionoDelCell:
        % /ObsDerived/Cal_SlantPathIonoGroup_bX or /ObsDerived/Cal_SlantPathIonoGroup_bS
        % sigma ionospheric delay, ionoDelSigCell: /ObsDerived/Cal_SlantPathIonoGroup_bX or /ObsDerived/Cal_SlantPathIonoGroup_bS
        nc_filename = get_nc_filename({'GroupDelayFull', '_bS', institution_tag}, wrapper_data.Observation.ObsEdit.files);
        tau_folder = 'ObsEdit';
        tau_file = nc_filename;
        tau_field = 'GroupDelayFull';
        nc_filename = get_nc_filename({'GroupDelay', '_bS'}, wrapper_data.Observation.Observables.files);
        sigma_tau_folder = 'Observables';
        sigma_tau_file = 'GroupDelay_bS';
        sigma_tau_field = 'GroupDelaySig';
        nc_filename = get_nc_filename({'Cal-SlantPathIonoGroup', '_bS'}, wrapper_data.Observation.ObsDerived.files);
        tau_ion_folder = 'ObsDerived';
        tau_ion_file = strrep(nc_filename,'-','_');
        tau_ion_field = 'Cal_SlantPathIonoGroup';
        
    case 'GroupDelay_bX'
        % GroupDelay_bX:
        % delay, groupDelayWAmbigCell: /Observables/GroupDelay_bX
        % sigma delay, groupDelaySigCell: /Observables/GroupDelay_bX
        % ionospheric delay, ionoDelCell: 
        % sigma ionospheric delay, ionoDelSigCell: 
        nc_filename = get_nc_filename({'GroupDelay', '_bx'}, wrapper_data.Observation.Observables.files);
        tau_folder = 'Observables';
        tau_file = nc_filename;
        tau_field = 'GroupDelay';
        sigma_tau_folder = 'Observables';
        sigma_tau_file = nc_filename;
        sigma_tau_field = 'GroupDelaySig';
        tau_ion_folder = {}; % ionospheric correction won't be used
        tau_ion_file = {}; % ionospheric correction won't be used
        tau_ion_field = {};
        
    case 'GroupDelay_bS'
        % GroupDelay_bS:
        % delay, groupDelayWAmbigCell: /Observables/GroupDelay_bS
        % sigma delay, groupDelaySigCell: /Observables/GroupDelay_bS
        % ionospheric delay, ionoDelCell: 
        % sigma ionospheric delay, ionoDelSigCell: 
        nc_filename = get_nc_filename({'GroupDelay', '_bS'}, wrapper_data.Observation.Observables.files);
        tau_folder = 'Observables';
        tau_file = nc_filename;
        tau_field = 'GroupDelay';
        sigma_tau_folder = 'Observables';
        sigma_tau_file = nc_filename;
        sigma_tau_field = 'GroupDelaySig';
        tau_ion_folder = {}; % ionospheric correction won't be used
        tau_ion_file = {}; % ionospheric correction won't be used
        tau_ion_field = {};
        
    case 'GroupDelay_plusiono_bX'
        % GroupDelay_bX:
        % delay, groupDelayWAmbigCell: /Observables/GroupDelay_bX
        % sigma delay, groupDelaySigCell: /Observables/GroupDelay_bX
        % ionospheric delay, ionoDelCell: /ObsDerived/Cal_SlantPathIonoGroup_bX
        % sigma ionospheric delay, ionoDelSigCell: /ObsDerived/Cal_SlantPathIonoGroup_bX
        nc_filename = get_nc_filename({'GroupDelay', '_bS'}, wrapper_data.Observation.Observables.files);
        tau_folder = 'Observables';
        tau_file = nc_filename;
        tau_field = 'GroupDelay';
        sigma_tau_folder = 'Observables';
        sigma_tau_file = nc_filename;
        sigma_tau_field = 'GroupDelaySig';
        nc_filename = get_nc_filename({'Cal-SlantPathIonoGroup', '_bX'}, wrapper_data.Observation.ObsDerived.files);
        tau_ion_folder = 'ObsDerived';
        tau_ion_file = strrep(nc_filename,'-','_');
        tau_ion_field = 'Cal_SlantPathIonoGroup';
        
    case 'GroupDelay_plusiono_bS'
        % GroupDelay_bX:
        % delay, groupDelayWAmbigCell: /Observables/GroupDelay_bS
        % sigma delay, groupDelaySigCell: /Observables/GroupDelay_bS
        % ionospheric delay, ionoDelCell: /ObsDerived/Cal_SlantPathIonoGroup_bX or /ObsDerived/Cal_SlantPathIonoGroup_bS
        % sigma ionospheric delay, ionoDelSigCell: /ObsDerived/Cal_SlantPathIonoGroup_bX or /ObsDerived/Cal_SlantPathIonoGroup_bS
        nc_filename = get_nc_filename({'GroupDelay', '_bS'}, wrapper_data.Observation.Observables.files);
        tau_folder = 'Observables';
        tau_file = nc_filename;
        tau_field = 'GroupDelay';
        sigma_tau_folder = 'Observables';
        sigma_tau_file = nc_filename;
        sigma_tau_field = 'GroupDelaySig';
        nc_filename = get_nc_filename({'Cal-SlantPathIonoGroup', '_bS'}, wrapper_data.Observation.ObsDerived.files);
        tau_ion_folder = 'ObsDerived';
        tau_ion_file = strrep(nc_filename,'-','_');
        tau_ion_field = 'Cal_SlantPathIonoGroup';
end  



%% DELAY:
groupDelayWAmbigCell = num2cell(out_struct.(tau_folder).(tau_file).(tau_field).val);

%% SIGMA DELAY:
groupDelaySigCell = num2cell(out_struct.(sigma_tau_folder).(sigma_tau_file).(sigma_tau_field).val);
%% IONOSPHERIC DELAY, SIGMA IONOSPHERIC DELAY and DELAY FLAG IONOSPHERIC DELAY::
if isempty(tau_ion_folder)
    ionoDelCell = num2cell(zeros(1,length(groupDelayWAmbigCell)));
    ionoDelSigCell = num2cell(zeros(1,length(groupDelayWAmbigCell)));
    ionoDelFlagcell = num2cell(zeros(1,length(groupDelayWAmbigCell)));
    fprintf('With this setting ionospheric delay will not be used\n')
else
    if isfield(out_struct.(tau_ion_folder),tau_ion_file)            
        ionoDelCell = num2cell(1e9*out_struct.(tau_ion_folder).(tau_ion_file).(tau_ion_field).val(1,:)); % cell: 1 x nObs            
        ionoDelSigCell = num2cell(1e9*out_struct.(sigma_tau_ion_folder).(sigma_tau_ion_file).(sigma_tau_ion_field).val(1,:)); % cell: 1 x nObs
        if isfield(out_struct.(tau_ion_folder).(tau_ion_file), 'Cal_SlantPathIonoGroupDataFlag') % if iono flag is given
            ionoDelFlagcell = num2cell(double(out_struct.(tau_ion_folder).(tau_ion_file).Cal_SlantPathIonoGroupDataFlag.val));
            fprintf('Ionospheric delay Flag will be used\n')
        else
            ionoDelFlagcell = num2cell(zeros(1,length(groupDelayWAmbigCell)));
        end
        fprintf('Ionospheric delay will be used\n')
    else
        fprintf('Can find Inospheric Delay File\n')
        warning('Ionospheric delay can not be used because was not found\n')
    end
end

%% DELAY FLAG DELAY:
nc_filename = get_nc_filename({'Edit', institution_tag}, wrapper_data.Observation.ObsEdit.files);
delayFlagLikeNGS    = num2cell(out_struct.ObsEdit.(nc_filename).DelayFlag.val);

%% SIGMA FINAL DELAY:  
delaySigmaTimesIonoSigma=num2cell(sqrt([groupDelaySigCell{:}].^2 + ([ionoDelSigCell{:}]*1e-9).^2)); % [sec]    cell: 1 x nObs

%% FILL SCAN STRUCT
% get number of antennas per scan
nAntPerScan=sum(scan2Station>0,2); % vector (nRows=nScans), giving number of participatin (in Scan) stations
% simply create vector from one to 40
oneToN=1:40;
% scan.mjd /.iso
% yr; mo; day; hr; minute; sec. (num cols = num scans)

nc_filename = get_nc_filename({'TimeUTC'}, wrapper_data.Scan.Scan.files);
if length(out_struct.Scan.TimeUTC.Second.val) == 1
    out_struct.Scan.(nc_filename).Second.val = zeros(length(out_struct.Scan.TimeUTC.YMDHM.val),1);
end
tim=[double(out_struct.Scan.(nc_filename).YMDHM.val); out_struct.Scan.(nc_filename).Second.val'];

scanMjd =  modjuldat(double(out_struct.Scan.(nc_filename).YMDHM.val(1,:)'), double(out_struct.Scan.(nc_filename).YMDHM.val(2,:)'), double(out_struct.Scan.(nc_filename).YMDHM.val(3,:)')) + ...
    double(out_struct.Scan.(nc_filename).YMDHM.val(4,:))'./24 + double(out_struct.Scan.(nc_filename).YMDHM.val(5,:))'./60./24 + out_struct.Scan.(nc_filename).Second.val/60/60/24;

scanMjdCell=num2cell(scanMjd);
scanSouCell=num2cell(scan2Source);
[scan(1:end-1).mjd]=deal(scanMjdCell{:});
[scan(1:end-1).iso]=deal(scanSouCell{:});
[itim,doy]=dday(tim(1,:),tim(2,:),tim(3,:),tim(4,:),tim(5,:));

% substructs need a for-loop
obsI1Index=1;
for iScan=1:nScans
    % scan.nobs
    scan(iScan).nobs=sum(obs2Scan==iScan);
    scan(iScan).tim=[tim(:,iScan);doy(iScan)];
    % +++ scan.stat +++
    
    % "preallocate"
    scan(iScan).stat(nAntPerScan(iScan))=subStruct_stat;

    % for each station in current scan get the observation number
    stationsInCurScan=logical(scan2Station(iScan,:));
    stationIndices=oneToN(stationsInCurScan);
    
    % for all stations in current scan
    for iStat=1:length(stationIndices)
        
        % Get nc file-list for the current station from the wrapper:
        stat_id = stationIndices(iStat);
        stat_name = deblank(out_struct.head.StationList.val(:,stat_id)');
        wrapper_stat_file_list = wrapper_data.Station.(stat_name).files;
        
        
        %% #### Met. data ####
        
        % ### scan.stat.temp ###
        % Check data availability:
        nc_filename = get_nc_filename({'Met'}, wrapper_stat_file_list);
        if ~isempty(out_struct.stat(stationIndices(iStat)).(nc_filename))
            if isfield(out_struct.stat(stationIndices(iStat)).(nc_filename), 'TempC')
                tdry = out_struct.stat(stationIndices(iStat)).(nc_filename).TempC.val(scan2Station(iScan,stationIndices(iStat)));
            else
                tdry = error_code_invalid_met_data;
            end
        else
            tdry = error_code_invalid_met_data;
        end
        % Check data value:
        if tdry ~= error_code_invalid_met_data
            if (tdry < -99)
                tdry = error_code_invalid_met_data;
            end
        end
        scan(iScan).stat(stationIndices(iStat)).temp = tdry;

        % ### scan.stat.pres ###
        % Check data availability:
        if ~isempty(out_struct.stat(stationIndices(iStat)).(nc_filename))
            if isfield(out_struct.stat(stationIndices(iStat)).(nc_filename), 'AtmPres')
                pres = out_struct.stat(stationIndices(iStat)).(nc_filename).AtmPres.val(scan2Station(iScan,stationIndices(iStat)));
            else
                pres = error_code_invalid_met_data;
            end
        else
            pres = error_code_invalid_met_data;
        end
        % Check data value:
        if pres ~= error_code_invalid_met_data
            if (pres < 0)
                pres = error_code_invalid_met_data;
            end
        end
        scan(iScan).stat(stationIndices(iStat)).pres = pres;
        
        % ### scan.stat.e ###
        % Check data availability:
        if ~isempty(out_struct.stat(stationIndices(iStat)).(nc_filename))
            if isfield(out_struct.stat(stationIndices(iStat)).(nc_filename), 'RelHum')
                relHum = out_struct.stat(stationIndices(iStat)).(nc_filename).RelHum.val(scan2Station(iScan,stationIndices(iStat)));
            else
                relHum = error_code_invalid_met_data;
            end
        else
            relHum = error_code_invalid_met_data;
        end
        % Check data value:
        if (relHum ~= error_code_invalid_met_data) && (tdry ~= error_code_invalid_met_data) 
            if (tdry > -99) && (relHum > 0)
                e = 6.1078 * exp((17.1 * tdry) / (235 + tdry)) * relHum;   % formula by Magnus * relative humidity
            else
                e = error_code_invalid_met_data;
            end
        else
            e = error_code_invalid_met_data;
        end
        scan(iScan).stat(stationIndices(iStat)).e = e;
            
        
        % #### Cable Cal. ####
        nc_filename = get_nc_filename({'Cal-Cable'}, wrapper_stat_file_list);
        nc_filename = strrep(nc_filename,'-','_');
        % scan.stat.cab
        if isfield(out_struct.stat(stationIndices(iStat)), nc_filename)
            scan(iScan).stat(stationIndices(iStat)).cab = 1e9*out_struct.stat(stationIndices(iStat)).(nc_filename).Cal_Cable.val(scan2Station(iScan,stationIndices(iStat))); % [nano-sec]
        else
            scan(iScan).stat(stationIndices(iStat)).cab = 0; % [nano-sec]            
        end
    end
    %% --- scan.stat ---
    
    % +++ scan.obs +++

    
    % "preallocate"
    scan(iScan).obs(scan(iScan).nobs)=subStruct_obs;
    [scan(iScan).obs.i1] = deal(obs2BaselineCell{obsI1Index:obsI1Index+scan(iScan).nobs-1,1});
    [scan(iScan).obs.i2] = deal(obs2BaselineCell{obsI1Index:obsI1Index+scan(iScan).nobs-1,2});

    [scan(iScan).obs.obs]=   deal(groupDelayWAmbigCell{obsI1Index:obsI1Index+scan(iScan).nobs-1}); % [sec]
    [scan(iScan).obs.sig]=deal(delaySigmaTimesIonoSigma{obsI1Index:obsI1Index+scan(iScan).nobs-1}); % [sec]
    [scan(iScan).obs.delion]=   deal(ionoDelCell{obsI1Index:obsI1Index+scan(iScan).nobs-1}); % [nano-sec]
    [scan(iScan).obs.sgdion]=   deal(ionoDelSigCell{obsI1Index:obsI1Index+scan(iScan).nobs-1}); % [nano-sec]
    [scan(iScan).obs.q_code_ion]=   deal(ionoDelFlagcell{obsI1Index:obsI1Index+scan(iScan).nobs-1});
    
    if length(delayFlagLikeNGS)==1 % check length of delay flag vector, if it is only 1 value for the whole session, this value will be assigned to all observations
        [scan(iScan).obs.q_code]=deal(double(delayFlagLikeNGS{1}).*ones(scan(iScan).nobs,1));          
    else
        [scan(iScan).obs.q_code]=deal(delayFlagLikeNGS{obsI1Index:obsI1Index+scan(iScan).nobs-1});   
    end
    
    
    
    
    obsI1Index=obsI1Index+scan(iScan).nobs;

    
    ionosphereCorrection    = 1;
    cableCalibration        = 1;
%     % "modify" delay for cable cal and iono delay
    if cableCalibration == 1
        for iObs=1:length(scan(iScan).obs)
            corcab=scan(iScan).stat(scan(iScan).obs(iObs).i2).cab-...
                scan(iScan).stat(scan(iScan).obs(iObs).i1).cab; % [ns]
            scan(iScan).obs(iObs).obs=scan(iScan).obs(iObs).obs+... 
               corcab*(1e-9);
        end
    end
    if ionosphereCorrection == 1
        for iObs=1:length(scan(iScan).obs)
            scan(iScan).obs(iObs).obs=scan(iScan).obs(iObs).obs-...        
                scan(iScan).obs(iObs).delion*(1e-9); % [sec]
        end
    end
    % --- scan.obs ---
    
    % +++ scan.space +++
    scan(iScan).space=space0;
    % --- scan.space ---
    
    % +++ scan.obs_type +++
    scan(iScan).obs_type = 'q';
end

% delete last scan entry (which was never needed)
scan(end)=[];
% fprintf('nc2scan finished\n')




%% #### Sub-functions 

function fieldname_str = get_nc_filename(field_name_pattern, wrapper_data_files)
% Input: 
% - field_name_pattern (Cell-array): Cell-array with 1 or more strings, which are matched with entries in "wrapper_data_files"
% - wrapper_data_files (Cell-array): containing name of .nc files

    flag_generate_error_msg = 0;

    switch(nargin)
        case 3
            flag_generate_error_msg = varargin{3};
    end

    % Check input:
    if ~iscell(field_name_pattern)
        field_name_pattern = {field_name_pattern};
    end
    if ~iscell(wrapper_data_files)
        wrapper_data_files = {wrapper_data_files};
    end
    
    % Init.:
    flaglist_match_wrapper_data_files = true(length(wrapper_data_files), length(field_name_pattern));
    
    % Select file from list according to "field_name_default"  
    for i_1 = 1 : length(field_name_pattern)
        for i_2 = 1 : length(wrapper_data_files)
            flaglist_match_wrapper_data_files(i_2, i_1) = flaglist_match_wrapper_data_files(i_2, i_1) && ~isempty(strfind(wrapper_data_files{i_2},field_name_pattern{i_1}));
        end
    end
    
    % Check, wich file in "wrapper_data_files" matches all strings in "field_name_default":
    ind = true(length(wrapper_data_files), 1);
    for i_1 = 1 : length(field_name_pattern)
        ind = ind & flaglist_match_wrapper_data_files(:, i_1);
    end
    
    % Check, if there is a match:
    if sum(ind) == 1 % one match
        tmp_str = wrapper_data_files{ind};
        % Remove the ".nc" file ending:
        fieldname_str = tmp_str(1 : strfind(tmp_str, '.nc')-1);
    elseif sum(ind) >= 1 % more than 1 match
        error('More than 1 match was found!');
    else % sum == 0, no match
        fieldname_str = '';
        switch(flag_generate_error_msg)
            case 0
                warning('No match for .nc file (from wrapper) found in out_struct!')
            case 1
                error('No match for .nc file (from wrapper) found in out_struct!')
        end
    end
    
return




