local MAX = 10000
local M = {}

local v = vim.api

local function get_node_spec(current_node)
  if current_node.type == "leaf" then
    local width = v.nvim_win_get_width(current_node.win)
    local height = v.nvim_win_get_height(current_node.win)
    local row_col = v.nvim_win_get_position(current_node.win)

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
  else
    local row = MAX
    local col = MAX
    local row_end = -MAX
    local col_end = -MAX

    for _, child_node in pairs(current_node.children) do
      row = math.min(row, child_node.spec.row)
      col = math.min(col, child_node.spec.col)
      row_end = math.max(row_end, child_node.spec.row_end)
      col_end = math.max(col_end, child_node.spec.col_end)
    end

    local height = row_end - row
    local width = col_end - col

    local row_space
    local col_space

    if current_node.type == "row" then
      for _, child_node in pairs(current_node.children) do
        col_space = math.min(col_space or MAX, child_node.spec.col_space)
        row_space = (row_space or 0) + child_node.spec.row_space
      end
    end

    if current_node.type == "col" then
      for _, child_node in pairs(current_node.children) do
        row_space = math.min(row_space or MAX, child_node.spec.row_space)
        col_space = (col_space or 0) + child_node.spec.col_space
      end
    end

    return {
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

function M.build(vim_node)
  vim_node = vim_node or vim.fn.winlayout()

  local node = {
    type = vim_node[1],
    idx = 1,
    last_idx = 1,
    parent = function() end,
    spec = nil,
  }

  if vim_node[1] == "leaf" then
    node.win = vim_node[2]
    node.spec = get_node_spec(node)
  else
    node.children = {}
    for idx, child_node in ipairs(vim_node[2]) do
      local new_node = M.build(child_node)
      new_node.idx = idx
      new_node.last_idx = #vim_node[2]
      new_node.parent = function()
        return node
      end
      node.children[idx] = new_node
      node.spec = get_node_spec(node)
    end
  end

  return node
end

function M.find_win(win, node)
  if node.type == "leaf" then
    if node.win == win then
      return node
    end
  else
    for _, child_node in pairs(node.children) do
      local found_node = M.find_win(win, child_node)
      if found_node then
        return found_node
      end
    end
  end
end

return M
