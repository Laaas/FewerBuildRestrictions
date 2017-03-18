-- ======= Copyright (c) 2003-2012, Unknown Worlds Entertainment, Inc. All rights reserved. =====
--
-- lua\BuildUtility.lua
--
--	  Created by:	Brian Cronin (brianc@unknownworlds.com)
--
-- ========= For more information, visit us at http://www.unknownworlds.com =====================

local buildRestrictions = true

Shared.RegisterNetworkMessage("BuildRestrictions", {
	state = "boolean"
})

if Client then
	Client.HookNetworkMessage("BuildRestrictions", function(msg)
		buildRestrictions = msg.state
	end)
elseif Server then
	function SetBuildRestrictions(state)
		buildRestrictions = state
		Server.SendNetworkMessage("BuildRestrictions", {state = state}, true)
	end

	function GetBuildRestrictions()
		return buildRestrictions
	end
end

local function CheckBuildTechAvailable(techId, teamNumber)

	local techTree = GetTechTree(teamNumber)
	local techNode = techTree:GetTechNode(techId)
	assert(techNode)
	return techNode:GetAvailable()

end

local function GetPathingRequirementsMet(position, extents)
	return not Pathing.GetIsFlagSet(position, extents, Pathing.PolyFlag_NoBuild) and Pathing.GetIsFlagSet(position, extents, Pathing.PolyFlag_Walk)
end

local function GetBuildAttachRequirementsMet(techId, position, teamNumber, snapRadius, normal)

	local legalBuild = true
	local attachEntity = nil

	local legalPosition = Vector(position)

	-- Make sure we're within range of something that's required (ie, an infantry portal near a command station)
	local attachRange = LookupTechData(techId, kStructureAttachRange, 0)

	-- Use a special power-aware filter if power is required
	local attachRequiresPower = LookupTechData(techId, kStructureAttachRequiresPower, false)
	local filterFunction = GetEntitiesForTeamWithinRange
	if attachRequiresPower then
		filterFunction = FindPoweredAttachEntities
	end

	local buildNearClass = LookupTechData(techId, kStructureBuildNearClass)
	if buildNearClass then

		local ents = {}

		-- Handle table of class names
		if type(buildNearClass) == "table" then
			for index, className in ipairs(buildNearClass) do
				table.copy(filterFunction(className, teamNumber, position, attachRange), ents, true)
			end
		else
			ents = filterFunction(buildNearClass, teamNumber, position, attachRange)
		end

		legalBuild = (table.count(ents) > 0)

	end

	local attachId = LookupTechData(techId, kStructureAttachId)
	-- prevent creation if this techId requires another techId in range
	if attachId then

		local supportingTechIds = {}

		if type(attachId) == "table" then
			for index, currentAttachId in ipairs(attachId) do
				table.insert(supportingTechIds, currentAttachId)
			end
		else
			table.insert(supportingTechIds, attachId)
		end

		local ents = GetEntsWithTechIdIsActive(supportingTechIds, attachRange, position)
		legalBuild = (table.count(ents) > 0)

	end


	-- For build tech that must be attached, find free attachment nearby. Snap position to it.
	local attachClass = LookupTechData(techId, kStructureAttachClass)
	if legalBuild and attachClass then

		-- If attach range specified, then we must be within that range of this entity
		-- If not specified, but attach class specified, we attach to entity of that type
		-- so one must be very close by (.5)

		legalBuild = LookupTechData(techId, kTechDataAttachOptional, false)

		attachEntity = GetNearestFreeAttachEntity(techId, position, snapRadius)
		if attachEntity then

			if not attachRequiresPower or (attachEntity:GetIsBuilt() and attachEntity:GetIsPowered()) then

				legalBuild = true

				VectorCopy(attachEntity:GetOrigin(), legalPosition)
				normal = attachEntity:GetCoords().yAxis

			end

		end

	end

	return legalBuild, legalPosition, attachEntity, normal

end


