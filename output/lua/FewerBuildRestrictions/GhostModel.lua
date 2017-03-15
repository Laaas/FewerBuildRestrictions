local kMaterialDubious = PrecacheAsset("cinematics/vfx_materials/placement_dubious.material");
local kArrowSize = Vector(24, 24, 0);

function GhostModel:SetRequiresActivation()
	self.renderMaterial:SetMaterial(kMaterialDubious);
end

-- children can override, but make sure to call this function as well
function GhostModel:Update()

    local player = Client.GetLocalPlayer()

    self.attachArrow:SetIsVisible(false)
    self:SetIsVisible(true)

    if player:isa("Commander") then
        self.renderMaterial:SetParameter("edge", 0)
    else
        self.renderMaterial:SetParameter("edge", 3)
    end

    local modelName = GhostModelUI_GetModelName()
    if not modelName then

        self:SetIsVisible(false)
        return

    end

    local modelIndex = Shared.GetModelIndex(modelName)
    local modelCoords = GhostModelUI_GetGhostModelCoords()
    local isValid, requiresActivation = GhostModelUI_GetIsValidPlacement()

    if not modelIndex then

        self:SetIsVisible(false)
        return

    end

    if self.loadedModelIndex ~= modelIndex then

        self.renderModel:SetModel(modelIndex)
        self.renderModel:InstanceMaterials()

        if player and player.GetIgnoreGhostHighlight and player:GetIgnoreGhostHighlight() ~= true then
            self.renderModel:SetMaterialParameter("highlight", 1)
        end

        self.loadedModelIndex = modelIndex

    end

    if self.validLoaded ~= nil or self.validLoaded ~= isValid then

		if isValid then
			if requiresActivation then
				self:SetRequiresActivation();
			else
				self:LoadValidMaterial(true);
			end
        else
			self:LoadValidMaterial(false);
		end
        self.validLoaded = isValid

    end

    if not modelCoords or not modelCoords:GetIsFinite() then

        self:SetIsVisible(false)
        return nil

    else

        self.renderModel:SetCoords(modelCoords)

        local direction = GhostModelUI_GetNearestAttachPointDirection()
        direction = direction or GhostModelUI_GetNearestAttachStructureDirection()
        if direction then

            self.attachArrow:SetIsVisible(true)
            local arrowDist = 3
            arrowDist = arrowDist + ((math.cos(Shared.GetTime() * 8) + 1) / 2)
            self.attachArrow:SetPosition(Client.WorldToScreen(modelCoords.origin + direction * arrowDist) - kArrowSize / 2)
            self.attachArrow:SetRotation(Vector(0, 0, GetYawFromVector(direction) + math.pi / 2))

        end

        if player and player.currentTechId then

            local radius = LookupTechData(player.currentTechId, kVisualRange, nil)

            if radius then

                player:AddGhostGuide(Vector(modelCoords.origin), radius)

            end

        end

    end

    return modelCoords

end
