-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil
Game = Game or nil
Counter = Counter or 0

Logs = Logs or {}

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

function addLog(msg, text) -- Function definition commented for performance, can be used for debugging
  Logs[msg] = Logs[msg] or {}
  table.insert(Logs[msg], text)
end

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

function adjustPosition(n1, n2)
  if math.abs(n1 - n2) > 20 then
    if n1 < 20 and n2 >= 20 then
      n2 = n2 - 40
    end
    
    if n1 >= 20 and n2 < 20 then
      n1 = n1 - 40
    end
  end

  return n1, n2
end

local function getDirections(x1, y1, x2, y2, isAway)
  if isAway == nil then
    isAway = false
  end

  x1, x2 = adjustPosition(x1, x2)
  y1, y2 = adjustPosition(y1, y2)
--  print("x1: " .. x1 .. " y1:" .. y1 .. " x2: " .. x2 .. " y2: " .. y2)
  local dx, dy = x2 - x1, y2 - y1
  local dirX, dirY = "", ""
--  print("dx:" .. dx .. " dy:" .. dy)

  if isAway then
    if dx > 0 then dirX = "Left" else dirX = "Right" end
    if dy > 0 then dirY = "Up" else dirY = "Down" end
  else
    if dx > 0 then dirX = "Right" else dirX = "Left" end
    if dy > 0 then dirY = "Down" else dirY = "Up" end
  end
  
  print(dirY .. dirX)
  return dirY .. dirX
end
function getDirectionTowards(point1x, point1y, point2x, point2y)

	local dx = point2x - point1x

	if dx > 0 then
		return "Right"
	elseif dx < 0 then
		return "Left"
	end

	if dy > 0 then
		return "Up"
	elseif dy < 0 then
		return "Down"
	end
end
-- Decides the next action based on player proximity and energy.
-- If any player is within range, it initiates an attack; otherwise, moves randomly.
function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false
  local lowestHealth = 100
  local weakestPlayer = nil

  for target, state in pairs(LatestGameState.Players) do
      if target ~= ao.id and inRange(player.x, player.y, state.x, state.y, 3) and player.energy >= state.health then
        if state.health < lowestHealth then
            lowestHealth = state.health
            weakestPlayer = target
        end
		if inRange(player.x, player.y, state.x, state.y, 1) then
            targetInRange = true
        end
      end
  end
  if player.energy >= lowestHealth and weakestPlayer and targetInRange then
    print(colors.red .. "Player in range. Attacking... Other Player health:" .. lowestHealth .. colors.reset)
	ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(player.energy)})
  else
    if weakestPlayer and player.energy > 1 then
      local moveDir = getDirections(me.x, me.y, player.x, player.y, false)
      print(Colors.red .. "Approaching the enemy. Move " .. moveDir .. Colors.reset)
      ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = moveDir})
    else
      -- If all players have full health, move randomly
      local directionMap = {"Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft"}
      local randomIndex = math.random(#directionMap)
      ao.send({Target = Game, Action = "PlayerMove", Direction = directionMap[randomIndex]})
    end
  end
  print(colors.red .. "Player energy:" .. player.energy .. " -- Player health:" .. player.health .. colors.reset)
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    ao.send({Target = Game, Action = "GetGameState"})
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    print("Location: " .. "row: " .. LatestGameState.Players[ao.id].x .. ' col: ' .. LatestGameState.Players[ao.id].y)

  end
)

-- Handler to trigger game state updates.
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
      -- print(colors.gray .. "Getting game state..." .. colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
  end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    --print("Game state updated. Print \'LatestGameState\' for detailed view.")
    print("Location: " .. "row: " .. LatestGameState.Players[ao.id].x .. ' col: ' .. LatestGameState.Players[ao.id].y)
  end
)

-- Handler to decide the next best action.
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    --print("Deciding next action...")
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    local playerEnergy = LatestGameState.Players[ao.id].energy
    if playerEnergy == undefined then
      print(colors.red .. "Unable to read energy." .. colors.reset)
      ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
    elseif playerEnergy > 10 then
      print(colors.red .. "Player has insufficient energy." .. colors.reset)
      ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
    else
      print(colors.red .. "Returning attack..." .. colors.reset)
      ao.send({Target = Game, Action = "PlayerAttack", AttackEnergy = tostring(playerEnergy)})
    end
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

Prompt = function () return Name .. "> " end

