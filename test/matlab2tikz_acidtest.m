function matlab2tikz_acidtest(varargin)
%MATLAB2TIKZ_ACIDTEST    unit test driver for matlab2tikz
%
% MATLAB2TIKZ_ACIDTEST('testFunctionIndices', INDICES, ...) or
%   MATLAB2TIKZ_ACIDTEST(INDICES, ...) runs the test only for the specified
%   indices. When empty, all tests are run. (Default: []).
%
% MATLAB2TIKZ_ACIDTEST('extraOptions', {'name',value, ...}, ...)
%   passes the cell array of options to MATLAB2TIKZ. Default: {}
%
% MATLAB2TIKZ_ACIDTEST('figureVisible', LOGICAL, ...)
%   plots the figure visibly during the test process. Default: false
%
% See also matlab2tikz, testfunctions

% Copyright (c) 2008--2014, Nico Schlömer <nico.schloemer@gmail.com>
% All rights reserved.
%
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
%    * Redistributions of source code must retain the above copyright
%      notice, this list of conditions and the following disclaimer.
%    * Redistributions in binary form must reproduce the above copyright
%      notice, this list of conditions and the following disclaimer in
%      the documentation and/or other materials provided with the distribution
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
% =========================================================================

  % In which environment are we?
  env = getEnvironment();
  if ~strcmp(env, 'MATLAB') && ~strcmp(env, 'Octave')
      error('Unknown environment. Need MATLAB(R) or GNU Octave.')
  end


  % -----------------------------------------------------------------------
  matlab2tikzOpts = matlab2tikzInputParser;

  matlab2tikzOpts = matlab2tikzOpts.addOptional(matlab2tikzOpts, ...
                                                'testFunctionIndices', ...
                                                [], @isfloat);
  matlab2tikzOpts = matlab2tikzOpts.addParamValue(matlab2tikzOpts, ...
                                                  'extraOptions', {}, @iscell);
  matlab2tikzOpts = matlab2tikzOpts.addParamValue(matlab2tikzOpts, ...
                                                  'figureVisible', false, @islogical);

  matlab2tikzOpts = matlab2tikzOpts.parse(matlab2tikzOpts, varargin{:});
  % -----------------------------------------------------------------------

  % first, initialize the tex output
  texfile = 'tex/acid.tex';
  fh = fopen(texfile, 'w');
  assert(fh ~= -1, 'Could not open TeX file ''%s'' for writing.', texfile);
  texfile_init(fh);

  % output streams
  stdout = 1;
  if strcmp(env, 'Octave') && ~matlab2tikzOpts.Results.figureVisible
      % Use the gnuplot backend to work around an fltk bug, see
      % <http://savannah.gnu.org/bugs/?43429>.
      graphics_toolkit gnuplot
  end

  % query the number of test functions
  [dummy, n] = testfunctions(0); %#ok
  
  defaultStatus = emptyStatus();

  if ~isempty(matlab2tikzOpts.Results.testFunctionIndices)
      indices = matlab2tikzOpts.Results.testFunctionIndices;
      % kick out the illegal stuff
      I = find(indices>=1 & indices<=n);
      indices = indices(I);
  else
      indices = 1:n;
  end

  % clean data directory
  fprintf(stdout, 'Cleaning data directory\n\n');
  dataDir = './data/';
  delete(fullfile(dataDir, 'test*'))

  ploterrmsg = cell(length(indices), 1);
  tikzerrmsg = cell(length(indices), 1);
  pdferrmsg  = cell(length(indices), 1);
  ploterror = false(length(indices), 1);
  tikzerror = false(length(indices), 1);
  pdferror  = false(length(indices), 1);
  
  status = cell(length(indices), 1); % cell array to accomodate different structure
  
  for k = 1:length(indices)
      fprintf(stdout, 'Executing test case no. %d...\n', indices(k));

      % open a window
      fig_handle = figure('visible',onOffBoolean(matlab2tikzOpts.Results.figureVisible));

      % plot the figure
      try
          status{k} = testfunctions(indices(k));
          
      catch %#ok
          e = lasterror('reset'); %#ok
          ploterrmsg{k} = format_error_message(e);

          for kError = 1:numel(e.stack);
              ee = e.stack(kError);
              if isempty(status{k}.function)
                  if ~isempty(regexp(ee.name, '^testfunctions>','once'))
                    % extract function name
                    status{k}.function = regexprep(ee.name, '^testfunctions>(.*)', '$1');
                  elseif ~isempty(regexp(ee.name, '^testfunctions','once')) && kError < numel(e.stack)
                    % new stack trace format (R2014b)
                    status{k}.function = e.stack(kError-1).name;
                  end
              end
          end
          status{k}.description = '\textcolor{red}{Error during plot generation.}';
          disp_error_message(env, ploterrmsg{k});
          ploterror(k) = true;
      end
      
      status{k} = fillStruct(status{k}, defaultStatus);
      % Make underscores in function names TeX compatible
      status{k}.functionTeX = strrep(status{k}.function, '_', '\_');
      
      % plot not sucessful
      if status{k}.skip
          close(fig_handle);
          continue
      end

      pdf_file = sprintf('data/test%d-reference.pdf' , indices(k));
      eps_file = sprintf('data/test%d-reference.eps' , indices(k));
      fig_file = sprintf('data/test%d-reference'     , indices(k));
      gen_file = sprintf('data/test%d-converted.tex' , indices(k));

      tic;
      % Save reference output as PDF
      try
          switch env
              case 'MATLAB'
                  % MATLAB does not generate properly cropped PDF files.
                  % So, we generate EPS files that are converted later on.
                  print(gcf, '-depsc2', eps_file);
                  ensureLineEndings(eps_file);
                  
              case 'Octave'
                  % In Octave, figures are properly cropped when using  print().
                  print(pdf_file, '-dpdf', '-S415,311', '-r150');
                  pause(1.0)
              otherwise
                  error('Unknown environment. Need MATLAB(R) or GNU Octave.')
          end
      catch %#ok
          e = lasterror('reset'); %#ok
          pdferrmsg{k} = format_error_message(e);
          disp_error_message(env, pdferrmsg{k});
          pdferror(k) = true;
      end
      % now, test matlab2tikz
      try
          cleanfigure(status{k}.extraCleanfigureOptions{:});
          matlab2tikz('filename', gen_file, ...
                      'showInfo', false, ...
                      'checkForUpdates', false, ...
                      'relativeDataPath', '../data/', ...
                      'dataPath', dataDir, ...
                      'width', '\figurewidth', ...
                      matlab2tikzOpts.Results.extraOptions{:}, ...
                      status{k}.extraOptions{:} ...
                     );
      catch %#ok
          e = lasterror('reset'); %#ok
          tikzerrmsg{k} = format_error_message(e);
          disp_error_message(env, tikzerrmsg{k});
          tikzerror(k) = true;
      end

      % ...and finally write the bits to the LaTeX file
      texfile_addtest(fh, fig_file, gen_file, status{k}.description, ...
                      status{k}.functionTeX, indices(k), pdferror(k), tikzerror(k));

      if ~status{k}.closeall
          close(fig_handle);
      else
          close all;
      end

      elapsedTime = toc;
      fprintf(stdout, '%s ', status{k}.function);
      fprintf(stdout, 'done (%4.2fs).\n\n', elapsedTime);
  end

  % Write the summary table to the LaTeX file
  texfile_tab_completion_init(fh)
  for k = 1:length(indices)
      % Break table up into pieces if it gets too long for one page
      if ~mod(k,35)
          texfile_tab_completion_finish(fh);
          texfile_tab_completion_init(fh);
      end

      fprintf(fh, '%d & \\texttt{%s}', indices(k), status{k}.functionTeX);
      if status{k}.skip
          fprintf(fh, ' & --- & skipped & ---');
      else
          for err = [ploterror(k), pdferror(k), tikzerror(k)]
              if err
                  fprintf(fh, ' & \\textcolor{red}{failed}');
              else
                  fprintf(fh, ' & \\textcolor{green!50!black}{passed}');
              end
          end
      end
      fprintf(fh, ' \\\\\n');
  end
  texfile_tab_completion_finish(fh);

  % Write the error messages to the LaTeX file if there are any
  if any([ploterror ; tikzerror ; pdferror])
      fprintf(fh, '\\section*{Error messages}\n\\scriptsize\n');
      for k = 1:length(indices)
          if isempty(ploterrmsg{k}) && isempty(tikzerrmsg{k}) && isempty(pdferrmsg{k})
              continue % No error messages for this test case
          end

          fprintf(fh, '\n\\subsection*{Test case %d: \\texttt{%s}}\n', indices(k), status{k}.functionTeX);
          print_verbatim_information(fh, 'Plot generation', ploterrmsg{k});
          print_verbatim_information(fh, 'PDF generation' , pdferrmsg{k} );
          print_verbatim_information(fh, 'matlab2tikz'    , tikzerrmsg{k});
      end
      fprintf(fh, '\n\\normalsize\n\n');
  end

  % now, finish off the file and close file and window
  texfile_finish(fh);
  fclose(fh);

