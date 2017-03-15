if Server then
	local function GetTeleportClassname(techId)

	    if not gTeleportClassnames then

	        gTeleportClassnames = {}
	        gTeleportClassnames[kTechId.TeleportHydra] = "Hydra"
	        gTeleportClassnames[kTechId.TeleportWhip] = "Whip"
	        gTeleportClassnames[kTechId.TeleportTunnel] = "TunnelEntrance"
	        gTeleportClassnames[kTechId.TeleportCrag] = "Crag"
	        gTeleportClassnames[kTechId.TeleportShade] = "Shade"
	        gTeleportClassnames[kTechId.TeleportShift] = "Shift"
	        gTeleportClassnames[kTechId.TeleportVeil] = "Veil"
	        gTeleportClassnames[kTechId.TeleportSpur] = "Spur"
	        gTeleportClassnames[kTechId.TeleportShell] = "Shell"
	        gTeleportClassnames[kTechId.TeleportHive] = "Hive"
	        gTeleportClassnames[kTechId.TeleportEgg] = "Egg"
	        gTeleportClassnames[kTechId.TeleportHarvester] = "Harvester"

	    end

	    return gTeleportClassnames[techId]


	end

	function Shift:TriggerEcho(techId, position)

        local teleportClassname = GetTeleportClassname(techId)
        local teleportCost = LookupTechData(techId, kTechDataCostKey, 0)

        local success = false

--Log("Tech ID: %s", kTechId[techId]);
        local validPos, _1, _2, _3, requiresActivation = GetIsBuildLegal(techId, position, 0, kStructureSnapRadius, self:GetOwner(), self)

        local builtStructures = {}
        local matureStructures = {}

        if validPos then

            local teleportAbles = GetEntitiesForTeamWithinRange(teleportClassname, self:GetTeamNumber(), self:GetOrigin(), kEchoRange)

                for index, entity in ipairs(teleportAbles) do
                    if HasMixin(entity, "Construct") and entity:GetIsBuilt() then
                        table.insert(builtStructures, entity)
                        if HasMixin(entity, "Maturity") and entity:GetIsMature() then
                            table.insert(matureStructures, entity)
                        end
                    end
                end

                if #matureStructures > 0 then
                    teleportAbles = matureStructures
                elseif #builtStructures > 0 then
                    teleportAbles = builtStructures
                end

                Shared.SortEntitiesByDistance(self:GetOrigin(), teleportAbles)

            for _, teleportAble in ipairs(teleportAbles) do

                if teleportAble:GetCanTeleport() then

                    teleportAble:TriggerTeleport(5, self:GetId(), position, teleportCost, requiresActivation);

                    if HasMixin(teleportAble, "Orders") then
                        teleportAble:ClearCurrentOrder()
                    end

                    self:TriggerEffects("shift_echo")
                    success = true
                    self.echoActive = true
                    self.timeLastEcho = Shared.GetTime()
                    break

                end

            end

        end

        return success

    end
end
