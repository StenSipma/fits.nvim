-- Choice menu playground
local function open(position)
        -- TODO (2021-01-30): If buffer already exists make a new one? Or overwrite current
        if not position then
                position = 'botright'
        end
        vim.cmd(position .. ' vnew')

        local win = vim.api.nvim_get_current_win()
        local buf = vim.api.nvim_get_current_buf()

        vim.api.nvim_buf_set_name(buf, "Preview Buf")

        vim.api.nvim_buf_set_option(0, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(0, 'swapfile', false)
        vim.api.nvim_buf_set_option(0, 'filetype', 'nvim-picker')
        vim.api.nvim_buf_set_option(0, 'bufhidden', 'wipe')


        vim.wo.wrap = false
        vim.wo.cursorline = true
        return {buf, win}
end

local function set_content(lines, actions, buf, win)
        if not buf then
                buf = vim.api.nvim_get_current_buf()
        end
        if not win then
                win = vim.api.nvim_get_current_win()
        end

        -- Make global for them to be accessible for action functions
        Lines = lines
        Mapper = actions
        -- for i,v in pairs(choices) do
        --         Mapper[#Lines+1] = v
        --         Lines[#Lines+1] = i
        -- end

        vim.api.nvim_buf_set_option(buf, 'modifiable', true)

        vim.api.nvim_buf_set_lines(buf, 0, -1, true, Lines)

        vim.api.nvim_buf_set_option(buf, 'modifiable', false)
end

-- Just a function that does nothing
local function do_nothing() end

local function do_action()
        -- line index
        local idx = vim.api.nvim_win_get_cursor(0)[1]

        if idx <= #Mapper then
                local choice = Mapper[idx]
                -- Execute function if it is one, otherwise just print it
                if vim.is_callable(choice) then
                        choice()
                else
                        print('Choice ', choice)
                end
        end
end

-- Mapped action function
local function close_window()
        vim.api.nvim_win_close(0, true)
end

local function set_mapping()
        local opts = {noremap=true, nowait=true}
        local keymaps = {
                q = "close_window()",
                ["<cr>"] = 'do_action()',
        }

        for k,v in pairs(keymaps) do
                vim.api.nvim_buf_set_keymap(0, "n", k, ":lua require'menu'."..v.."<cr>", opts)
        end
end

local function picker(lines, actions)
        -- Open the new window
        local buf, win = open()

        -- Set the content of the buffer
        set_content(lines, actions, buf, win)

        -- Set mappings according to the current row/line
        -- Idea: to avoid the global mapper variable, limiting to only one
        -- mapping table, we have multiple mappers, which are indexed with a
        -- number. This number is passed to the do_action function
        set_mapping()
end

return {
        picker = picker,
        do_action = do_action,
        do_nothing = do_nothing,
        close_window = close_window,
}
