-- top-level requires (safe)
local function safe_require(name)
  local ok, res = pcall(require, name)
  if ok and type(res) == "table" then
    return res
  end
  return nil
end

-- Cache color tables at parse time
local colors_vanilla_generated = safe_require("colors.vanilla-generated")
local colors_vanilla_custom   = safe_require("colors.vanilla-custom")

local colors_space_age_generated = safe_require("colors.space-age-generated")

local colors_krastorio2_generated = safe_require("colors.krastorio2-generated")

-- require your vibrance module at top-level too
local color_vibrance = safe_require("color_vibrance") or error("color_vibrance module missing")


ITEM_COLORS = {} -- global used by the rest of your mod

local function rebuild_item_colors()
  -- apply runtime settings to vibrance module
  color_vibrance.apply_settings_from_game()

  -- clear existing
  for k in pairs(ITEM_COLORS) do ITEM_COLORS[k] = nil end

  -- Merge using cached tables (no require calls here)
  if colors_vanilla_generated then
    color_vibrance.merge(colors_vanilla_generated, true, ITEM_COLORS)
  end
  if colors_vanilla_custom then
    color_vibrance.merge(colors_vanilla_custom, false, ITEM_COLORS)
  end

  if script.active_mods["space-age"] then
    if colors_space_age_generated then
      color_vibrance.merge(colors_space_age_generated, true, ITEM_COLORS)
    end
  end

  if script.active_mods["Krastorio2"] and colors_krastorio2_generated then
    color_vibrance.merge(colors_krastorio2_generated, true, ITEM_COLORS)
  end
end

rebuild_item_colors()

script.on_configuration_changed(function(data)
  rebuild_item_colors()
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "train-stop-item-color-vibrance-push" or event.setting == "train-stop-item-color-saturation-boost" then
    rebuild_item_colors()
  end
end)


local function color_train_stop(entity)
    if not (entity and entity.valid and entity.type == "train-stop") then return end

    local name = entity.backer_name

    -- Find all item and fluid tags
    local items = {}
    for item in name:gmatch("%[item=([%w%-_]+)%]") do
        items[#items+1] = item
    end
    for fluid in name:gmatch("%[fluid=([%w%-_]+)%]") do
        items[#items+1] = fluid
    end

    if #items == 0 then return end

    -- Read setting
    local blend = settings.global["train-stop-item-color-blend-item-colours"].value

    -- If NOT blending, use the first matching colour and exit early
    if not blend then
        local first = items[1]
        local c = ITEM_COLORS[first]
        if not c then return end

        entity.color = {
            r = c.r,
            g = c.g,
            b = c.b,
            a = 1
        }
        return
    end

    -- Blend colours (default behaviour)
    local r, g, b = 0, 0, 0
    local count = 0

    for _, item in ipairs(items) do
        local c = ITEM_COLORS[item]
        if c then
            r = r + c.r
            g = g + c.g
            b = b + c.b
            count = count + 1
        end
    end

    if count == 0 then return end

    entity.color = {
        r = r / count,
        g = g / count,
        b = b / count,
        a = 1
    }
end


script.on_event(defines.events.on_player_selected_area, function(event)
    if event.item ~= "train-stop-color-tool" then return end

    for _, entity in pairs(event.entities) do
        color_train_stop(entity)
    end
end)

script.on_event(defines.events.on_player_alt_selected_area, function(event)
    if event.item ~= "train-stop-color-tool" then return end

    for _, entity in pairs(event.entities) do
        color_train_stop(entity)
    end
end)
