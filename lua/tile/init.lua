local v = vim.api
local tile = {}
tile.__index = tile
tile.opts = { horizontal = 4, vertical = 2 }

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

local function split_win(win, opts)
  vim.cmd(
    string.format(
      "noautocmd keepjumps %dwindo %s %s",
      v.nvim_win_get_number(win),
      opts.after and "belowright" or "aboveleft",
      opts.vertical and "vsp" or "sp"
    )
  )

  return v.nvim_get_current_win()
end

local function split_move_win(win, destination_win, opts)
  vim.fn.win_splitmove(win, destination_win, {
    rightbelow = opts.after,
    vertical = opts.vertical,
  })
end

local function move_node(current_node, destination_win, opts)
  if not current_node then
    return
  end

  if current_node.type ~= "leaf" then
    local tmp_win = split_win(destination_win, { after = opts.after, vertical = opts.vertical })
    for _, child in pairs(current_node.children) do
      move_node(child, tmp_win, {
        after = false,
        vertical = current_node.type ~= "col",
        ignore = opts.ignore,
      })
    end
    v.nvim_win_close(tmp_win, true)
  else
    if current_node.win ~= destination_win and current_node.win ~= opts.ignore then
      split_move_win(current_node.win, destination_win, opts)
    end
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

function tile.shift_left()
  local win_node = node.find_win(v.nvim_get_current_win(), node.build())
  local parent_node = win_node.parent()

  if parent_node.type == "row" then
    if win_node.idx == win_node.last_idx and #parent_node.children == 2 and parent_node.children[1].type == "leaf" then
      split_move_win(win_node.win, parent_node.children[1].win, { after = false, vertical = true })
    elseif win_node.idx == 1 then
      local tmp_win = split_win(win_node.win, { after = true, vertical = true })
      local grandparent = parent_node.parent()
      move_node(grandparent, tmp_win, {
        after = false,
        vertical = false,
        ignore = win_node.win,
      })
      v.nvim_win_close(tmp_win, true)
      v.nvim_set_current_win(win_node.win)
    else
      local tmp_win = split_win(win_node.win, { after = false, vertical = true })
      move_node(parent_node.children[win_node.idx - 1], tmp_win, {
        after = false,
        vertical = false,
        ignore = win_node.win,
      })
      v.nvim_win_close(win_node.win, true)
      v.nvim_set_current_win(tmp_win)
    end
  else
    local tmp_win = split_win(win_node.win, { after = true, vertical = true })
    move_node(parent_node, tmp_win, {
      after = false,
      vertical = false,
      ignore = win_node.win,
    })
    v.nvim_win_close(tmp_win, true)
    v.nvim_set_current_win(win_node.win)
  end
end

function tile.shift_right()
  local win_node = node.find_win(v.nvim_get_current_win(), node.build())
  local parent_node = win_node.parent()

  if parent_node.type == "row" then
    if win_node.idx == 1 and #parent_node.children == 2 and parent_node.children[2].type == "leaf" then
      split_move_win(win_node.win, parent_node.children[2].win, { after = true, vertical = true })
    elseif win_node.idx == win_node.last_idx then
      local tmp_win = split_win(win_node.win, { after = false, vertical = true })
      local grandparent = parent_node.parent()
      move_node(grandparent, tmp_win, {
        after = false,
        vertical = false,
        ignore = win_node.win,
      })
      v.nvim_win_close(tmp_win, true)
      v.nvim_set_current_win(win_node.win)
    else
      local tmp_win = split_win(win_node.win, { after = true, vertical = true })
      move_node(parent_node.children[win_node.idx + 1], tmp_win, {
        after = true,
        vertical = false,
        ignore = win_node.win,
      })
      v.nvim_win_close(win_node.win, true)
      v.nvim_set_current_win(tmp_win)
    end
  else
    local tmp_win = split_win(win_node.win, { after = false, vertical = true })
    move_node(parent_node, tmp_win, {
      after = false,
      vertical = false,
      ignore = win_node.win,
    })
    v.nvim_win_close(tmp_win, true)
    v.nvim_set_current_win(win_node.win)
  end
end

function tile.shift_up()
  local win_node = node.find_win(v.nvim_get_current_win(), node.build())
  local parent_node = win_node.parent()

  if parent_node.type == "col" then
    if win_node.idx == win_node.last_idx and #parent_node.children == 2 and parent_node.children[1].type == "leaf" then
      split_move_win(win_node.win, parent_node.children[1].win, { after = false, vertical = false })
    elseif win_node.idx == 1 then
      local tmp_win = split_win(win_node.win, { after = true, vertical = false })
      local grandparent = parent_node.parent()
      move_node(grandparent, tmp_win, {
        after = false,
        vertical = true,
        ignore = win_node.win,
      })
      v.nvim_win_close(tmp_win, true)
      v.nvim_set_current_win(win_node.win)
    else
      local tmp_win = split_win(win_node.win, { after = false, vertical = false })
      move_node(parent_node.children[win_node.idx - 1], tmp_win, {
        after = false,
        vertical = true,
        ignore = win_node.win,
      })
      v.nvim_win_close(win_node.win, true)
      v.nvim_set_current_win(tmp_win)
    end
  else
    local tmp_win = split_win(win_node.win, { after = true, vertical = false })
    move_node(parent_node, tmp_win, {
      after = false,
      vertical = true,
      ignore = win_node.win,
    })
    v.nvim_win_close(tmp_win, true)
    v.nvim_set_current_win(win_node.win)
  end
end

function tile.shift_down()
  local win_node = node.find_win(v.nvim_get_current_win(), node.build())
  local parent_node = win_node.parent()

  if parent_node.type == "col" then
    if win_node.idx == 1 and #parent_node.children == 2 and parent_node.children[2].type == "leaf" then
      split_move_win(win_node.win, parent_node.children[2].win, { after = true, vertical = false })
    elseif win_node.idx == win_node.last_idx then
      local tmp_win = split_win(win_node.win, { after = false, vertical = false })
      local grandparent = parent_node.parent()
      move_node(grandparent, tmp_win, {
        after = false,
        vertical = true,
        ignore = win_node.win,
      })
      v.nvim_win_close(tmp_win, true)
      v.nvim_set_current_win(win_node.win)
    else
      local tmp_win = split_win(win_node.win, { after = true, vertical = false })
      move_node(parent_node.children[win_node.idx + 1], tmp_win, {
        after = true,
        vertical = true,
        ignore = win_node.win,
      })
      v.nvim_win_close(win_node.win, true)
      v.nvim_set_current_win(tmp_win)
    end
  else
    local tmp_win = split_win(win_node.win, { after = false, vertical = false })
    move_node(parent_node, tmp_win, {
      after = false,
      vertical = true,
      ignore = win_node.win,
    })
    v.nvim_win_close(tmp_win, true)
    v.nvim_set_current_win(win_node.win)
  end
end

function tile.setup(opts)
  tile.opts = vim.tbl_deep_extend("force", tile.opts, opts)
end

return tile
