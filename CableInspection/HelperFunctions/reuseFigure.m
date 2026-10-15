function fig = reuseFigure(name, position, tag)
%reuseFigure Reuse a named figure and clear its old contents.

fig = findobj("Type", "figure", "Tag", tag);
if isempty(fig)
    fig = figure(Name=name, Position=position, Tag=tag);
else
    figure(fig)
    clf(fig)
end
end
