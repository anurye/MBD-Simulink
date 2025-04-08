function add_display(~, ~, app)
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
                add_ss_display(selected_blocks{i});
            case 'From'
                add_from_display(selected_blocks{i});
            case 'Inport'
                add_inport_display(selected_blocks{i});
            otherwise
                MBDToolFunctions.update_status(app, 'Not supported', ...
                    'clear', true, 'type', 'warning');
        end
    catch mexc
        MBDToolFunctions.update_status(app, ['Error: ', mexc.message], ...
            'type', 'error', 'clear', false);
        return;
    end
end
end

function add_ss_display(selected_block)
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
    add_ss_display_sub(selected_block, outport_names,num_inports)
else
    outports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Outport');
    inports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Inport');
    add_ss_display_sub(selected_block, outports, numel(inports))
end
end

function add_from_display(selected_block)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get the position of the From block
from_position = get_param(selected_block, 'Position');

% From block port and its position
from_port = get_param(selected_block, 'PortConnectivity');
from_port_position = from_port(end).Position;

% Check if a Display is already connected
if ~isempty(from_port(end).DstBlock)
    dst_blocks = get_param(from_port(end).DstBlock, 'BlockType');
    if iscell(dst_blocks)
        is_connected_to_disp = any(strcmp(dst_blocks, 'Display'));
    else
        is_connected_to_disp = strcmp(dst_blocks, 'Display');
    end
    % Skip if already connected to a Display
    if is_connected_to_disp, return; end
end

% Add new Display and set its parameters
display_name = MBDToolFunctions.find_unique_name(parent_system, 'Display');
add_block('simulink/Sinks/Display', [parent_system, '/', display_name]);

display_position = MBDToolFunctions.compute_position(from_position, ...
    'min_size', [90, 30], 'side', 'r');
set_param([parent_system, '/', display_name], ...
    'Position', display_position, ...
    'ShowName', 'off')

% Connect the From block to the new Display block
display_port_position = get_param([parent_system, '/', display_name], 'PortConnectivity').Position;
add_line(parent_system, [from_port_position; display_port_position]);
end

function add_inport_display(selected_block)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get the position of the Inport block
inport_position = get_param(selected_block, 'Position');

% Inport block port and its position
inport_port = get_param(selected_block, 'PortConnectivity');
inport_port_position = inport_port(end).Position;

% Check if a Display is already connected
if ~isempty(inport_port(end).DstBlock)
    dst_blocks = get_param(inport_port(end).DstBlock, 'BlockType');
    if iscell(dst_blocks)
        is_connected_to_disp = any(strcmp(dst_blocks, 'Display'));
    else
        is_connected_to_disp = strcmp(dst_blocks, 'Display');
    end
    % Skip if already connected to a Display
    if is_connected_to_disp, return; end
end

% Add new Display and set its parameters
display_name = MBDToolFunctions.find_unique_name(parent_system, 'Display');
add_block('simulink/Sinks/Display', [parent_system, '/', display_name]);

display_position = MBDToolFunctions.compute_position(inport_position, ...
    'min_size', [90, 30], 'side', 'r');
set_param([parent_system, '/', display_name], ...
    'Position', display_position, ...
    'ShowName', 'off')

% Connect the From block to the new Display block
display_port_position = get_param([parent_system, '/', display_name], 'PortConnectivity').Position;
add_line(parent_system, [inport_port_position; display_port_position]);
end

%{
        Helper Function
%}
function add_ss_display_sub(selected_block, outports, num_inputs)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get subsystem port connectivity
ports = get_param(selected_block, 'PortConnectivity');
% Remove trigger port
ports(strcmp({ports.Type}, 'trigger')) = [];

for i = 1:numel(outports)
    % Get the position of the subsystem output port
    outport_conn = ports(i + num_inputs);
    ss_outport_port_positions = outport_conn.Position;

    % Check if the subsystem port is already connected
    if ~isempty(outport_conn.DstBlock) || ~isempty(outport_conn.DstPort), continue; end

    % Add a new Display block and set its params
    display_name = MBDToolFunctions.find_unique_name(parent_system, 'Display');
    add_block('simulink/Sinks/Display', [parent_system, '/', display_name]);

    display_position = MBDToolFunctions.compute_position(repmat(ss_outport_port_positions, 1, 2), ...
        'min_size', [90, 30], 'side', 'r');
    set_param([parent_system, '/', display_name], ...
        'position', display_position, ...
        'ShowName', 'off');

    % Connect the subsystem port to the new Display block
    display_port_position = get_param([parent_system, '/', display_name], 'PortConnectivity').Position;
    add_line(parent_system, [ss_outport_port_positions; display_port_position]);
end
end
