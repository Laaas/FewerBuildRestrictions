ConstructMixin.networkVars.requiresActivation = "boolean";

local OnUpdate;


local oldConstructionComplete = newproxy();
local spawnTime = newproxy();
local filter = newproxy();

if Server then
	function ConstructMixin:SetRequiresActivation()
		self.requiresActivation = true;
		self[oldConstructionComplete] = self.constructionComplete;
		self.constructionComplete = false;
		if HasMixin(self, "MapBlip") then
			self:MarkBlipDirty();
		end
		self[spawnTime] = Shared.GetTime();
		self[filter] = EntityFilterOne(self);
		OnUpdate(self);
		self:AddTimedCallback(OnUpdate, 1, true);
	end
elseif Client then
	function ConstructMixin:SetRequiresActivation()
		assert(false, "SetRequiresActivation should not be called from the client!");
	end
end

local function activate(self)
	self.requiresActivation = false;
	self.constructionComplete = self[oldConstructionComplete];
	self[oldConstructionComplete] = nil;
	self.filter = nil;
	if HasMixin(self, "MapBlip") then
		self:MarkBlipDirty();
	end
end

OnUpdate = function(self)	if not self.requiresActivation then
		return false;
	end
	local ents = GetEntitiesWithinRange("Entity", self:GetOrigin(), 12);
	local self_pos;
	if self.GetEngagementPoint then
		self_pos = self:GetEngagementPoint();
	else
		self_pos = LookupTechData(self:GetTechId(), kTechDataMaxExtents);
		self_pos = self:GetOrigin() + (self_pos and self_pos.y / 2 or 0.5);
	end
	for i = 1, #ents do
		local ent = ents[i];
		if HasMixin(ent, "Construct") and not ent:GetRequiresActivation() or ent:isa("Player") then
			local ent_pos;
			if ent.GetEngagementPoint then
				ent_pos = ent:GetEngagementPoint();
			else
				ent_pos = LookupTechData(ent:GetTechId(), kTechDataMaxExtents);
				ent_pos = ent:GetOrigin() + (ent_pos and ent_pos.y / 2 or 0.5);
			end
			local trace = Shared.TraceRay(self_pos, ent_pos, CollisionRep.Move, PhysicsMask.AllButPCsAndRagdollsAndBabblers, self[filter]);

			if trace.entity == ent then
				activate(self);
				return false;
			end
		end
	end
	if Shared.GetTime() - 60 > self[spawnTime] then
		self:Kill();
	end
	return true;
end

function ConstructMixin:GetRequiresActivation()
	return self.requiresActivation;
end

local old = ConstructMixin.Construct;
function ConstructMixin:Construct(elapsedTime, builder)
	if not self.requiresActivation then
		return old(self, elapsedTime, builder);
	end
end

local old = ConstructMixin.OnHealSpray;
function ConstructMixin:OnHealSpray(gorge)
	if not self.requiresActivation then
		old(self, gorge);
	end
end

function ConstructMixin:GetCanConstruct(constructor)

    if self.GetCanConstructOverride then
        return self:GetCanConstructOverride(constructor)
    end



    if LookupTechData(self:GetTechId(), kTechDataNotOnInfestation) and GetIsPointOnInfestation(self:GetOrigin()) then
        return false
    end

    return not self:GetIsBuilt() and GetAreFriends(self, constructor) and self:GetIsAlive() and not constructor:isa("Exo")

end

if Server then
	function ConstructMixin:OnUse(player, elapsedTime, useSuccessTable)

	    local used = false

		if self.requiresActivation and self:GetCanConstruct(player) then
			activate(self);
			used = true;
	    elseif not GetIsAlienUnit(self) and self:GetCanConstruct(player) then



			local constructInterval = 0

			local activeWeapon = player:GetActiveWeapon()
			if activeWeapon and activeWeapon:GetMapName() == Builder.kMapName then
				constructInterval = kUseInterval
			end

	        local success, playAV = self:Construct(constructInterval, player)

			if success then
				used = true
			end

	    end

	    useSuccessTable.useSuccess = useSuccessTable.useSuccess or used

	end
end

function ConstructMixin:GetCanBeUsed(player, useSuccessTable)

	if self.requiresActivation then
		useSuccessTable.useSuccess = true;
    elseif self:GetIsBuilt() and not self:GetCanBeUsedConstructed(player) then
        useSuccessTable.useSuccess = false
	end

end

function ConstructMixin:GetCanBeUsedInaccurately(player, t)
	t.b = t.b and not self.requiresActivation;
end

local oldConstructionComplete = ConstructMixin.SetConstructionComplete;
function ConstructMixin:SetConstructionComplete(builder)
	oldConstructionComplete(self, builder);
	if self:GetIsAlive() and self.requiresActivation then
		self.constructionComplete = false;
		self[oldConstructionComplete] = true;
	end
end
