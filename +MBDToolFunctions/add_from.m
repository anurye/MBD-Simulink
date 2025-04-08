function add_from(src, ~, app)
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
                add_ss_from(selected_blocks{i}, app, src);
            case 'Goto'
                add_goto_from(selected_blocks{i}, app, src);
            case 'Outport'
                add_outport_from(selected_blocks{i}, app);
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


function add_ss_from(selected_block, app, src)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Check if the selected block is a Stateflow chart
chart = find(sfroot, '-isa', 'Stateflow.Chart', 'Path', selected_block);
if ~isempty(chart)
    % Extract input data ports
    inputData = chart.find('-isa', 'Stateflow.Data', 'Scope', 'Input');
    try
        inport_names = {inputData.Name};
    catch mexc
        if numel(inputData) == 0, return; end
        rethrow(mexc)
    end
    add_ss_from_sub(selected_block, inport_names, parent_system, app, src)
else
    inports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Inport');
    inport_names = get_param(inports, 'Name');
    add_ss_from_sub(selected_block, inport_names, parent_system, app, src)
end

% Handle trigger port
% Get subsystem port connectivity
ports = get_param(selected_block, 'PortConnectivity');
trigger_port = ports(strcmp({ports.Type}, 'trigger'));
if numel(trigger_port) == 1
    % Check if the port is already connected
    if trigger_port.SrcBlock ~= -1 || ~isempty(trigger_port.SrcPort), return; end

    % Trigger port
    trigger = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'TriggerPort');
    trigger_name = get_param(trigger, 'Name');
    trigger_port_position = trigger_port.Position;

    % Add a new From block
    from_name = MBDToolFunctions.find_unique_name(parent_system, 'From');
    add_block('simulink/Signal Routing/From', [parent_system, '/', from_name]);

    % Set From params
    from_position = MBDToolFunctions.compute_position(repmat(trigger_port_position, 1, 2), ...
        'name', trigger_name{1}, 'min_size', [40, 28], 'v_spacing', -42);
    set_param([parent_system, '/', from_name], ...
        'Position', from_position, ...
        'GotoTag', trigger_name{1}, ...
        'ShowName', 'off');
    % Connect the new From block to the subsystem port
    from_port_position = get_param([parent_system, '/', from_name], 'PortConnectivity').Position;
    add_line(parent_system, [from_port_position; ...
        [trigger_port_position(1), from_port_position(2)]; ...
        trigger_port_position]);

end
end

function add_goto_from(selected_block, app, src)
% Parent system
parent_system = get_param(selected_block, 'Parent');

% Get the GotoTag of the Goto block
goto_tag = get_param(selected_block, 'GotoTag');
if app.remove_suffix
    goto_tag = strrep(goto_tag, char(app.suffix), '');
else
    goto_tag = [goto_tag, char(app.suffix)];
end

% Goto block position
goto_position = get_param(selected_block, 'Position');
% Goto port and Goto port position
goto_port = get_param(selected_block, 'PortConnectivity');
goto_port_position = goto_port(end).Position;

% From block name
from_name = MBDToolFunctions.find_unique_name(parent_system, 'From');

% Check if adding a cast is required
if strcmpi(src.Tag, 'from_cast')
    % Check if the input is already connected
    if goto_port(end).SrcBlock ~= -1 || ~isempty(goto_port(end).SrcPort)
        src_blocks = get_param(goto_port(end).SrcBlock, 'BlockType');
        if iscell(src_blocks)
            is_connected_to_from = any(strcmp(src_blocks, 'DataTypeConversion'));
        else
            is_connected_to_from = strcmp(src_blocks, 'DataTypeConversion');
        end
        % Skip if already connected to a From
        if is_connected_to_from, return; end
    end

    % Add new From block
    add_block('simulink/Signal Routing/From', [parent_system, '/', from_name]);

    % Add a new Cast block
    cast_name = MBDToolFunctions.find_unique_name(parent_system, 'Cast');
    add_block('simulink/Commonly Used Blocks/Data Type Conversion', [parent_system, '/', cast_name]);

    % Set From params
    cast_position = MBDToolFunctions.compute_position(goto_position, ...
        'min_size', [75, 34], 'spacing', 100);
    from_position = MBDToolFunctions.compute_position(goto_position, ...
        'name', goto_tag, 'spacing', 275, 'side', 'l', 'min_size', [40, 28]);

    set_param([parent_system, '/', from_name], ...
        'Position', from_position, ...
        'GotoTag', goto_tag, ...
        'ShowName', 'off');
    set_param([parent_system, '/', cast_name], ...
        'Position', cast_position, ...
        'ShowName', 'off');

    % Connect the new From->Cast blocks to the Goto port
    from_port_pos = get_param([parent_system, '/', from_name], 'PortConnectivity').Position;
    cast_ports = get_param([parent_system, '/', cast_name], 'PortConnectivity');
    cast_inport_pos = cast_ports(1).Position;
    cast_outport_pos = cast_ports(2).Position;

    add_line(parent_system, [from_port_pos; cast_inport_pos]);
    add_line(parent_system, [cast_outport_pos; goto_port_position]);
