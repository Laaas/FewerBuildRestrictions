local index = 1;
while assert(debug.getupvalue(Welder.GetRange, index)) ~= "kWeldRange" do
	index = index + 1;
end

debug.setupvalue(Welder.GetRange, index, debug.getupvalue(Welder.GetRange, index) / 2); -- Half welder range
