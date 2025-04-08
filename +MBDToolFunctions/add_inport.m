function add_inport(~, ~, app)
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
                add_ss_inport(selected_blocks{i});
            case 'Goto'
                add_goto_inport(selected_blocks{i});
            otherwise
                MBDToolFunctions.update_status(app, 'Not supported', ...
                    'type', 'warning');
        end
    catch mexc
        MBDToolFunctions.update_status(app, ['Error: ', mexc.message], ...
            'type', 'error');
        return;
    end
end
end


function add_ss_inport(selected_block)
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
    add_ss_inport_sub(selected_block, inport_names, parent_system);
else
    % Inport names
    inports = find_system(selected_block, 'SearchDepth', 1, 'BlockType', 'Inport');
    inport_names = get_param(inports, 'Name');
    add_ss_inport_sub(selected_block, inport_names, parent_system)
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

    % Add a new Inport block
    inport_name = MBDToolFunctions.find_unique_name(parent_system, trigger_name{1});
    add_block('simulink/Sources/In1', [parent_system, '/', inport_name]);

    % Set Inport params
    inport_position = MBDToolFunctions.compute_position(repmat(trigger_port_position, 1, 2), ...
        'max_size', [30, 14], 'v_spacing', -42);
    set_param([parent_system,'/',inport_name], ...
        'Position', inport_position, ...
        'ShowName', 'on');
    % Connect the new From block to the subsystem port
    inport_port_position = get_param([parent_system, '/', inport_name], 'PortConnectivity').Position;
    add_line(parent_system, [inport_port_position; ...
        [trigger_port_position(1), inport_port_position(2)]; ...
        trigger_port_position]);

end
end

function add_goto_inport(block)
% Parent system
parent_system = get_param(block, 'Parent');

% Get the GotoTag of the Goto block and its position
goto_tag = get_param(block, 'GotoTag');
goto_position = get_param(block, 'Position');
% Get goto port and goto port position
goto_port = get_param(block, 'PortConnectivity');
goto_port_position = goto_port(end).Position;

% Check if the input is already connected
if goto_port(end).SrcBlock ~= -1
    src_blocks = get_param(goto_port(end).SrcBlock, 'BlockType');
    if iscell(src_blocks)
        is_connected_to_inport = any(strcmp(src_blocks, 'Inport'));
    else
        is_connected_to_inport = strcmp(src_blocks, 'Inport');
    end
    % Skip if already connected to an Inport
    if is_connected_to_inport, return; end
end

% Add the Inport and set its parametes
inport_name = MBDToolFunctions.find_unique_name(parent_system, goto_tag);
add_block('simulink/Sources/In1', [parent_system, '/', inport_name]);

inport_position = MBDToolFunctions.compute_position(goto_position, ...
    'max_size', [30, 14]);
set_param([parent_system, '/', inport_name], ...
    'Position', inport_position, ...
    'ShowName', 'on')

% Connect the new Inport to the Goto block
inport_port_position = get_param([parent_system, '/', inport_name], 'PortConnectivity').Position;
add_line(parent_system, [inport_port_position; goto_port_position]);
end

%{
        Helper Functions
%}
function add_ss_inport_sub(selected_block, inport_names, parent_system)
% Get subsystem port connectivity
ports = get_param(selected_block, 'PortConnectivity');
for i = 1:numel(inport_names)
    % Get the position of the subsystem input port
    inport_conn = ports(i);
    ss_inport_port_position = inport_conn.Position;

    % Check if the subsystem port is already connected
    if inport_conn.SrcBlock ~= -1 || ~isempty(inport_conn.SrcPort), continue; end

    % Add a new Inport block and set its param
    inport_name = MBDToolFunctions.find_unique_name(parent_system, inport_names{i});
    add_block('simulink/Sources/In1', [parent_system,'/',inport_name]);

    inport_position = MBDToolFunctions.compute_position(repmat(ss_inport_port_position, 1, 2), ...
        'max_size', [30, 14]);
    set_param([parent_system,'/',inport_name], ...
        'Position', inport_position, ...
        'ShowName', 'on');

    % Connect the new Inport block to the subsystem port
    inport_port_position = get_param([parent_system,'/',inport_name], 'PortConnectivity').Position;
    add_line(parent_system, [inport_port_position; ss_inport_port_position]);
end
end