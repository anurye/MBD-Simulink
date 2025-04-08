function add_goto(src, ~, app)
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
                add_ss_goto(selected_blocks{i}, app, src);
            case 'From'
                add_from_goto(selected_blocks{i}, app, src);
            case 'Inport'
                add_inport_goto(selected_blocks{i});
            case 'BusSelector'
                add_bus_goto(selected_blocks{i});
            otherwise
                MBDToolFunctions.update_status(app, 'Not supported', ...
                    'type', 'warning')
        end
    catch mexc
        MBDToolFunctions.update_status(app, ['Error: ', mexc.message], ...
            'type', 'error', 'clear', false);
        return;
    end
end
end


function add_ss_goto(selected_block, app, src)
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
    add_ss_goto_sub(selected_block, outport_names, num_inports, app, src)
else
    outports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Outport');
    inports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Inport');
    outport_names = get_param(outports, 'Name');
    add_ss_goto_sub(selected_block, outport_names, numel(inports), app, src)
end
end

function add_bus_goto(selected_block)
% Get bus port connectivity
ports = get_param(selected_block, 'PortConnectivity');
% Output signal names
output_signals = get_param(selected_block, 'OutputSignals');
signal_names = split(output_signals, ',');

% Parent system
parent_system = get_param(selected_block, 'Parent');

for i = 1:numel(signal_names)
    % Get the position of the bus output port
    port_conn = ports(i+1); % Exclude input port
    port_position = port_conn.Position;

    % Check if the bus port is already connected
    if ~isempty(port_conn.DstBlock) || ~isempty(port_conn.DstPort), continue; end

    % Add a new Goto block
    goto_name = MBDToolFunctions.find_unique_name(parent_system, 'Goto');
    add_block('simulink/Signal Routing/Goto', [parent_system, '/', goto_name]);

    % Set Goto params
    goto_position = MBDToolFunctions.compute_position(repmat(port_position, 1, 2), ...
        'name', signal_names{i}, 'side', 'r', 'min_size', [40, 28]);
    set_param([parent_system, '/', goto_name], ...
        'position', goto_position, ...
        'GotoTag', signal_names{i}, ...
        'ShowName', 'off');

    % Connect the subsystem port to the new Outport block
    goto_port_position = get_param([parent_system, '/', goto_name], 'PortConnectivity').Position;
    add_line(parent_system, [port_position; goto_port_position]);
end
end

function add_from_goto(selected_block, app, src)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get the GotoTag of the From block
goto_tag  = get_param(selected_block, 'GotoTag');
if app.remove_suffix
    goto_tag = strrep(goto_tag, char(app.suffix), '');
else
    goto_tag = [goto_tag, char(app.suffix)];
end

% Determine the Goto block doesn't already exist
if goto_exists(selected_block, goto_tag), return; end

% From block position
from_position = get_param(selected_block, 'Position');

% From port and from port position
from_port = get_param(selected_block, 'PortConnectivity');
from_port_position = from_port(end).Position;

% Goto block name
goto_name = MBDToolFunctions.find_unique_name(parent_system, 'Goto');

% Check if adding a cast is required
if strcmpi(src.Tag, 'cast_goto')
    % Check if the output is already connected
    if ~isempty(from_port(end).DstBlock) || ~isempty(from_port(end).DstPort)
        dst_blocks = get_param(from_port(end).DstBlock, 'BlockType');
        if iscell(dst_blocks)
            is_connected_to_cast = any(strcmp(dst_blocks, 'DataTypeConversion'));
        else
            is_connected_to_cast = strcmp(dst_blocks, 'DataTypeConversion');
        end
        % Skip if already connected to a Cast
        if is_connected_to_cast, return; end
    end

    % Add new Goto block
    add_block('simulink/Signal Routing/Goto', [parent_system, '/', goto_name]);

    % Add a new Cast block
    cast_name = MBDToolFunctions.find_unique_name(parent_system, 'Cast');
    add_block('simulink/Commonly Used Blocks/Data Type Conversion', [parent_system, '/', cast_name]);

    % Set Goto params
    cast_position = MBDToolFunctions.compute_position(from_position, ...
        'side', 'r', 'min_size', [75, 34], 'spacing', 100);
    goto_position = MBDToolFunctions.compute_position(from_position, ...
        'name', goto_tag, 'spacing', 275, 'side', 'r', 'min_size', [40, 28]);

    set_param([parent_system, '/', goto_name], ...
        'Position', goto_position, ...
        'GotoTag', goto_tag, ...
        'ShowName', 'off');
    set_param([parent_system, '/', cast_name], ...
        'Position', cast_position, ...
        'ShowName', 'off');

    % Connect the new From->Cast blocks to the Goto port
    goto_port_pos = get_param([parent_system, '/', goto_name], 'PortConnectivity').Position;
    cast_ports = get_param([parent_system, '/', cast_name], 'PortConnectivity');
    cast_inport_pos = cast_ports(1).Position;
    cast_outport_pos = cast_ports(2).Position;

    add_line(parent_system, [from_port_position; cast_inport_pos]);
    add_line(parent_system, [cast_outport_pos; goto_port_pos]);
