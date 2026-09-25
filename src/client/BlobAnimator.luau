-- A pacák lapulása és nyúlása (squash & stretch). Csak látvány, minden kliens a saját gépén számolja
-- minden játékos pacájára: ugráskor megnyúlik, földet éréskor ellapul, mozgás közben rezeg.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BlobAnimator = {}

-- Pacánként: az utolsó függőleges sebesség, a levegőben volt-e, és a földet érés lapulása.
local states: { [BasePart]: { lastVy: number, wasAir: boolean, impact: number } } = setmetatable({}, { __mode = "k" }) :: any

local function animate(blob: BasePart, mesh: SpecialMesh, humanoid: Humanoid, root: BasePart, dt: number, t: number)
	local state = states[blob]
	if not state then
		state = { lastVy = 0, wasAir = false, impact = 0 }
		states[blob] = state
	end

	local velocity = root.AssemblyLinearVelocity
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	if state.wasAir and not airborne then
		-- Földet érés: minél gyorsabban esett, annál jobban ellapul.
		state.impact = math.clamp(-state.lastVy / 70, 0.15, 0.45)
	end
	state.wasAir = airborne
	state.lastVy = velocity.Y
	state.impact *= math.exp(-dt * 9)

	local stretch = if airborne then math.clamp(velocity.Y / 90, -0.2, 0.25) else 0
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local wobble = if airborne then 0 else math.sin(t * 16) * 0.06 * math.min(speed / 24, 1)

	local sy = 1 + stretch - state.impact + wobble
	local sxz = 1 / math.sqrt(sy) -- a térfogat nagyjából marad
	mesh.Scale = Vector3.new(sxz, sy, sxz)
	-- Az alja maradjon a helyén: a középpontot annyival toljuk, amennyivel a magasság változott.
	mesh.Offset = Vector3.new(0, (sy - 1) * blob.Size.Y / 2, 0)
end

function BlobAnimator.start()
	RunService.RenderStepped:Connect(function(dt)
		local t = os.clock()
		for _, player in Players:GetPlayers() do
			local character = player.Character
			if not character then
				continue
			end
			local blob = character:FindFirstChild("Blob") :: BasePart?
			local mesh = blob and blob:FindFirstChildOfClass("SpecialMesh")
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if blob and mesh and humanoid and root then
				animate(blob, mesh, humanoid, root, dt, t)
			end
		end
	end)
end

return BlobAnimator
