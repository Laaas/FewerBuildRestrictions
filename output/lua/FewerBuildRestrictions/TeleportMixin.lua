local old = TeleportMixin.TriggerTeleport;

function TeleportMixin:TriggerTeleport(delay, destinationEntityId, destinationPos, cost, requiresActivation)
	if Server then
		self.postTeleportRequiresActivation = requiresActivation;
	end
	old(self, delay, destinationEntityId, destinationPos, cost);
end

function TeleportMixin:OnTeleportEnd()
	if Server and self.SetRequiresActivation and self.postTeleportRequiresActivation then
		self.postTeleportRequiresActivation = nil;
		self:SetRequiresActivation();
	end
end
