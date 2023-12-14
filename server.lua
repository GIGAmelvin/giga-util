local colorCodes = {
  "\x1b[31m", -- Red
  "\x1b[32m", -- Green
  "\x1b[33m", -- Yellow
  "\x1b[34m", -- Blue
  "\x1b[35m", -- Magenta (Purple)
  "\x1b[36m", -- Cyan (Light Blue)
  "\x1b[37m", -- White
}

local function stringToHash(str)
  local hash = 0
  for i = 1, #str do
    local c = str:byte(i)
    hash = ((hash * 31) + c) % 255
  end
  return hash
end

local function hashToColor(hash)
  local index = (hash % #colorCodes) + 1
  return colorCodes[index]
end

local function tPrint(tbl, indent)
  indent = indent or 0
  if type(tbl) == "table" then
    for k, v in pairs(tbl) do
      local tblType = type(v)
      local formatting = ("%s ^3%s:^0"):format(string.rep("  ", indent), k)

      if tblType == "table" then
        print(formatting)
        tPrint(v, indent + 1)
      elseif tblType == "boolean" then
        print(("%s^1 %s ^0"):format(formatting, v))
      elseif tblType == "function" then
        print(("%s^9 %s ^0"):format(formatting, v))
      elseif tblType == "number" then
        print(("%s^5 %s ^0"):format(formatting, v))
      elseif tblType == "string" then
        print(("%s ^2'%s' ^0"):format(formatting, v))
      else
        print(("%s^2 %s ^0"):format(formatting, v))
      end
    end
  else
    print(("%s ^0%s"):format(string.rep("  ", indent), tbl))
  end
end

local function Debug(identifier, ...)
  local colorCode = hashToColor(stringToHash(identifier))
  print(("%s[ %s ]^0"):format(colorCode, identifier))
  tPrint(...)
  print(("%s[ END %s ]\x1b[0m"):format(colorCode, identifier))
end

RegisterNetEvent("giga-util:server:Debug")
AddEventHandler("giga-util:server:Debug", Debug)
