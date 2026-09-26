-- PvP a kliensen: hátrapattanás, ha meglopták a pacánkat, és a festéklopás látványa.
-- A lopásról a szerver dönt (StealService); a saját karaktert viszont a kliens mozgatja,
-- ezért a hátrapattanást itt kell rátenni.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Hud = require(script.Parent.Hud)
local Sounds = require(script.Parent.Sounds)

local Pvp = {}

local function blobOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("Blob") :: BasePart?
end

-- Festékcseppek a meglopott pacától a lopó felé.
local function stealBurst(from: BasePart, to: BasePart?, color: Color3, amount: number)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = from.Position
	attachment.Parent = workspace.Terrain
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0.2) })
	emitter.Lifetime = NumberRange.new(0.35, 0.6)
	emitter.Speed = NumberRange.new(18, 30)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Acceleration = Vector3.new(0, -50, 0)
	emitter.Enabled = false
	if to then
		local direction = to.Position - from.Position
		if direction.Magnitude > 0.01 then
			attachment.WorldCFrame = CFrame.lookAt(from.Position, to.Position) * CFrame.Angles(math.rad(-90), 0, 0)
		end
	else
		emitter.SpreadAngle = Vector2.new(180, 180)
	end
	emitter.Parent = attachment
	emitter:Emit(math.clamp(amount * 4, 10, 40))
	Debris:AddItem(attachment, 1.2)
end

function Pvp.start()
	local localPlayer = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("Remotes")

	remotes:WaitForChild("Knockback").OnClientEvent:Connect(function(velocity: Vector3)
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping) -- a talajról így el tud pattanni
			root.AssemblyLinearVelocity = velocity
		end
	end)

	remotes
		:WaitForChild("Stolen").OnClientEvent
		:Connect(function(thief: Player, victim: Player, amount: number, stomp: boolean)
			local color = Config.PAINT_COLOR_BY_NAME[thief:GetAttribute("Team") or ""] or Color3.new(1, 1, 1)
			local victimBlob = blobOf(victim)
			if victimBlob then
				stealBurst(victimBlob, blobOf(thief), color, amount)
				Sounds.play("Land", victimBlob.Position)
			end
			local how = if stomp then "Stomp!" else "Bump!"
			if thief == localPlayer then
				Hud.announce(`{how} You stole {amount} paint from {victim.DisplayName}!`, color)
			elseif victim == localPlayer then
				Hud.announce(`{how} {thief.DisplayName} stole {amount} of your paint!`, color)
			end
		end)
end

return Pvp
