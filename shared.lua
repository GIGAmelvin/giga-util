if IsDuplicityVersion() then
  math.randomseed(os.time())
else
  math.randomseed(GetGameTimer())
end

local function isLeapYear(year)
  return year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0)
end

local function utcTimeToEpoch(year, month, day, hour, minute, second)
  local months = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, }

  -- Adjust for leap years
  if month > 2 and isLeapYear(year) then
    day = day + 1
  end

  -- Convert year to days (not considering leap years here)
  local daysInYears = (year - 1970) * 365

  -- Add days for each leap year since 1970
  for y = 1970, year - 1 do
    if isLeapYear(y) then
      daysInYears = daysInYears + 1
    end
  end

  -- Convert months to days
  local daysInMonths = 0
  for i = 1, month - 1 do
    daysInMonths = daysInMonths + months[i]
  end

  local totalSeconds = second
  totalSeconds = totalSeconds + minute * 60
  totalSeconds = totalSeconds + hour * 3600
  totalSeconds = totalSeconds + (day - 1 + daysInMonths + daysInYears) * 86400

  return totalSeconds
end

local function now()
  if IsDuplicityVersion() then
    return os.time() * 1000
  else
    return utcTimeToEpoch(GetUtcTime()) * 1000
  end
end

local function memoize(func, ttl)
  local cache = {}

  return function(...)
    local args = { ..., }
    local stringed = {}
    for _, arg in ipairs(args) do
      table.insert(stringed, tostring(arg))
    end
    local key = table.concat(stringed, "_")

    local currentTime = now()

    if type(cache[key]) == "table" then
      -- If there's a TTL and the cached value has expired
      if ttl and (currentTime - cache[key].time) > ttl then
        cache[key] = nil
      else
        return table.unpack(cache[key].value)
      end
    end
    if type(cache[key]) ~= "table" then
      -- Avoid caching nil
      local result = table.pack(func(...))
      if result == nil then return end
      local hasKeys = false
      for _ in pairs(result) do
        hasKeys = true
        break
      end
      if not hasKeys then return end
      cache[key] = {
        value = result,
        time = currentTime,
      }
    end

    return table.unpack(cache[key].value)
  end
end


local function debounce(fn, delay)
  local lastTriggered = 0

  return function(...)
    local args = { ..., }
    local currentTime = now()

    if currentTime - lastTriggered < delay then
      return
    end

    lastTriggered = currentTime

    Citizen.CreateThread(function()
      Citizen.Wait(delay)
      fn(table.unpack(args))
    end)
  end
end

local function throttle(fn, delay)
  local lastExecutionTime = 0

  return function(...)
    local currentTime = now()
    local diff = currentTime - lastExecutionTime

    if diff >= delay then
      fn(...)
      lastExecutionTime = currentTime
    end
  end
end

local function clamp(number, min_value, max_value)
  return math.max(math.min(number, max_value), min_value)
end

local function omit(inputTable, keysToRemove)
  local result = {}

  for key, value in pairs(inputTable) do
    if not keysToRemove[key] then
      result[key] = value
    end
  end

  return result
end

local function mergeTables(...)
  local result = {}

  for _, tbl in ipairs({ ..., }) do
    for key, value in pairs(tbl) do
      result[key] = value
    end
  end

  return result
end

local function deepMergeTables(...)
  local result = {}

  local function merge(destination, source)
    for key, value in pairs(source) do
      if type(value) == "table" and type(destination[key]) == "table" then
        merge(destination[key], value)
      else
        destination[key] = value
      end
    end
  end

  for _, tbl in ipairs({ ..., }) do
    merge(result, tbl)
  end

  return result
end

