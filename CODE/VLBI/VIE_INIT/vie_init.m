% ************************************************************************
%   Description:
%   The first part of VieVS. Reads the data from the NGS files and some
%   additional inforamtion.
%
%   Input:	
%      Uses the parameter file stored in currentf_pa.mat. The string
%      ngsfile, containing the name of NGS-file to be processed must exist
%      in the workspace.
%   Input arguments:
%    - ngsfile                  - directory and name of the input file (e.g. "2005/05APR04XA_N004")
%    - parameter                - VieVS parameter structure (contains GUI parameters)
%    - out_vie_init_subdir      - sub-directory for VIE_INIT (LEVEL0)
%    - ngsdir                   - Input file directiory (if it is empty the default path is used for different input file formats: "ngsdir_tmp")
%    - trf                      - TRF data structure (optional)
%    - crf                      - CRF data structure (optional)
%
%   Output:
%      The antenna, scan, and sources structure arrays, saved in the
%      in the LEVEL0 directory.
% 
%   External calls: 	
%   	read_ngs.m	  
%       read_vso.m
%       get_trf_and_crf.m
%       constants.m
%       read_vgosdb_input_settings.m
%       
%   Coded for VieVS: 
%   May 2009 by Tobias Nilsson
%
%   Revision: 
%   18 Nov 2009 by Tobias Nilsson: the program now reads the outlier-file
%     for the session if it exist and specified in the option. The
%     information from the outlier-file is used in read_ngs.
%   28 Jan 2010 by Tobias Nilsson: Outliers now read from yearly
%     directories (../DATA/OUTLIERS/YYYY/).
%   24 Feb 2010 by Tobias Nilsson: file paths for input and output are modified 
%     user defined sub-directory for input and output is available
%   26 Feb 2010 by Tobias Nilsson: Possible to use different subdirectories
%     for outliers.
%   24 Jan 2011 by Hana Spicakova: choice between GPT function
%      (Global Pressure and Temperature) for all observations and measured 
%      meteorological data from NGS file with GPT only as backup
%   18 Apr 2011 by TObias Nilsson: Changed input/output variables
%   04 May 2011 by Matthias Madzak: New parameter variables
%       (parameter.vie_init.iono, _.ionoFolder) to ini_opt (they are needed
%       in read_ngs).
%   09 May 2011 by Tobias Nilsson: Now also the baselines excluded
%               are printed on the screen.
%   13 Nov 2012 by Hana Kr???sn???: antenna offset and mounting type taken from
%               superstatin file (antenna_info). No more from NGS header.
%   14 Mar 2013 by Matthias Madzak: implementation of supersource file.
%   05 Feb 2014 by Lucia Plank: read JET files
%   16 May 2014 by Monika Tercjak: reading and saving names of stations
%               which should be down-weighted
%   30 May 2014 by David Mayer: a message when no OPT file was found 
%   26 Sep 2014 by Hana Krasna: bug fixed, by simulations the Outlier
%               directory is now recognised
%   11 Nov 2014 by A. Hellerschmied: added option to decide wether to use
%               OPT files or not.
%   12 Jan 2015 by Caroline/Matthias: NO CABLE CAL Info print at command 
%               window
%   14 Jan 2015 by Daniel Landskron: output in Command Window slightly
%               modified
%   20 Jul 2015 by A. Girdiuk: output start and end time moments for
%       excluded station
%   21 Jul 2015 by A.Girdiuk: output for outliers list
%   04 Dec 2015 by A. Hellerschmied: OPT file is now loaded in VIE_INIT only!
%   10 Dec 2015 by A. Hellerschmied: Bug fix: Init. of clock break and ref. 
%       station data added in case no OPT file is available.
%   08 Jan 2016 by M. Madzak: Added read possibility for reading vgos-db
%       (netCDF) files
%   28 Jan 2016 by C. Sch???nberger: sources can be excluded for a certain time span.
%   28 Jun 2016 by A. Hellerschmied: Changes in call of read_ngs.m
%   12 Jul 2016 by A. Hellerschmied: Revised vie_init.m for VieVS 3.0:
%                   - enhanced support of vgosDB files as data input
%                   - support of VSO files as data input
%                   - Many small changes and fixes
%   17 Jul 2016 by A. Hellerschmied: - Content of "sources" structure (natural sources, quasars) is now stored in the sub-structure "sources.q"
%                                    - The sub-structure "sources.sc" can be used to define space-crafts
%   27 Jul 2016 by D. Mayer: Bug fix: Sessions with 2 underscores are now read correctly 
%   03 Aug 2016 by A. Hellerschmied: Enhanced support of .vso files as input data.
%   08 Aug 2016 by A. Girdiuk: bug-fix: parameter initialization is added for stations to be down-weighted
%   09 Aug 2016 by A. Hellerschmied: "sources.sc" changed to "sources.s"
%   21 Sep 2016 by A. Hellerschmied: Possibility added to read space craft ephemerids (TRF positions and velocities) from an external file
%   26 Oct 2016 by A. Hellerschmied: When loading vso files the fileapth is now taken from "parameter.filepath" (defined in vie_batchX_X.m)
%   08 Nov 2016 by D. Mayer: Sources can be deleted from .txt file
%   10 Nov 2016 by H. Krasna: exclude sources with <3 observations from the
%               NNR constraints, or fixed them if the sources are estimated as 
%               pwl offsets to avoid singularity
%   07 Feb 2017 by A. Hellerschmied: "parameter" structure added as in/output arguments for read_vso.m
%   14.Feb 2017 by M. Schartner: new optional parameters: trf and crf.
%   22 Feb 2017 by A. Hellerschmied: Manual TRF file support established
%   23 Feb 2017 by A. Hellerschmied: get_trf_and_crf.m used for loading CRF and TRF data
%   14 Mar 2017 by A. Hellerschmied: call of function "constants.m"
%   31 Mar 2017 by D. Mayer: added the possibility to remove list of
%   			station from every session in the code
%   13 Nov 2017 by J. Gruber: new functions to specify insitute provider,
%   			version name and frequency band (read_vgosdb_input_settings.m)
%   06 Jan 2018 by J. Gruber: Changed call of cleanScan.m

