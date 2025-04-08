function add_outport(~, ~, app)
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
                add_ss_outport(selected_blocks{i});
            case 'From'
                add_from_outport(selected_blocks{i});
            otherwise
        end
    catch mexc
        MBDToolFunctions.update_status(app, ['Error: ', mexc.message], ...
            'type', 'error', 'clear', false);
        return;
    end
end
end


function add_ss_outport(selected_block)
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
    add_ss_outport_sub(selected_block, outport_names, num_inports)
else
    % Outport names
    outports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Outport');
    inports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Inport');
    outport_names = get_param(outports, 'Name');
    add_ss_outport_sub(selected_block, outport_names, numel(inports))
end
end

function add_from_outport(selected_block)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get the GotoTag of the From block and its position
goto_tag = get_param(selected_block, 'GotoTag');
from_position = get_param(selected_block, 'Position');

% From block port and its position
from_port = get_param(selected_block, 'PortConnectivity');
from_port_position = from_port(end).Position;

% Check if an output is already connected
if ~isempty(from_port(end).DstBlock)
    dst_blocks = get_param(from_port(end).DstBlock, 'BlockType');
    if iscell(dst_blocks)
        is_connected_to_outport = any(strcmp(dst_blocks, 'Outport'));
    else
        is_connected_to_outport = strcmp(dst_blocks, 'Outport');
    end
    % Skip if already connected to an Outport
    if is_connected_to_outport, return; end
end

% Add the Outport and set its parameters
outport_name = MBDToolFunctions.find_unique_name(parent_system, goto_tag);
add_block('simulink/Sinks/Out1', [parent_system, '/', outport_name]);

outport_position = MBDToolFunctions.compute_position(from_position, ...
    'max_size', [30, 14], 'side', 'r');
set_param([parent_system, '/', outport_name], ...
    'Position', outport_position, ...
    'ShowName', 'on')

% Connect the From block to the new Outport
outport_port_position = get_param([parent_system, '/', outport_name], 'PortConnectivity').Position;
add_line(parent_system, [from_port_position; outport_port_position]);
end


function add_ss_outport_sub(selected_block, outport_names, num_inputs)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get subsystem port connectivity
ports = get_param(selected_block, 'PortConnectivity');
% Remove trigger port
ports(strcmp({ports.Type}, 'trigger')) = [];
for i = 1:numel(outport_names)
    % Get the position of the subsystem output port
    outport_conn = ports(i + num_inputs);
    ss_outport_port_positions = outport_conn.Position;

    % Check if the subsystem port is already connected
    if ~isempty(outport_conn.DstBlock) || ~isempty(outport_conn.DstPort), continue; end

    % Add a new Outport block and set its params
    outport_name = MBDToolFunctions.find_unique_name(parent_system, outport_names{i});
    add_block('simulink/Sinks/Out1', [parent_system, '/', outport_name]);

    outport_position = MBDToolFunctions.compute_position(repmat(ss_outport_port_positions, 1, 2), ...
        'max_size', [30, 14], 'side', 'r');
    set_param([parent_system, '/', outport_name], ...
        'position', outport_position, ...
        'ShowName', 'on');

    % Connect the subsystem port to the new Outport block
    outport_port_position = get_param([parent_system, '/', outport_name], 'PortConnectivity').Position;
    add_line(parent_system, [ss_outport_port_positions; outport_port_position]);
end
end