else
    % Add new From block
    add_block('simulink/Signal Routing/From', [parent_system, '/', from_name]);
    % Set From params
    from_position = MBDToolFunctions.compute_position(goto_position, ...
        'name', goto_tag, 'side', 'r', 'min_size', [40, 28]);
    set_param([parent_system, '/', from_name], ...
        'Position', from_position, ...
        'GotoTag', goto_tag, ...
        'ShowName', 'off');
end
end

function add_outport_from(selected_block, app)
% Parent system
parent_system = get_param(selected_block, 'Parent');
% Get the position and name of the Outport block
outport_position = get_param(selected_block, 'Position');
goto_tag = get_param(selected_block, 'Name');
if app.remove_suffix
    goto_tag = strrep(goto_tag, char(app.suffix), '');
else
    goto_tag = [goto_tag, char(app.suffix)];
end

% Outport block port and its position
outport_port = get_param(selected_block, 'PortConnectivity');
outport_port_position = outport_port(end).Position;

% Check if a From block is already connected
if outport_port(end).SrcBlock ~= -1
    src_blocks = get_param(outport_port(end).SrcBlock, 'BlockType');
    if iscell(src_blocks)
        is_connected_to_from = any(strcmp(src_blocks, 'From'));
    else
        is_connected_to_from = strcmp(src_blocks, 'From');
    end
    % Skip if already connected to a From block
    if is_connected_to_from, return; end
end

% Add new From block and set its parameters
from_name = MBDToolFunctions.find_unique_name(parent_system, 'From');
add_block('simulink/Signal Routing/From', [parent_system, '/', from_name]);

from_position = MBDToolFunctions.compute_position(outport_position, ...
    'min_size', [40, 28], 'name', goto_tag);
set_param([parent_system, '/', from_name], ...
    'Position', from_position, ...
    'GotoTag', goto_tag, ...
    'ShowName', 'off');

% Connect the Outport block to the new From block
from_port_position = get_param([parent_system, '/', from_name], 'PortConnectivity').Position;
add_line(parent_system, [from_port_position; outport_port_position]);
end

%{
        Helper Function
%}
function add_ss_from_sub(selected_block, inport_names, parent_system, app, src)
% Get subsystem port connectivity
ports = get_param(selected_block, 'PortConnectivity');
for i = 1:numel(inport_names)
    % Get the position of the subsystem input port
    inport_conn = ports(i);
    inport_positions = inport_conn.Position;
    % Check if the subsystem port is already connected
    if inport_conn.SrcBlock ~= -1 || ~isempty(inport_conn.SrcPort), continue; end

    % Add a new From block
    from_name = MBDToolFunctions.find_unique_name(parent_system, 'From');
    add_block('simulink/Signal Routing/From', [parent_system, '/', from_name]);
    if app.remove_suffix
        goto_tag = strrep(inport_names{i}, char(app.suffix), '');
    else
        goto_tag = [inport_names{i}, char(app.suffix)];
    end

    % Check if adding a cast is required
    if strcmpi(src.Tag, 'from_cast')
        % Add a new Cast block
        cast_name = MBDToolFunctions.find_unique_name(parent_system, 'Cast');
        add_block('simulink/Commonly Used Blocks/Data Type Conversion', [parent_system, '/', cast_name]);

        % Set From params
        cast_position = MBDToolFunctions.compute_position(repmat(inport_positions, 1, 2), ...
            'side', 'l', 'spacing', 50, 'min_size', [75, 34]);
        from_position = MBDToolFunctions.compute_position(repmat(inport_positions, 1, 2), ...
            'name', goto_tag, 'spacing', 175, 'side', 'l', 'min_size', [40, 28]);

        set_param([parent_system, '/', from_name], ...
            'Position', from_position, ...
            'GotoTag', [inport_names{i}, char(app.suffix)], ...
            'ShowName', 'off');
        set_param([parent_system, '/', cast_name], ...
            'Position', cast_position, ...
            'ShowName', 'off');

        % Connect the new From->Cast blocks to the subsystem port
        from_port_pos = get_param([parent_system, '/', from_name], 'PortConnectivity').Position;
        cast_ports = get_param([parent_system, '/', cast_name], 'PortConnectivity');
        cast_inport_pos = cast_ports(1).Position;
        cast_outport_pos = cast_ports(2).Position;

        add_line(parent_system, [from_port_pos; cast_inport_pos]);
        add_line(parent_system, [cast_outport_pos; inport_positions]);
    else
        % Set From params
        from_position = MBDToolFunctions.compute_position(repmat(inport_positions, 1, 2), ...
            'name', goto_tag, 'min_size', [40, 28]);
        set_param([parent_system, '/', from_name], ...
            'Position', from_position, ...
            'GotoTag', goto_tag, ...
            'ShowName', 'off');
        % Connect the new From block to the subsystem port
        add_line(parent_system, ...
            [get_param([parent_system, '/', from_name], 'PortConnectivity').Position; inport_positions]);
    end
end
end