end
% =========================================================================
function texfile_init(texfile_handle)

  fprintf(texfile_handle, ...
           ['\\documentclass[landscape]{scrartcl}\n'                , ...
            '\\pdfminorversion=6\n\n'                               , ...
            '\\usepackage{amsmath} %% required for $\text{xyz}$\n\n', ...
            '\\usepackage{graphicx}\n'                              , ...
            '\\usepackage{epstopdf}\n'                              , ...
            '\\usepackage{tikz}\n'                                  , ...
            '\\usetikzlibrary{plotmarks}\n\n'                       , ...
            '\\usepackage{pgfplots}\n'                              , ...
            '\\pgfplotsset{compat=newest}\n\n'                      , ...
            '\\usepackage[margin=0.5in]{geometry}\n'                , ...
            '\\newlength\\figurewidth\n'                            , ...
            '\\setlength\\figurewidth{0.4\\textwidth}\n\n'          , ...
            '\\begin{document}\n\n']);

end
% =========================================================================
function texfile_finish(texfile_handle)

    [env,versionString] = getEnvironment();


  fprintf(texfile_handle, ...
      [
      '\\newpage\n',...
      '\\begin{tabular}{ll}\n',...
      '  Created  & ' datestr(now) ' \\\\ \n', ...
      '  OS       & ' OSVersion ' \\\\ \n',...
      '  ' env '  & ' versionString ' \\\\ \n', ...
      VersionControlIdentifier, ...
      '  Pgfplots & \\expandafter\\csname ver@pgfplots.sty\\endcsname \\\\ \n',...
      '\\end{tabular}\n',...
      '\\end{document}']);

