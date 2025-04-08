function update_status(app, message, opts)
arguments
    app MBDTool
    message {mustBeTextScalar}
    opts.type (1,:) char {mustBeMember(opts.type, {'error', 'warning', 'info', 'default'})} = 'default' 
    opts.clear = true;
end

% Update the status text area with a message and set the background color
if opts.clear
    app.status_text_area.Value = {message};
else
    status_text = app.status_text_area.Value;
    status_text = [status_text(:); convertStringsToChars(message)];
    app.status_text_area.Value = status_text;
end

switch opts.type
    case 'error'
        app.status_text_area.BackgroundColor = [1, 0.8, 0.8];
    case 'warning'
        app.status_text_area.BackgroundColor = [1, 1, 0.8];
    case 'info'
        app.status_text_area.BackgroundColor = [0.8, 1, 0.8];
    otherwise
        app.status_text_area.BackgroundColor = [1, 1, 1];
end

end
