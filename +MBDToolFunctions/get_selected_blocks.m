function selected_blocks = get_selected_blocks
    selected_blocks = find_system(gcs, 'SearchDepth', 1, 'Selected', 'on');
end
