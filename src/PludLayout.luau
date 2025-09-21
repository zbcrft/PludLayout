local tween_service = game:GetService("TweenService")

local MAX_ITERATION = 100

export type Layout = {
	Padding: UDim2;
	Size: UDim2;
	ConstantUpdates: boolean;
	SmoothUpdates: boolean;
	UpdateTween: TweenInfo; -- only works with constant updates and smooth updates
	Linked: Frame;
	whitelisted: {};
	blacklisted: {[Object]: boolean};
	initialized: {[Object]: boolean};
}

local plud_layout = {}
plud_layout.__index =  plud_layout

function plud_layout.create_layout(grid_data: Layout)
	local self: Layout = setmetatable({
		blacklisted = {};
		whitelisted = {};
		initialized = {};
	}, plud_layout)

	for i, v in grid_data do
		self[i] = v
	end

	self.Linked.ChildAdded:Connect(function(child)
		--print(`New child: {child}`)
		self:whitelist(child)
	end)

	self.Linked.ChildRemoved:Connect(function(child)
		--print(`Lost child: {child}`)
		self:remove(child)
	end)
	
	for _, child in self.Linked:GetChildren() do
		self:whitelist(child)
	end

	return self
end

local function get_offset(UDim: UDim, AbsoluteSize: number): number
	return AbsoluteSize*UDim.Scale+UDim.Offset
end

function plud_layout:update()
	local cleaned = {}
	if self.ConstantUpdates then
		for _, obj in self.whitelisted do
			if obj and obj.Parent and not table.find(self.blacklisted, obj) then
				table.insert(cleaned, obj)
			end
		end
		self.whitelisted = cleaned
	end
	
	local offset = -1
	local taken_collumns = {}::{[number]:{number}}
	
	local parent_w = self.Linked.AbsoluteSize.X
	local parent_h = self.Linked.AbsoluteSize.Y
	local cell_w = get_offset(self.Size.X, parent_w)
	local cell_h = get_offset(self.Size.Y, parent_h)
	local pad_w = get_offset(self.Padding.X, parent_w)
	local pad_h = get_offset(self.Padding.Y, parent_h)

	local collumns = parent_w//(cell_w+pad_w)
	
	for i = 1, #self.whitelisted do
		local obj = self.whitelisted[i]

		local obj_w = get_offset(obj.Size.X, parent_w)
		local obj_h = get_offset(obj.Size.Y, parent_h)
		local grid_x = math.ceil(obj_w/cell_w)
		local grid_y = math.ceil(obj_h/cell_h)
		
		i += offset
		local row = (i)//collumns
		local collumn = (i)%collumns
		
		if grid_x > 1 and collumn == collumns-1 then
			i += 1
			offset += 1
			
			row = (i)//collumns
			collumn = (i)%collumns
		end
		
		for iter = 1, MAX_ITERATION do
			if taken_collumns[row] and table.find(taken_collumns[row], collumn) then
				offset += 1
				i += 1
				
				row = (i)//collumns
				collumn = (i)%collumns
			else
				break
			end

			if iter == MAX_ITERATION then
				warn("Reached max iteration for trying to find the next position of an element")
			end
		end
		
		if grid_x > 1 or grid_y > 1 then
			for offset_x = 0, grid_x-1 do
				for offset_y = 0, grid_y-1 do
					local offset_row = row + offset_y
					local offset_collumn = collumn + offset_x
					
					if not taken_collumns[offset_row] then
						taken_collumns[offset_row] = {}
					end
					
					table.insert(taken_collumns[offset_row], offset_collumn)
				end
			end
		end
		
		local pos = UDim2.fromOffset(collumn*(cell_w+pad_w),row*(cell_h+pad_h))
		
		if obj.Position == pos then continue end
		
		if self.SmoothUpdates and self.UpdateTween then
			tween_service:Create(obj, self.UpdateTween, {Position = pos}):Play()
		else
			obj.Position = pos
		end

		self.initialized[obj] = true
	end
end

function plud_layout:unwhitelist(obj: Object)
	if not obj then return end
	
	for i = 1, #self.whitelisted do
		if self.whitelisted[i] == obj then
			self.whitelisted[i] = nil
			break
		end
	end
end

function plud_layout:remove(obj: Object)
	if not obj then return end
	
	self.blacklisted[obj] = nil
	
	self:unwhitelist(obj)
	
	self.initialized[obj] = nil
end

function plud_layout:blacklist(obj: Object)
	if not obj then return end
	self.blacklisted[obj] = true

	self:unwhitelist(obj)

	self.initialized[obj] = false
end


function plud_layout:whitelist(obj: Object)
	if not obj then return end
	self.blacklisted[obj] = nil

	local slot_found = false
	for i = 1, #self.whitelisted do
		if self.whitelisted[i] == nil then
			self.whitelisted[i] = obj
			slot_found = true
			break
		end
	end
	if not slot_found then
		table.insert(self.whitelisted, obj)
	end
end

return plud_layout
