function drawRotatedBox(rbox, color, lineWidth)
%drawRotatedBox Draw a matchshape rotated bounding box.

cx = rbox(1);
cy = rbox(2);
w = rbox(3);
h = rbox(4);
theta = deg2rad(rbox(5));

corners = [-w/2 -h/2; w/2 -h/2; w/2 h/2; -w/2 h/2; -w/2 -h/2];
R = [cos(theta) -sin(theta); sin(theta) cos(theta)];
points = corners * R' + [cx cy];

plot(points(:, 1), points(:, 2), Color=color, LineWidth=lineWidth)
end
