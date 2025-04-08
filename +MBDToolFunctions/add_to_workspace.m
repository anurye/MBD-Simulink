function add_to_workspace(~, ~, app)
selected_blocks = MBDToolFunctions.get_selected_blocks();
if isempty(selected_blocks)
    MBDToolFunctions.update_status(app, 'No blocks selected.', ...
        'type', 'warning');
    return;
end

% Clear status field
MBDToolFunctions.update_status(app, '');

for i = 1:numel(selected_blocks)
    block_type = get_param(selected_blocks{i}, 'BlockType');
    try
        switch block_type
            case 'SubSystem'
                add_ss_tws(selected_blocks{i}, app);
            case 'From'
                add_from_tws(selected_blocks{i}, app);
            case 'Inport'
                add_inport_tws(selected_blocks{i});
            otherwise
                MBDToolFunctions.update_status(app, ...
                    sprintf('Adding TWS to %s block not supported', block_type), ...
                    'error');
                return
        end
    catch mexc
        MBDToolFunctions.update_status(app, ['Error: ', mexc.message], ...
            'type', 'error');
        return;
    end
end
end

function add_ss_tws(selected_block, app)
% Check if the selected block is a Stateflow chart
chart = find(sfroot, '-isa', 'Stateflow.Chart', 'Path', selected_block);
if ~isempty(chart)
    % Extract input and output data ports
    output_data = chart.find('-isa', 'Stateflow.Data', 'Scope', 'Output');
    input_data = chart.find('-isa', 'Stateflow.Data', 'Scope', 'Input');
    try
        outport_names = {output_data.Name};
    catch mexc
        % Check if there are no outputs
        if numel(output_data) == 0, return, end
        rethrow(mexc)
    end
    num_inports = numel(input_data);
    add_ss_tws_sub(selected_block, outport_names, num_inports, app)
else
    % Outport names
    outports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Outport');
    inports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Inport');
    outport_names = get_param(outports, 'Name');
    add_ss_tws_sub(selected_block, outport_names, numel(inports), app)
end
end

function add_from_tws(selected_block, app)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get the GotoTag and position of the From block
goto_tag = [get_param(selected_block, 'GotoTag'), char(app.suffix)];
from_position = get_param(selected_block, 'Position');
% Get the port and port position of the From block
from_port = get_param(selected_block, 'PortConnectivity');
from_port_position = from_port.Position;

% Check if the output is already connected
if ~isempty(from_port(end).DstBlock)
    dst_blocks = get_param(from_port(end).DstBlock, 'BlockType');
    if iscell(dst_blocks)
        is_connected_to_tws = any(strcmp(dst_blocks, 'ToWorkspace'));
    else
        is_connected_to_tws = strcmp(dst_blocks, 'ToWorkspace');
    end
    % Skip if already connected to a Goto
    if is_connected_to_tws, return; end
end

% Add new ToWorkspace block
tws_position = MBDToolFunctions.compute_position(from_position, ...
    'name', goto_tag, 'side', 'r', 'min_size', [90, 30]);
tws_name = MBDToolFunctions.find_unique_name(parent_system, 'To Workspace');
add_block('simulink/Sinks/To Workspace', [parent_system, '/', tws_name]);
set_param([parent_system, '/', tws_name], ...
    'position', tws_position, ...
    'VariableName', goto_tag, ...
    'SampleTime', '-1', ...
    'ShowName' , 'off', ...
    'SaveFormat', 'Structure With Time', ...
    'Decimation', '1');

% Connect the From block to the new ToWorkspace block
tws_port_position = get_param([parent_system, '/', tws_name], 'PortConnectivity').Position;
add_line(parent_system, [from_port_position; tws_port_position]);
end

function add_inport_tws(selected_block)
% Parent system
parent_system = get_param(selected_block, 'Parent');
% Get the position and name of the Inport block
inport_position = get_param(selected_block, 'Position');
inport_name = get_param(selected_block, 'Name');

% Inport block port and its position
inport_port = get_param(selected_block, 'PortConnectivity');
inport_port_position = inport_port(end).Position;

% Check if a ToWorkspace block is already connected
if ~isempty(inport_port(end).DstBlock)
    dst_blocks = get_param(inport_port(end).DstBlock, 'BlockType');
    if iscell(dst_blocks)
        is_connected_to_tws = any(strcmp(dst_blocks, 'ToWorkspace'));
    else
        is_connected_to_tws = strcmp(dst_blocks, 'ToWorkspace');
    end
    % Skip if already connected to a ToWorkspace block
    if is_connected_to_tws, return; end
end

% Add new ToWorkspace block
tws_position = MBDToolFunctions.compute_position(inport_position, ...
    'name', inport_name, 'side', 'r', 'min_size', [90, 30]);
tws_name = MBDToolFunctions.find_unique_name(parent_system, 'To Workspace');
add_block('simulink/Sinks/To Workspace', [parent_system, '/', tws_name]);
set_param([parent_system, '/', tws_name], ...
    'position', tws_position, ...
    'VariableName', inport_name, ...
    'SampleTime', '-1', ...
    'ShowName' , 'off', ...
    'SaveFormat', 'Structure With Time', ...
    'Decimation', '1');

% Connect the Inport block to the new ToWorkspace block
tws_port_position = get_param([parent_system, '/', tws_name], 'PortConnectivity').Position;
add_line(parent_system, [inport_port_position; tws_port_position]);
end


%{
        Helper functions
%}
function add_ss_tws_sub(selected_block, outport_names, num_inputs, app)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get subsystem port connectivity
ports = get_param(selected_block, 'PortConnectivity');
% Remove trigger port
ports(strcmp({ports.Type}, 'trigger')) = [];

for i = 1:numel(outport_names)
    % Get the position of the subsystem output port
    outport_conn = ports(i + num_inputs);
    outport_position = outport_conn.Position;

    % Check if the subsystem port is already connected
    if ~isempty(outport_conn.DstBlock) || ~isempty(outport_conn.DstPort), continue; end

    % Add a new To Workspace block and set its params
    tws_name = MBDToolFunctions.find_unique_name(parent_system, 'To Workspace');
    add_block('simulink/Sinks/To Workspace', [parent_system, '/', tws_name]);

    tws_position = MBDToolFunctions.compute_position(repmat(outport_position, 1, 2), ...
        'name', [outport_names{i}, char(app.suffix)], 'side', 'r', 'min_size', [90, 30]);
    set_param([parent_system, '/', tws_name], ...
        'position', tws_position, ...
        'VariableName', [outport_names{i}, char(app.suffix)], ...
        'SampleTime', '-1', ...
        'ShowName' , 'off', ...
        'SaveFormat', 'Structure With Time', ...
        'Decimation', '1');

    % Connect the subsystem port to the new To Workspace block
    tws_port_position = get_param([parent_system, '/', tws_name], 'PortConnectivity').Position;
    add_line(parent_system, [outport_position; tws_port_position]);
end
end
