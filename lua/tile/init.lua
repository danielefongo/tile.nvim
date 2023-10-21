local v = vim.api
local tile = {}
tile.__index = tile
tile.opts = {
  horizontal = 4,
  vertical = 2,
  min_width = 1,
  min_height = 1,
}

local node = require("tile.node")

local function clamp(value, max)
  if value < max then
    return value
  else
    return max
  end
end

local resize_left
local resize_right
local resize_down
local resize_up

resize_left = function(leaf_node, current_node)
  current_node = current_node or leaf_node
  local leaf_spec = leaf_node.spec
  local parent_node = current_node.parent()

  if not parent_node then
    return
  end

  if parent_node.type == "row" then
    if current_node.idx == current_node.last_idx then
      for idx = current_node.idx - 1, 1, -1 do
        local sibling_spec = parent_node.children[idx].spec

        if sibling_spec.row_space > 0 then
          return v.nvim_win_set_width(0, leaf_spec.width + clamp(tile.opts.horizontal, sibling_spec.row_space))
        end
      end
    else
      v.nvim_win_set_width(0, leaf_spec.width - tile.opts.horizontal)
    end
  else
    resize_left(leaf_node, parent_node)
  end
end

resize_right = function(leaf_node, current_node)
  current_node = current_node or leaf_node
  local leaf_spec = leaf_node.spec
  local parent_node = current_node.parent()

  if not parent_node then
    return
  end

  if parent_node.type == "row" then
    if current_node.idx == current_node.last_idx then
      v.nvim_win_set_width(0, leaf_spec.width - tile.opts.horizontal)
    else
      for idx = current_node.idx + 1, current_node.last_idx, 1 do
        local sibling_spec = parent_node.children[idx].spec

        if sibling_spec.row_space > 0 then
          return v.nvim_win_set_width(0, leaf_spec.width + clamp(tile.opts.horizontal, sibling_spec.row_space))
        end
      end
    end
  else
    resize_right(leaf_node, parent_node)
  end
end

resize_up = function(leaf_node, current_node)
  current_node = current_node or leaf_node
  local leaf_spec = leaf_node.spec
  local parent_node = current_node.parent()

  if not parent_node then
    return
  end

  if parent_node.type == "col" then
    if current_node.idx == current_node.last_idx then
      for idx = current_node.idx - 1, 1, -1 do
        local sibling_spec = parent_node.children[idx].spec

        if sibling_spec.col_space > 0 then
          return v.nvim_win_set_height(0, leaf_spec.height + clamp(tile.opts.vertical, sibling_spec.col_space))
        end
      end
    else
      v.nvim_win_set_height(0, leaf_spec.height - tile.opts.vertical)
    end
  else
    resize_up(leaf_node, parent_node)
  end
end

resize_down = function(leaf_node, current_node)
  current_node = current_node or leaf_node
  local leaf_spec = leaf_node.spec
  local parent_node = current_node.parent()

  if not parent_node then
    return
  end

  if parent_node.type == "col" then
    if current_node.idx == current_node.last_idx then
      v.nvim_win_set_height(0, leaf_spec.height - tile.opts.vertical)
    else
      for idx = current_node.idx + 1, current_node.last_idx, 1 do
        local sibling_spec = parent_node.children[idx].spec

        if sibling_spec.col_space > 0 then
          return v.nvim_win_set_height(0, leaf_spec.height + clamp(tile.opts.vertical, sibling_spec.col_space))
        end
      end
    end
  else
    resize_down(leaf_node, parent_node)
  end
end

function tile.resize_left()
  resize_left(node.find_win(v.nvim_get_current_win(), node.build()))
end

function tile.resize_right()
  resize_right(node.find_win(v.nvim_get_current_win(), node.build()))
end

function tile.resize_up()
  resize_up(node.find_win(v.nvim_get_current_win(), node.build()))
end

function tile.resize_down()
  resize_down(node.find_win(v.nvim_get_current_win(), node.build()))
end

function tile.setup(opts)
  tile.opts = vim.tbl_deep_extend("force", tile.opts, opts)
end

return tile
