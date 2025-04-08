function new_position = compute_position(ref_position, opts)
    arguments
        ref_position (1,4) double
        opts.side (1,:) char {mustBeMember(opts.side, {'l', 'r'})} = 'l'
        opts.name (1,:) char = ''
        opts.min_size (1,2) double = [30, 14]
        opts.max_size (1,2) double = [250, 28]
        opts.spacing (1,1) double = 150
        opts.v_spacing (1,1) double = 0
    end
    
    % Compute block dimensions
    ref_width = ref_position(3) - ref_position(1);
    ref_height = ref_position(4) - ref_position(2);

    % Estimate width required to display the name (8 pixels per character heuristic)
    name_width = max(length(opts.name) * 8, opts.min_size(1));
    block_width = max(min(name_width, opts.max_size(1)), opts.min_size(1));
    
    % Scale height based on reference block
    block_height = max(min(ref_height, opts.max_size(2)), opts.min_size(2));

    % Adjust delta based on the side and ensure spacing
    switch opts.side
        case 'l'
            x_offset = -block_width - opts.spacing;
        case 'r'
            x_offset = ref_width + opts.spacing;
    end
    y_offset = (ref_height - block_height) / 2 + opts.v_spacing;

    % Compute final position
    left = ref_position(1) + x_offset;
    top = ref_position(2) + y_offset;
    right = left + block_width;
    bottom = top + block_height;
    
    new_position = [left, top, right, bottom];
end
