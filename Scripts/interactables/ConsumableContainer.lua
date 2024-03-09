dofile( "$SURVIVAL_DATA/Scripts/game/survival_items.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

ConsumableContainer = class( nil )
ConsumableContainer.maxChildCount = 255

local ContainerSize = 5

function ConsumableContainer.server_onCreate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, ContainerSize, self.data.stackSize )
	end
	if self.data.filterUid then
		local filters = { sm.uuid.new( self.data.filterUid ) }
		container:setFilters( filters )
	end
end

function ConsumableContainer.client_canCarry( self )
	local container = self.shape.interactable:getContainer( 0 )
	if container and sm.exists( container ) then
		return not container:isEmpty()
	end
	return false
end

function ConsumableContainer.client_onInteract( self, character, state )
	if state == true then
		local container = self.shape.interactable:getContainer( 0 )
		if container then
			local gui = nil

			local shapeUuid = self.shape:getShapeUuid()

			if shapeUuid == obj_container_ammo then
				gui = sm.gui.createAmmunitionContainerGui( true )

			elseif shapeUuid == obj_container_battery then
				gui = sm.gui.createBatteryContainerGui( true )

			elseif shapeUuid == obj_container_chemical then
				gui = sm.gui.createChemicalContainerGui( true )

			elseif shapeUuid == obj_container_fertilizer then
				gui = sm.gui.createFertilizerContainerGui( true )

			elseif shapeUuid == obj_container_gas then
				gui = sm.gui.createGasContainerGui( true )

			elseif shapeUuid == obj_container_seed then
				gui = sm.gui.createSeedContainerGui( true )

			elseif shapeUuid == obj_container_water then
				gui = sm.gui.createWaterContainerGui( true )
			end

			if gui == nil then
				gui = sm.gui.createContainerGui( true )
				gui:setText( "UpperName", "#{CONTAINER_TITLE_GENERIC}" )
			end

			gui:setContainer( "UpperGrid", container )
			gui:setText( "LowerName", "#{INVENTORY_TITLE}" )
			gui:setContainer( "LowerGrid", sm.localPlayer.getInventory() )
			gui:open()
		end
	end
end

function ConsumableContainer.client_onUpdate( self, dt )
	local container = self.shape.interactable:getContainer( 0 )
	if container and self.data.stackSize then
		local quantities = sm.container.quantity( container )

		local quantity = 0
		for _,q in ipairs( quantities ) do
			quantity = quantity + q
		end

		local frame = ContainerSize - math.ceil( quantity / self.data.stackSize )
		self.interactable:setUvFrameIndex( frame )
	end
end

TurretNormalAmmoContainer = class( ConsumableContainer )
TurretNormalAmmoContainer.connectionOutput = 2^13
TurretNormalAmmoContainer.colorNormal = sm.color.new( 0x84ff32ff )
TurretNormalAmmoContainer.colorHighlight = sm.color.new( 0xa7ff4fff )

TurretExplosiveAmmoContainer = class( ConsumableContainer )
TurretExplosiveAmmoContainer.connectionOutput = 2^14
TurretExplosiveAmmoContainer.colorNormal = sm.color.new( 0x84ff32ff )
TurretExplosiveAmmoContainer.colorHighlight = sm.color.new( 0xa7ff4fff )