-- Pass in a table, a path, and a default fallback value
-- print(get({ foo = { bar = { baz = 'bam' } } }, 'foo.bar.baz', 'fizz'))   -- prints 'bam'
-- print(get({ foo = 'bar' }, 'baz.bam', 17))                              -- prints 17
-- print(get({ a = { ['asd def ghj'] = 5 } }, "a['asd def ghj']", 999))    -- prints 5
local function get(tbl, path, fallback)
  if tbl == nil then
    return nil
  end

  local function split(p)
    local segments = {}
    local inBracket = false
    local currSegment = ""

    for i = 1, #p do
      local char = p:sub(i, i)

      if char == "[" then
        if #currSegment > 0 then
          table.insert(segments, currSegment)
          currSegment = ""
        end
        inBracket = true
      elseif char == "]" then
        inBracket = false
      elseif char == "." and not inBracket then
        if #currSegment > 0 then
          table.insert(segments, currSegment)
          currSegment = ""
        end
      else
        currSegment = currSegment .. char
      end
    end

    if #currSegment > 0 then
      currSegment = currSegment:gsub("^'(.+)'$", "%1"):gsub('^"(.+)"$', "%1")
      table.insert(segments, currSegment)
    end

    return segments
  end

  local segments = split(path)
  local currentValue = tbl

  for _, segment in ipairs(segments) do
    if currentValue[segment] == nil then
      return fallback
    else
      currentValue = currentValue[segment]
    end
  end

  return currentValue
end

local function tryJson(v)
  local function decode()
    return json.decode(v)
  end
  local success, result = pcall(decode)
  if success then return result end
  return nil
end

local function commaSeparateString(str, sep)
  local result = {}
  for match in (str .. sep):gmatch("(.-)" .. sep) do
    table.insert(result, match)
  end
  return result
end

local function Debugger(identifier)
  local configuration = GetConvar("DEBUG", "")
  if configuration == "" then return function() end end
  if type(configuration) ~= "string" or type(identifier) ~= "string" then return function() end end
  local patterns = commaSeparateString(configuration, ",")

  return function(...)
    for _, pat in ipairs(patterns) do
      -- Escape hyphens and convert
      -- wildcard '*' to regex pattern '.*'
      local pattern = pat:gsub("-", "%%-"):gsub("%*", ".*")
      if not identifier:match(pattern) then
        goto continue
      end
      if IsDuplicityVersion() then
        TriggerEvent("giga-util:server:Debug", identifier, ...)
        break
      end
      TriggerServerEvent("giga-util:server:Debug", identifier, ...)
      break
      ::continue::
    end
  end
end

local function EnumerateEntitiesWithinDistance(entities, isPlayerEntities, coords, maxDistance)
  local nearbyEntities = {}
  if coords then
    coords = vector3(coords.x, coords.y, coords.z)
  else
    local playerPed = GetPlayerPed(-1)
    coords = GetEntityCoords(playerPed)
  end
  for k, entity in pairs(entities) do
    local distance = #(coords - GetEntityCoords(entity))

    if distance <= maxDistance then
      nearbyEntities[#nearbyEntities+1] = isPlayerEntities and k or entity
    end
  end
  return nearbyEntities
end

local function ChanceBoolean(probability)
  return math.random() <= probability
end

local function ChanceRange(min, max)
  return math.random() * (max - min) + min
end

local e = {
  Function = {
    Memoize = memoize,
    Debounce = debounce,
    Throttle = throttle,
  },
  Table = {
    Omit = omit,
    Merge = mergeTables,
    Deep = {
      Merge = deepMergeTables,
    },
    Get = get,
  },
  Number = {
    Clamp = clamp,
  },
  String = {
    JSON = {
      Try = {
        Decode = tryJson,
      },
    },
  },
  Debugger = Debugger,
  Entity = {
    Enumerate = {
      Within = {
        Distance = EnumerateEntitiesWithinDistance,
      },
    },
  },
  Chance = {
    Boolean = ChanceBoolean,
    Range = ChanceRange,
  },
  Time = {
    Epoch = now,
  },
}

local function GetUtils()
  return e
end

exports("GetUtils", GetUtils)
