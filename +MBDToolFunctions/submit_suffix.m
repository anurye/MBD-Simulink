function submit_suffix(~, ~, app)
% Retrieve the suffix
suffix = strtrim(app.input_suffix_field.Value);

% Update suffix property
app.suffix = suffix;

% Determine action from dropdown
selected_action = app.action_dropdown.Value;
switch selected_action
    case 'Append'
        app.remove_suffix = false;
    case 'Remove'
        app.remove_suffix = true;
end

% Clear the input field
app.input_suffix_field.Value = "";

% Update status
MBDToolFunctions.update_status(app, ...
    ['Suffix "', suffix, '" submitted for ', selected_action], 'type', 'info');
end