else
    % Add new Goto block
    add_block('simulink/Signal Routing/Goto', [parent_system, '/', goto_name]);
    % Set Goto params
    goto_position = MBDToolFunctions.compute_position(from_position, ...
        'name', goto_tag, 'side', 'l', 'min_size', [40, 28]);
    set_param([parent_system, '/', goto_name], ...
        'position', goto_position, ...
        'GotoTag', goto_tag, ...
        'ShowName', 'off');
end
end

function add_inport_goto(selected_block)
% Parent system
parent_system = get_param(selected_block, 'Parent');
% Get the position and name of the Inport block
inport_position = get_param(selected_block, 'Position');
goto_tag = get_param(selected_block, 'Name');

% Determine the Goto block doesn't already exist
if goto_exists(selected_block, goto_tag), return; end

% Inport block port and its position
inport_port = get_param(selected_block, 'PortConnectivity');
inport_port_position = inport_port(end).Position;

% Check if a Goto block is already connected
if ~isempty(inport_port(end).DstBlock)
    dst_blocks = get_param(inport_port(end).DstBlock, 'BlockType');
    if iscell(dst_blocks)
        is_connected_to_goto = any(strcmp(dst_blocks, 'Goto'));
    else
        is_connected_to_goto = strcmp(dst_blocks, 'Goto');
    end
    % Skip if already connected to a Goto block
    if is_connected_to_goto, return; end
end

% Add new Goto block and set its parameters
goto_name = MBDToolFunctions.find_unique_name(parent_system, 'From');
add_block('simulink/Signal Routing/Goto', [parent_system, '/', goto_name]);

goto_position = MBDToolFunctions.compute_position(inport_position, ...
    'min_size', [40, 28], 'name', goto_tag, 'side', 'r');
set_param([parent_system, '/', goto_name], ...
    'Position', goto_position, ...
    'GotoTag', goto_tag, ...
    'ShowName', 'off');

% Connect the Inport block to the new Goto block
goto_port_position = get_param([parent_system, '/', goto_name], 'PortConnectivity').Position;
add_line(parent_system, [inport_port_position; goto_port_position]);
end

function exists = goto_exists(selected_block, tag_name)
% Get the parent system of the selected block
parent_system = get_param(selected_block, 'Parent');

% Find all Goto blocks in the parent system
goto_blocks = find_system(parent_system, 'SearchDepth', 1, 'BlockType', 'Goto');

% Check if any Goto block has the specified tag
exists = false;
for i = 1:numel(goto_blocks)
    goto_tag = get_param(goto_blocks{i}, 'GotoTag');
    if strcmpi(goto_tag, tag_name)
        exists = true;
        return;
    end
end
end

%{
        Helper Function
%}
function add_ss_goto_sub(selected_block, outport_names, num_inputs, app, src)
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

    % Add a new Goto block
    goto_name = MBDToolFunctions.find_unique_name(parent_system, 'Goto');
    add_block('simulink/Signal Routing/Goto', [parent_system, '/', goto_name]);
    % goto_tag = outport_names{i};
    outport_name = strip(outport_names{i});
    if app.remove_suffix
        goto_tag = strrep(outport_name, char(app.suffix), '');
    else
        goto_tag = [outport_name, char(app.suffix)];
    end

    % Check if adding a cast is required
    if strcmpi(src.Tag, 'cast_goto')
        % Add a new Cast block
        cast_name = MBDToolFunctions.find_unique_name(parent_system, 'Cast');
        add_block('simulink/Commonly Used Blocks/Data Type Conversion', [parent_system, '/', cast_name]);

        % Set Goto params
        cast_position = MBDToolFunctions.compute_position(repmat(outport_position, 1, 2), ...
            'side', 'r', 'spacing', 50, 'min_size', [75, 34]);
        goto_position = MBDToolFunctions.compute_position(repmat(outport_position, 1, 2), ...
            'name', goto_tag, 'spacing', 175, 'side', 'r', 'min_size', [40, 28]);

        set_param([parent_system, '/', goto_name], ...
            'Position', goto_position, ...
            'GotoTag', goto_tag, ...
            'ShowName', 'off');
        set_param([parent_system, '/', cast_name], ...
            'Position', cast_position, ...
            'ShowName', 'off');

        % Connect the new From->Cast blocks to the subsystem port
        goto_port_pos = get_param([parent_system, '/', goto_name], 'PortConnectivity').Position;
        cast_ports = get_param([parent_system, '/', cast_name], 'PortConnectivity');
        cast_inport_pos = cast_ports(1).Position;
        cast_outport_pos = cast_ports(2).Position;

        add_line(parent_system, [outport_position; cast_inport_pos]);
        add_line(parent_system, [cast_outport_pos; goto_port_pos]);
    else
        % Set Goto params
        goto_position = MBDToolFunctions.compute_position(repmat(outport_position, 1, 2), ...
            'name', goto_tag, 'side', 'r', 'min_size', [40, 28]);
        set_param([parent_system, '/', goto_name], ...
            'position', goto_position, ...
            'GotoTag', goto_tag, ...
            'ShowName', 'off');

        % Connect the subsystem port to the new Outport block
        add_line(parent_system, [outport_position; ...
            get_param([parent_system, '/', goto_name], 'PortConnectivity').Position]);
    end
end
end