end
% =========================================================================
function print_verbatim_information(texfile_handle, title, contents)
    if ~isempty(contents)
        fprintf(texfile_handle, ...
                ['\\subsubsection*{%s}\n', ...
                 '\\begin{verbatim}\n%s\\end{verbatim}\n'], ...
                title, contents);
    end
end
% =========================================================================
function texfile_addtest(texfile_handle, ref_file, gen_file, desc, ...
                          funcName, funcId, ref_error, gen_error)
  % Actually add the piece of LaTeX code that'll later be used to display
  % the given test.

  fprintf(texfile_handle, ...
          ['\\begin{figure}\n'                                          , ...
           '  \\centering\n'                                            , ...
           '  \\begin{tabular}{cc}\n'                                   , ...
           '    %s & %s \\\\\n'                                         , ...
           '    reference rendering & generated\n'                      , ...
           '  \\end{tabular}\n'                                         , ...
           '  \\caption{%s \\texttt{%s}, \\texttt{testFunctions(%d)}}\n', ...
          '\\end{figure}\n'                                             , ...
          '\\clearpage\n\n'],...
          include_figure(ref_error, 'includegraphics', ref_file), ...
          include_figure(gen_error, 'input', gen_file), ...
          desc, funcName, funcId);

end
% =========================================================================
function str = include_figure(errorOccured, command, filename)
    if errorOccured
        str = sprintf(['\\tikz{\\draw[red,thick] ', ...
                       '(0,0) -- (\\figurewidth,\\figurewidth) ', ...
                       '(0,\\figurewidth) -- (\\figurewidth,0);}']);
    else
        switch command
            case 'includegraphics'
                strFormat = '\\includegraphics[width=\\figurewidth]{../%s}';
            case 'input'
                strFormat = '\\input{../%s}';
            otherwise
                error('Matlab2tikz_acidtest:UnknownFigureCommand', ...
                      'Unknown figure command "%s"', command);
        end
        str = sprintf(strFormat, filename);
    end
end
% =========================================================================
function texfile_tab_completion_init(texfile_handle)

  fprintf(texfile_handle, ['\\clearpage\n\n'                            , ...
                           '\\begin{table}\n'                           , ...
                           '\\centering\n'                              , ...
                           '\\caption{Test case completion summary}\n'  , ...
                           '\\begin{tabular}{rlccc}\n'                  , ...
                           'No. & Test case & Plot & PDF & TikZ \\\\\n' , ...
                           '\\hline\n']);

end
% =========================================================================
function texfile_tab_completion_finish(texfile_handle)

  fprintf(texfile_handle, ['\\end{tabular}\n' , ...
                           '\\end{table}\n\n' ]);

end
% =========================================================================
function [env,versionString] = getEnvironment()
  % Check if we are in MATLAB or Octave.
  % Calling ver with an argument: iterating over all entries is very slow
  alternatives = {'MATLAB','Octave'};
  for iCase = 1:numel(alternatives)
      env   = alternatives{iCase};
      vData = ver(env);
      if ~isempty(vData)
          versionString = vData.Version;
          return; % found the right environment
      end
  end
  % otherwise:
  env = [];
  versionString = [];
