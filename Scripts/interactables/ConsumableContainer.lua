ConsumableContainer = class( nil )
ConsumableContainer.maxChildCount = 255
ConsumableContainer.colorNormal = sm.color.new( 0xcb0a00ff )
ConsumableContainer.colorHighlight = sm.color.new( 0xee0a00ff )
ConsumableContainer.connectIcon = "ammo"

local ContainerSize = 5

function ConsumableContainer.server_onCreate( self )
	local container = self.shape.interactable:getContainer( 0 )
	if not container then
		container = self.shape:getInteractable():addContainer( 0, ContainerSize, self.data.stackSize )
	end
	if self.data.filterUid then
		local filters
		if type(self.data.filterUid) == "table" then
			filters = self.data.filterUid
			for k, v in pairs(filters) do
				filters[k] = sm.uuid.new(v)
			end
		else
			filters = { sm.uuid.new( self.data.filterUid ) }
		end

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
			local gui = sm.gui.createContainerGui( true )
			gui:setText( "UpperName", "#{CONTAINER_TITLE_GENERIC}" )
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
TurretNormalAmmoContainer.connectionOutput = connectiontype_turretnormal

TurretExplosiveAmmoContainer = class( ConsumableContainer )
TurretExplosiveAmmoContainer.connectionOutput = connectiontype_turretexplosive

CannonRocketContainer = class( ConsumableContainer )
CannonRocketContainer.connectionOutput = connectiontype_cannonrocket

CannonRatshotContainer = class( ConsumableContainer )
CannonRatshotContainer.connectionOutput = connectiontype_cannonratshot

RailgunSpikeContainer = class( ConsumableContainer )
RailgunSpikeContainer.connectionOutput = connectiontype_railgunspike