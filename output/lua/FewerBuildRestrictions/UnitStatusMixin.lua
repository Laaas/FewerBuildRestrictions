local oldGetUnitName = UnitStatusMixin.GetUnitName;
function UnitStatusMixin:GetUnitName(forEntity)
	local name = oldGetUnitName(self, forEntity);
	if HasMixin(self, "Construct") and self:GetRequiresActivation() then
			return name .. " (Requires activation by non-commander! [E])";
	end
	return name;
end