local function GetTeamNumber(player, ignoreEntity)

	local teamNumber = -1

	if player then
		teamNumber = player:GetTeamNumber()
	elseif ignoreEntity then
		teamNumber = ignoreEntity:GetTeamNumber()
	end

	return teamNumber

end

local function CheckValidIPPlacement(position, extents)

	local trace = Shared.TraceBox(extents, position - Vector(0, 0.3, 0), position - Vector(0, 3, 0), CollisionRep.Default, PhysicsMask.AllButPCs, EntityFilterAll())
	local valid = true
	if trace.fraction == 1 then
		local traceStart = position + Vector(0, 0.3, 0)
		local traceSurface = Shared.TraceRay(traceStart, traceStart - Vector(0, 0.4, 0), CollisionRep.Default, PhysicsMask.AllButPCs, EntityFilterAll())
		valid = traceSurface.surface ~= "no_ip"
	end

	return valid

end

local function GetGroundAtPointWithCapsule(position, extents, filter)
	local physicsGroupMask = PhysicsMask.CommanderBuild
	local kCapsuleSize = 0.1

	local topOffset = extents.y + kCapsuleSize
	local startPosition = position + Vector(0, topOffset, 0)
	local endPosition = position - Vector(0, 1000, 0)

	local trace
	if filter == nil then
		trace = Shared.TraceCapsule(startPosition, endPosition, kCapsuleSize, 0, CollisionRep.Move, physicsGroupMask)
	else
		trace = Shared.TraceCapsule(startPosition, endPosition, kCapsuleSize, 0, CollisionRep.Move, physicsGroupMask, filter)
	end

   -- If we didn't hit anything, then use our existing position. This
   -- prevents objects from constantly moving downward if they get outside
   -- of the bounds of the map.
	if trace.fraction ~= 1 then
		return trace.endPoint - Vector(0, 2 * kCapsuleSize, 0), trace.normal
	else
		return position, trace.normal
	end
end

local function GetIsStructureExitValid(origin, direction, range)

    local capsuleRadius = 0.5
    local capsuleHeight = 0.5

    local groundOffset = Vector(0, 0.1 + capsuleHeight/2 + capsuleRadius, 0)
    local startPoint = origin + groundOffset
    local endPoint = startPoint + direction * range
    local trace = Shared.TraceCapsule(startPoint, endPoint, capsuleRadius, capsuleHeight, CollisionRep.Move, PhysicsMask.AIMovement, nil)

    return trace.fraction == 1

end

local function CheckValidExit(techId, position, angle)

    local directionVec = GetNormalizedVector(Vector(math.sin(angle), 0, math.cos(angle)))

    local validExit = true

    local validExit = GetIsStructureExitValid(position, directionVec, 5)

    return validExit, not validExit and "COMMANDERERROR_NO_EXIT" or nil

end

