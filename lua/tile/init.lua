local MAX = 10000
local ROW = "row"
local COL = "col"
local LEAF = "leaf"
local v = vim.api
local tile = {}
tile.__index = tile
tile.opts = {
  horizontal = 4,
  vertical = 2,
  min_width = 1,
  min_height = 1,
}

local function leaf(win)
  return { LEAF, win }
end

local function clamp(value, max)
  if value < max then
    return value
  else
    return max
  end
end

local function get_pos(leaf_node, root_node)
  root_node = root_node or vim.fn.winlayout()
  leaf_node = leaf_node or leaf(v.nvim_get_current_win())

  if root_node[1] ~= LEAF then
    for idx, child_node in ipairs(root_node[2]) do
      if vim.deep_equal(child_node, leaf_node) then
        return { kind = root_node[1], idx = idx, last_idx = #root_node[2], parent = root_node }
      else
        local pos = get_pos(leaf_node, child_node)
        if pos then
          return pos
        end
      end
    end
  end
end

local function get_win_spec(win_id)
  local width = v.nvim_win_get_width(win_id)
  local height = v.nvim_win_get_height(win_id)
  local row_col = v.nvim_win_get_position(win_id)

  return {
    row = row_col[1],
    col = row_col[2],
    height = height,
    width = width,
    row_end = row_col[1] + height,
    col_end = row_col[2] + width,
    row_space = math.max(0, width - 1),
    col_space = math.max(0, height - 1),
  }
end

local function get_node_spec(node)
  if node[1] == LEAF then
    return get_win_spec(node[2])
  else
    local row = MAX
    local col = MAX
    local row_end = -MAX
    local col_end = -MAX

    for _, value in pairs(node[2]) do
      local sibling_spec = get_node_spec(value)
      row = math.min(row, sibling_spec.row)
      col = math.min(col, sibling_spec.col)
      row_end = math.max(row_end, sibling_spec.row_end)
      col_end = math.max(col_end, sibling_spec.col_end)
    end

    local height = row_end - row
    local width = col_end - col

    local row_space
    local col_space

    if node[1] == ROW then
      for _, value in pairs(node[2]) do
        local sibling_spec = get_node_spec(value)

        col_space = math.min(col_space or MAX, sibling_spec.col_space)
        row_space = (row_space or 0) + sibling_spec.row_space
      end
    end

    if node[1] == COL then
      for _, value in pairs(node[2]) do
        local sibling_spec = get_node_spec(value)

        row_space = math.min(row_space or MAX, sibling_spec.row_space)
        col_space = (col_space or 0) + sibling_spec.col_space
      end
    end

    return {
      kind = node[1],
      row = row,
      col = col,
      height = height,
      width = width,
      row_end = row_end,
      col_end = col_end,
      row_space = row_space,
      col_space = col_space,
    }
  end
end

local resize_left
local resize_right
local resize_down
local resize_up

resize_left = function(win_ids, win_id, current_node)
  local pos = get_pos(current_node or leaf(win_id))
  local win_spec = get_win_spec(win_id)

  if not pos then
    return
  end

  if pos.kind == ROW then
    if pos.idx == pos.last_idx then
      for idx = pos.idx - 1, 1, -1 do
        local sibling_spec = get_node_spec(pos.parent[2][idx])

        if sibling_spec.row_space > 0 then
          return v.nvim_win_set_width(0, win_spec.width + clamp(tile.opts.horizontal, sibling_spec.row_space))
        end
      end
    else
      v.nvim_win_set_width(0, win_spec.width - tile.opts.horizontal)
    end
  else
    resize_left(win_ids, win_id, pos.parent)
  end
end

resize_right = function(win_ids, win_id, node)
  local pos = get_pos(node or leaf(win_id))
  local win_spec = get_win_spec(win_id)

  if not pos then
    return
  end

  if pos.kind == ROW then
    if pos.idx == pos.last_idx then
      v.nvim_win_set_width(0, win_spec.width - tile.opts.horizontal)
    else
      for idx = pos.idx + 1, pos.last_idx, 1 do
        local sibling_spec = get_node_spec(pos.parent[2][idx])

        if sibling_spec.row_space > 0 then
          return v.nvim_win_set_width(0, win_spec.width + clamp(tile.opts.horizontal, sibling_spec.row_space))
        end
      end
    end
  else
    resize_right(win_ids, win_id, pos.parent)
  end
end

resize_up = function(win_ids, win_id, node)
  local pos = get_pos(node or leaf(win_id))
  local win_spec = get_win_spec(win_id)

  if not pos then
    return
  end

  if pos.kind == COL then
    if pos.idx == pos.last_idx then
      for idx = pos.idx - 1, 1, -1 do
        local sibling_spec = get_node_spec(pos.parent[2][idx])

        if sibling_spec.col_space > 0 then
          return v.nvim_win_set_height(0, win_spec.height + clamp(tile.opts.vertical, sibling_spec.col_space))
        end
      end
    else
      v.nvim_win_set_height(0, win_spec.height - tile.opts.vertical)
    end
  else
    resize_up(win_ids, win_id, pos.parent)
  end
end

resize_down = function(win_ids, win_id, node)
  local pos = get_pos(node or leaf(win_id))
  local win_spec = get_win_spec(win_id)

  if not pos then
    return
  end

  if pos.kind == COL then
    if pos.idx == pos.last_idx then
      v.nvim_win_set_height(0, win_spec.height - tile.opts.vertical)
    else
      for idx = pos.idx + 1, pos.last_idx, 1 do
        local sibling_spec = get_node_spec(pos.parent[2][idx])

        if sibling_spec.col_space > 0 then
          return v.nvim_win_set_height(0, win_spec.height + clamp(tile.opts.vertical, sibling_spec.col_space))
        end
      end
    end
  else
    resize_down(win_ids, win_id, pos.parent)
  end
end

function tile.resize_left()
  resize_left(v.nvim_list_wins(), v.nvim_get_current_win())
end

function tile.resize_right()
  resize_right(v.nvim_list_wins(), v.nvim_get_current_win())
end

function tile.resize_up()
  resize_up(v.nvim_list_wins(), v.nvim_get_current_win())
end

function tile.resize_down()
  resize_down(v.nvim_list_wins(), v.nvim_get_current_win())
end

function tile.setup(opts)
  tile.opts = vim.tbl_deep_extend("force", tile.opts, opts)
end

return tile