end
% =========================================================================
function [formatted, OSType, OSVersion] = OSVersion()
    if ismac
        OSType = 'Mac OS';
        [dummy, OSVersion] = system('sw_vers -productVersion');
    elseif ispc
        OSType = 'Windows';
        [dummy, OSVersion] = system('ver');
    elseif isunix
        OSType = 'Unix';
        [dummy, OSVersion] = system('uname -r');
    else
        OSType = '';
        OSVersion = '';
    end
    formatted = strtrim([OSType ' ' OSVersion]);
end
% =========================================================================
function msg = format_error_message(e)
    msg = '';
    if ~isempty(e.message)
        msg = sprintf('%serror: %s\n', msg, e.message);
    end
    if ~isempty(e.identifier)
        msg = sprintf('%serror: %s\n', msg, e.identifier);
    end
    if ~isempty(e.stack)
        msg = sprintf('%serror: called from:\n', msg);
        for ee = e.stack(:)'
            msg = sprintf('%serror:   %s at line %d, in function %s\n', ...
                          msg, ee.file, ee.line, ee.name);
        end
    end
end
% =========================================================================
function disp_error_message(env, msg)
    stderr = 2;
    % When displaying the error message in MATLAB, all backslashes
    % have to be replaced by two backslashes. This must not, however,
    % be applied constantly as the string that's saved to the LaTeX
    % output must have only one backslash.
    if strcmp(env, 'MATLAB')
        fprintf(stderr, strrep(msg, '\', '\\'));
    else
        fprintf(stderr, msg);
    end
end
% =========================================================================
function [formatted,treeish] = VersionControlIdentifier()
% This function gives the (git) commit ID of matlab2tikz
%
% This assumes the standard directory structure as used by Nico's master branch:
%     SOMEPATH/src/matlab2tikz.m with a .git directory in SOMEPATH.
%
% The HEAD of that repository is determined from file system information only
% by following dynamic references (e.g. ref:refs/heds/master) in branch files
% until an absolute commit hash (e.g. 1a3c9d1...) is found.
% NOTE: Packed branch references are NOT supported by this approach
    MAXITER     = 10; % stop following dynamic references after a while
    formatted   = '';
    REFPREFIX   = 'ref:';
    isReference = @(treeish)(any(strfind(treeish, REFPREFIX)));
    treeish     = [REFPREFIX 'HEAD'];
    try
        % get the matlab2tikz directory
        m2tDir = fileparts(mfilename('fullpath'));
        gitDir = fullfile(m2tDir,'..','.git');

        nIter = 1;
        while isReference(treeish)
            refName    = treeish(numel(REFPREFIX)+1:end);
            branchFile = fullfile(gitDir, refName);

            if exist(branchFile, 'file') && nIter < MAXITER
                fid     = fopen(branchFile,'r');
                treeish = fscanf(fid,'%s');
                fclose(fid);
                nIter   = nIter + 1;
            else % no branch file or iteration limit reached
                treeish = '';
                return;
            end
        end
    catch %#ok
        treeish = '';
    end
    if ~isempty(treeish)
        formatted = ['  Commit & ' treeish ' \\\\ \n'];
    end
end
% =========================================================================
function onOff = onOffBoolean(bool)
if bool
    onOff = 'on';
else
    onOff = 'off';
end
end
% =========================================================================
function ensureLineEndings(filename)
% Read in one line and test the ending
fid = fopen(filename,'r+');
testline = fgets(fid);
if ispc && ~strcmpi(testline(end-1:end), sprintf('\r\n'))
    % Rewind, read the whole
    fseek(fid,0,'bof'); 
    str = fread(fid,'*char')'; 

    % Replace, overwrite and close
    str = regexprep(str, '\n|\r','\r\n');
    fseek(fid,0,'bof'); 
    fprintf(fid,'%s',str);
    fclose(fid);
end
end
% =========================================================================
function defaultStatus = emptyStatus()
% constructs an empty status struct
defaultStatus = struct('function',               '', ...
                       'description',            '',...
                       'issues',                 [],...
                       'skip',                   false, ... % skipped this test?
                       'closeall',               false, ... % call close all after?
                       'extraOptions',           {cell(0)}, ...
                       'extraCleanfigureOptions',{cell(0)});
end
% =========================================================================
function [status] = fillStruct(status, defaultStatus)
% fills non-existant fields of |data| with those of |defaultData|
  fields = fieldnames(defaultStatus);
  for iField = 1:numel(fields)
      field = fields{iField};
      if ~isfield(status,field)
          status.(field) = defaultStatus.(field);
      end
  end
end
% =========================================================================