local last_check = -1000
local prevValidOddPos = true
--
--Returns true or false if build attachments are fulfilled, as well as possible attach entity
--to be hooked up to. If snap radius passed, then snap build origin to it when nearby. Otherwise
--use only a small tolerance to see if entity is close enough to an attach class.
--
function GetIsBuildLegal(techId, position, angle, snapRadius, player, ignoreEntity, ignoreChecks, inabsolute)

	local legalBuild = true
	local extents = GetExtents(techId)

	local attachEntity = nil
	local errorString = nil

	local filter = CreateFilter(ignoreEntity)

	-- Snap to ground
	local legalPosition, normal = GetGroundAtPointWithCapsule(position, extents, filter)

	-- Check attach points
	local teamNumber = GetTeamNumber(player, ignoreEntity)
	if buildRestrictions then
		legalBuild, legalPosition, attachEntity, normal = GetBuildAttachRequirementsMet(techId, legalPosition, teamNumber, snapRadius, normal)
	end

	if not legalBuild then
		errorString = "COMMANDERERROR_OUT_OF_RANGE"
	end

	if buildRestrictions then
		local spawnBlock = LookupTechData(techId, kTechDataSpawnBlock, false)
		if spawnBlock and legalBuild then
			legalBuild = #GetEntitiesForTeamWithinRange("SpawnBlocker", player:GetTeamNumber(), position, kSpawnBlockRange) == 0
			errorString = (not legalBuild) and "COMMANDERERROR_MUST_WAIT" or nil
		end
	end

	if legalBuild then

		legalBuild = legalBuild and CheckBuildTechAvailable(techId, teamNumber)

		if not legalBuild then
			errorString = "COMMANDERERROR_TECH_NOT_AVAILABLE"
		end

	end

	if not attachEntity and legalBuild and buildRestrictions then

		local isNotOddPos = GetPathingRequirementsMet(legalPosition, extents)
		if not isNotOddPos then
			if not inabsolute or Shared.GetTime() > last_check + 0.2 then
				last_check = Shared.GetTime()
				local ents = GetEntitiesWithinRange("Entity", legalPosition, 12)
				local self_pos = LookupTechData(techId, kTechDataMaxExtents)
				self_pos = legalPosition + (self_pos and self_pos.y / 2 or 0.5)
				for i = 1, #ents do
					local ent = ents[i]
					if HasMixin(ent, "Construct") or ent:isa "Player" then
						local ent_pos
						if ent.GetEngagementPoint then
							ent_pos = ent:GetEngagementPoint()
						else
							ent_pos = LookupTechData(ent:GetTechId(), kTechDataMaxExtents)
							ent_pos = ent:GetOrigin() + (ent_pos and ent_pos.y / 2 or 0.5)
						end
						local trace = Shared.TraceRay(self_pos, ent_pos, CollisionRep.Move, PhysicsMask.AllButPCsAndRagdollsAndBabblers, filter)

						if trace.entity == ent then
							legalBuild = true
							prevValidOddPos = true
							goto next
						end
					end
				end
				legalBuild = false
				prevValidOddPos = false
			else
				legalBuild = prevValidOddPos
			end
		end

		::next::
	end

	-- Check infestation requirements
	if legalBuild then

		legalBuild = legalBuild and GetInfestationRequirementsMet(techId, legalPosition)
		if not legalBuild then
			errorString = "COMMANDERERROR_INFESTATION_REQUIRED"
		end

	end

	if legalBuild then

		-- dont allow dropping on infestation
		if LookupTechData(techId, kTechDataNotOnInfestation, false) and GetIsPointOnInfestation(legalPosition) then
			legalBuild = false
		end

		if not legalBuild then
			errorString = "COMMANDERERROR_NOT_ALLOWED_ON_INFESTATION"
		end

	end

	-- Check special build requirements. We do it here because we have the trace from the building available to find out the normal
	if legalBuild and buildRestrictions then

		local method = LookupTechData(techId, kTechDataBuildRequiresMethod, nil)
		if method then

			-- DL: As the normal passed in here isn't used to orient the building - don't bother working it out exactly. Up should be good enough.
			legalBuild = method(techId, legalPosition, normal, player)

			if not legalBuild then

				local customMessage = LookupTechData(techId, kTechDataBuildMethodFailedMessage, nil)

				if customMessage then
					errorString = customMessage
				else
					errorString = "COMMANDERERROR_BUILD_FAILED"
				end

			end

		end

	end

    if legalBuild and (not ignoreChecks or ignoreChecks["ValidExit"] ~= true) and techId == kTechId.RoboticsFactory then
        legalBuild, errorString = CheckValidExit(techId, legalPosition, angle)
    end

	if legalBuild and techId == kTechId.InfantryPortal and buildRestrictions then

		legalBuild = CheckValidIPPlacement(legalPosition, extents)
		if not legalBuild then
			errorString = "COMMANDERERROR_INVALID_PLACEMENTS"
		end

	end

	return legalBuild, legalPosition, attachEntity, errorString, normal

end