% ************************************************************************
%
function [antenna,sources,scan,parameter]=vie_init(ngsfile, parameter, out_vie_init_subdir, ngsdir, varargin)
disp('---------------------------------------------------------------')
disp('|                  Welcome to VIE_INIT!!!!!                   |')
disp('---------------------------------------------------------------')
disp(' ')

% Call the constants function to get the global variables for constants:
constants;
% Get the session name:
switch(parameter.data_type)
    case 'ngs'
%         parameter.session_name  = ngsfile(6 : end);
        ngsdir_tmp              = 'NGS';
        index_underscore_in_name = strfind(parameter.session_name, '_');
        if size(index_underscore_in_name,2) == 1
            optfil                  = ['../DATA/OPT/', parameter.vie_init.diropt, '/', parameter.year, '/', parameter.session_name(1 : (index_underscore_in_name(1) - 1)), '.OPT'];
        elseif size(index_underscore_in_name,2) == 2
            optfil                  = ['../DATA/OPT/', parameter.vie_init.diropt, '/', parameter.year, '/', parameter.session_name(1 : (index_underscore_in_name(2) - 1)), '.OPT'];
        else
            warning('More than 2 underscores found in session name! OPT file is not loaded correctly.')
        end
        clear index_underscore_in_name
        outfile                 = ['../DATA/OUTLIER/', parameter.vie_init.dirout, '/', parameter.year, '/', parameter.session_name, '.OUT'];
%         fprintf(' ==> Input file format: NGS\n');
    case 'vso'
%         parameter.session_name  = ngsfile(6 : (strfind(ngsfile, ' [VSO]')-1));
        ngsdir_tmp              = 'VSO';
        optfil                  = ['../DATA/OPT/', parameter.vie_init.diropt, '/', parameter.year, '/', parameter.session_name, '.OPT'];
        outfile                 = ['../DATA/OUTLIER/', parameter.vie_init.dirout, '/', parameter.year, '/', parameter.session_name, '.OUT'];
%         fprintf(' ==> Input file format: VSO\n');
    case 'vgosdb'
%         parameter.session_name  = ngsfile(6 : (strfind(ngsfile, ' [vgosDB]')-1));
        ngsdir_tmp              = 'vgosDB';
        optfil                  = ['../DATA/OPT/', parameter.vie_init.diropt, '/', parameter.year, '/', parameter.session_name, '.OPT'];
        outfile                 = ['../DATA/OUTLIER/', parameter.vie_init.dirout, '/', parameter.year, '/', parameter.session_name, '.OUT'];
%         fprintf(' ==> Input file format: vgosDB\n');
end % switch(parameter.data_type)

session = parameter.session_name;

% check if ngsdir exists:
if exist('ngsdir', 'var')
    if isempty(ngsdir)
        ngsdir = ngsdir_tmp;
    end
else
    ngsdir = ngsdir_tmp;
end


%% ##### CRF + TRF #####
trffile = parameter.vie_init.trf;
crffile = parameter.vie_init.crf;

