function submit_suffix(~, ~, app)
% Retrieve the suffix value from the input field
suffix = strtrim(app.input_suffix_field.Value);

% Update suffix
app.suffix = suffix;

% Update append (true if the suffix is to be appended, false for removing)
answer = questdlg('What would you like to do?', ...
    'Options', ...
    'Append Suffix', 'Remove Suffix', 'Append Suffix');
% Handle response
switch answer
    case {'Append Suffix', ''}
        app.remove_suffix = false;
    case 'Remove Suffix'
        app.remove_suffix = true;
end

% Clear the input field after submission
app.input_suffix_field.Value = "";

% Update status message
MBDToolFunctions.update_status(app, ['Suffix submitted: "', suffix, '"'], ...
    'type', 'info');
end
