function unique_name = find_unique_name(parent_path, proposed_name)
% FIND_UNIQUE_NAME Returns the <proposed_name> with an incremental number
% suffix to make it unique within the model path <parent_path>.
%
% INPUTS:
%   - parent_path : TEXTscalar
%       Model path where we want to create the new block. The model is
%       supposed to be loaded.
%
%   - proposed_name : TEXTscalar
%       Desired name for the new block, if this name is already used in the
%       parent path, an incremental numeric suffix is added to this input.
%
% OUTPUT:
%   - unique_name : CHAR vector
%       Unique name within the <parent_path>
%
% EXAMPLE:
% unique_name = find_unique_name('NG_MIL/WP01_Cons', 'unit_delay');
%
% 20240311 Marco Tobia Vitali (marcotobia.vitali@northvolt.com)
arguments
    parent_path {mustBeTextScalar}
    proposed_name {mustBeTextScalar}
end

% consolidate inputs
parent_path = char(parent_path);
unique_name = char(proposed_name);
unique_idx = 0;

% keep incrementing the suffix until the name is unique
while getSimulinkBlockHandle([parent_path, '/', unique_name]) ~= -1
    unique_idx = unique_idx + 1;
    if unique_idx == 1
        unique_name = [unique_name, '1']; %#ok<AGROW>
    else
        % remove the previous suffix and add the new one
        unique_name = [unique_name(1:end-length(num2str(unique_idx-1))), ...
                       num2str(unique_idx)];
    end
end
end