% Load TRF and CRF data, if the data are not provided as input arguments
if isempty(varargin)
    [trf, crf, parameter] = get_trf_and_crf(parameter);
else
    trf = varargin{1};
    crf = varargin{2};
end


%%  +++++++++++++++++ GET OPT STUFF +++++++

ini_opt.sta_excl='';
ini_opt.sour_excl='';
ini_opt.stat_dw=''; 
ini_opt.bas_excl=[];
ini_opt.no_cab='';
ini_opt.scan_excl=[];
bas_excl='';
remove_sprecial_stations = false;
stations_to_be_removed = {''; ''; ''; ''};

% read OPT-file (clock breaks exclusion, etc...), if parameter.vie_init.use_opt_files - flag is set.
if parameter.vie_init.use_opt_files
    if exist(optfil, 'file')
        [ini_opt, bas_excl]=readOPT(optfil,remove_sprecial_stations,stations_to_be_removed);
        parameter.vie_init.ref_clk_name     = ini_opt.refclock;         % If no reference clock is defined in the OPt file, this field conatin an empty string ('')!
        parameter.vie_init.num_clk_breaks   = ini_opt.num_clk_breaks;   % Number of clock braeks in OPT file
        parameter.vie_init.clk_break        = ini_opt.clk_break;        % Clock break info (structure)
    else
        fprintf('No OPT file was found\n');
        parameter.vie_init.ref_clk_name     = ''; % If no reference clock is defined in the OPt file, this field conatin an empty string ('')!
        parameter.vie_init.num_clk_breaks   = 0;
        parameter.vie_init.clk_break        = [];
        if remove_sprecial_stations
            ini_opt.sta_excl = char(stations_to_be_removed);
            ini_opt.sta_excl_start = zeros(1,size(stations_to_be_removed,1));
        end
    end
end
% --------------------------------------- (get opt stuff)

% write info about excluded baselines, statinos, sources +++++++++++ 
fprintf('Stations to be excluded: %1.0f\n', size(ini_opt.sta_excl,1))
for k=1:size(ini_opt.sta_excl,1)
    if ini_opt.sta_excl_start(k)==0                                    %%%=> A. Girdiuk 2015-07-20
        fprintf('%s \n', ini_opt.sta_excl(k,:));
    else
        fprintf('%s %f %f\n', ini_opt.sta_excl(k,:), ini_opt.sta_excl_start(k),ini_opt.sta_excl_end(k));
    end                                                                %%%<= A. Girdiuk 2015-07-20
end
  
%------------- Monika
fprintf('Stations to be down-weighted: %1.0f\n', size(ini_opt.stat_dw,1))
if size(ini_opt.stat_dw,1) == 0
    parameter.vie_init.stat_dw = [];
else
	parameter.vie_init.stat_dw = {};
    for k=1:size(ini_opt.stat_dw,1)
        fprintf('%s', ini_opt.stat_dw(k,:),' ', ini_opt.stat_co(k,:))
        fprintf('\n')
        parameter.vie_init.stat_dw(k,:) = {ini_opt.stat_dw(k,:)};
        parameter.vie_init.stat_co(k,:) = str2num(ini_opt.stat_co(k,:));
    end
end
%---------------
    
fprintf('Sources to be excluded: %1.0f\n', size(ini_opt.sour_excl,1))
for k=1:size(ini_opt.sour_excl,1)
    %fprintf('%s\n', ini_opt.sour_excl(k,:))
    if ini_opt.sour_excl_start(k)==0                                    
        fprintf('%s \n', ini_opt.sour_excl(k,:));
    else
        fprintf('%s %f %f\n', ini_opt.sour_excl(k,:), ini_opt.sour_excl_start(k),ini_opt.sour_excl_end(k));
    end 
end

remove_sources_from_list = false;
if remove_sources_from_list
    path2sourcelist = '';     %add the path of your .txt file here. Format is the same as glob input .txt files   
    fid = fopen(path2sourcelist);
    if fid == -1
        warning('File with list of removed sources can not be found\n');
    else
        remove_sources = textscan(fid, '%8s','Delimiter','\n');
        remove_sources = remove_sources{1};
        ini_opt.sour_excl = [ini_opt.sour_excl;char(remove_sources)];
        disp('+ sources from external file removed');
        if isfield(ini_opt, 'sour_excl_start')
        ini_opt.sour_excl_start = [ini_opt.sour_excl_start, zeros(1,length(remove_sources))];
        ini_opt.sour_excl_end = [ini_opt.sour_excl_end, zeros(1,length(remove_sources))];
        else
        ini_opt.sour_excl_start = zeros(1,length(remove_sources));
        ini_opt.sour_excl_end = zeros(1,length(remove_sources));
        end
    end
    fclose(fid);
end

fprintf('Baselines to be excluded: %1.0f\n', size(bas_excl,1))
for k=1:size(bas_excl,1)
    fprintf('%s\n', bas_excl(k,:))
end
fprintf('No cable calibration: %1.0f\n', size(ini_opt.no_cab,1))
for k=1:size(ini_opt.no_cab,1)
    fprintf('%s\n', ini_opt.no_cab(k,:))
end
fprintf('\n')
% -------------------------------------------------------------------    

% +++++++++++++++ OUTLIERS +++++++++++++++++++++++++++++++++++++++++
if (exist(outfile, 'file'))&&(parameter.vie_init.rm_outlier==1)
    [ini_opt.scan_excl]=readOUT(outfile);
    fprintf('the %2d outliers are applied \n',size(ini_opt.scan_excl,2));        %%%=> A. Girdiuk 2015-07-21
    for k=1:size(ini_opt.scan_excl,2)
        fprintf(' %10s %10s %5.2f\n', ini_opt.scan_excl(k).sta1,ini_opt.scan_excl(k).sta2,ini_opt.scan_excl(k).mjd);
    end
else
    fprintf('outliers list is not applied \n');
    if exist(outfile, 'file')==0
        fprintf('outliers list does not exist \n');
    end
end
fprintf('\n')  
% ------------------- OUTLIERS -------------------------------------
   

% +++++++++++++++++++ read jet ang file ++++++++++++++++++++++++++++++++++
% parameter.vie_init.jetfilnam=['../DATA/JETANG/',session(1:min([length(session),14])),'.JETUV'];
parameter.vie_init.jetfilnam    = ['../DATA/JETANG/',session(1:min([length(session),14])),'.JET'];
parameter.vie_init.jetfilnamuv  = ['../DATA/JETANG/',session(1:min([length(session),14])),'.JETUV'];
parameter.vie_init.jetfilnamjb  = ['../DATA/JETANG/',session(1:min([length(session),14])),'.JETJB'];
if parameter.vie_init.ex_jet == 1
    jamax = parameter.vie_init.jetang;
    [ini_opt.scan_jet] = readJET(parameter.vie_init.jetfilnam,jamax);
    fprintf('read JET file: %s\n',parameter.vie_init.jetfilnam)
    fprintf('Number of obs to be excluded due to jet angle: %2.1f %3.0f\n', jamax,length(ini_opt.scan_jet))
else
    ini_opt.scan_jet = [];  
end
% ------------------- read jet ang file -------------------------------------
    
% Set ini_opt parameters
ini_opt.iono    = parameter.vie_init.iono;
ini_opt.minel   = parameter.vie_init.min_elev;
ini_opt.Qlim    = parameter.vie_init.Qlim;
    


%% ##### Load observation data #####

% Distinguish between different input data types:
switch(parameter.data_type)

    % #############################
    % #####     vgosDB        #####
    % #############################
    case 'vgosdb'
    
        % folder of e.g. Head.nc file
        curNcFolder = ['../DATA/vgosDB/',parameter.year, '/',parameter.session_name,'/'];

        % read netCDF data
        [out_struct, nc_info]=read_nc(curNcFolder);
        
        % read vievs input settings from vgosdb_input_settings.tx file 
        [ in, fb, wrapper_k, wrapper_v ] = read_vgosdb_input_settings( 'vgosdb_input_settings.txt' );
        
        % Standard settings, which are used if not defined differently in settings file:
        if isempty(in) % institute
            in = 'IVS';
            fprintf('Set institute to default: %s\n', in)
        end
        if isempty(fb) % frequency band
            fb = 'GroupDelayFull_bX';
            fprintf('Set frequency band to default: %s\n', fb)
        end
        if isempty(wrapper_k) % wrapper tag
            wrapper_k = 'all';
            fprintf('Set wrapper tag to default: %s\n', wrapper_k)
        end
        if isempty(wrapper_v) % wrapper version
            wrapper_v = 'highest_version';
            fprintf('Set wrapper version to default: %s\n', wrapper_v)
        end
        
        % Read wrapper
        wrapper_data = read_vgosdb_wrapper(curNcFolder, parameter.session_name, in, wrapper_k, wrapper_v);
        
        
        % check out_struct
        out_struct = check_out_struct( out_struct, in, wrapper_data);
        
        % get scan, antenna, source struct from netCDF files
        scan        = nc2scan(out_struct, nc_info, fb);
        antenna     = nc2antenna(out_struct, trf, trffile{2});
        sources     = nc2sources(out_struct, crf, crffile{2});
        
        % "clean" scan struct (because of exclusions)
        [scan, sources, antenna] = cleanScan(scan, sources, antenna, out_struct.head.StationList.val', out_struct.head.SourceList.val', ini_opt, bas_excl, parameter.vie_init.Qlim, parameter.vie_init.min_elev);

    
        % Create a sub-structure in "sources" for quasars sources:
        q = sources;
        clear sources
        sources.q   = q;
        sources.s 	= [];
        fprintf('...reading the vgosDB file finished!\n');
    

    % #############################
    % #####     NGS           #####
    % #############################
    case 'ngs'
        fprintf(' => Start reading %s\n',ngsfile);
        if isnan(str2double(ngsfile(1))) % if first element in ngsfile is character - absolute path of NGS file is given
            [antenna,sources,scan] = read_ngs(ngsfile, trffile, crffile, ini_opt, trf, crf);
        else
            [antenna,sources,scan] = read_ngs(['../DATA/' ngsdir '/' ngsfile], trffile, crffile, ini_opt, trf, crf);
        end
        fprintf('...reading the NGS file finished!\n');
        
        
		
        %Sources which were observed less than 3 times in the NGS file.
        NumObs12=find([sources.numobs]<3);
        for i=1:length(NumObs12)
            % if the sources are estimated with the NNR, exclude those
            % sources from the NNR constraint
            if parameter.lsmopt.est_sourceNNR ==1
                sources(NumObs12(i)).in_crf=0;
                sources(NumObs12(i)).flag_defining=0;
                if i==1
                    fprintf('%d sources with <3 observations found. They will not be included in NNR.\n',length(NumObs12));
                end

            % if the sources are estimated as pwl offsets, only non-CRF
            % sources are always estimated, therefore put 1 to the poor
            % observed sources to fixed them and avoid the singularity.
            elseif parameter.lsmopt.pw_sou ==1
                sources(NumObs12(i)).in_crf=1;
                if i==1
                    fprintf('%d sources with <3 observations found. Their coordinates will not be estimated.\n',length(NumObs12));
                end
            end
        end

        
        
        % Create a sub-structure in "sources" for quasars sources:
        q = sources;
        clear sources
        sources.q   = q;
        sources.s 	= [];
        


    % #############################
    % #####     VSO           #####
    % #############################
    case 'vso'
        vso_file_path = parameter.filepath; % ['../DATA/VSO/',parameter.year, '/'];
        vso_file_name = parameter.session_name;
        fprintf(' => Start reading %s\n', [vso_file_path, vso_file_name]);
        
        % Get satellite ephem. file path and name
        str_ind = max([strfind(parameter.vie_init.sc_orbit_file_path_name, '\'), strfind(parameter.vie_init.sc_orbit_file_path_name, '/')]);
        if ~isempty(str_ind)
            sat_orbit_file_path = parameter.vie_init.sc_orbit_file_path_name(1 : str_ind); 
            sat_orbit_file_name = parameter.vie_init.sc_orbit_file_path_name(str_ind+1 : end);
% +++ Workaround solution! Has to be implemented properly in the GUI!
%   => Currently the file type is derived from the file extension 
            % Get file type:
            if strcmp(parameter.vie_init.sc_orbit_file_path_name(end-3 : end), '.sp3')
                parameter.vie_init.sc_orbit_file_type = 'sp3';
            else
                parameter.vie_init.sc_orbit_file_type = 'sat_ephem_trf';
            end
% --- Workaround solution!
            sat_orbit_file_type = parameter.vie_init.sc_orbit_file_type;
        else
            sat_orbit_file_name = '';
            sat_orbit_file_path = '';
            sat_orbit_file_type = '';
        end
        
        [antenna, sources, scan, parameter] = read_vso(vso_file_path, vso_file_name, trf, trffile{2}, crf, crffile{2}, ini_opt, sat_orbit_file_path, sat_orbit_file_name, sat_orbit_file_type, parameter);
        fprintf('...reading the VSO file finished!\n');
        
end % switch(parameter.data_type)


% ##### Write info to CW #####
fprintf('\n');
fprintf('A total of %d stations, %d sources (quasars) and %d scans were found\n', length(antenna), length(sources.q), length(scan));
disp('The following stations were found:')
ind = 1;
for a=1:length(antenna)
  fprintf('%2.0f%s%s\n',ind,'. ',antenna(a).name)
  ind=ind+1;
end
clear ind

% ????????? Needed:
antenna(1).ngsfile=ngsfile;
antenna(1).session=session;

fprintf('\nvie_init successfully finished!\n');

