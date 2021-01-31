local menu = require('menu')

local function text_center(str, width)
        if not width then
                width = vim.bo.textwidth
        end

        local space = math.max(width - #str, 0)
        if space == 0 then
                return str
        end

        local pad = " "
        local l = math.floor(space/2)
        local r = math.ceil(space/2)
        return string.rep(pad, l) .. str .. string.rep(pad, r)
end

local function info_to_string(info)
        local hdu_type  = info[4]
        if hdu_type == "BinTableHDU" then
                return string.format("%-15s | (%11s) | Column Types: %s", info[4], info[6], info[7])
        else
                local type_str = ""
                for i,v in ipairs(info[6]) do
                        type_str = type_str .. tostring(v) .. " x "
                end
                type_str = type_str:sub(0, #type_str-3) -- remove last " x "

                return string.format("%-15s | (%11s) | type: %s", info[4], type_str, info[7])
        end
end

local function match_highlight(group, regex, str, line, offset)
        if not offset then
                offset = {0, 0}
        end
        local a, b = regex:match_str(str)
        if a then
                vim.api.nvim_buf_add_highlight(0, -1, group, line-1, a+offset[1], b+offset[2])
        end
end

local type_ident_map = {
        boolean = "Boolean",
        string = "String",
        number = "Number",
}

local function header_highlighting(lines, header)
        local cmt_regex = vim.regex(' / .*$') -- Matches a comment at the end
        for i,v in ipairs(lines) do
                local value_identifier = type_ident_map[type(header[i][2])]
                vim.api.nvim_buf_add_highlight(0, -1, value_identifier, i-1, 10, -1)
                vim.api.nvim_buf_add_highlight(0, -1, 'Identifier', i-1, 0, 8)
                vim.api.nvim_buf_add_highlight(0, -1, 'Comment', i-1, 9, 10)
                match_highlight('Comment', cmt_regex, v, i)
        end
end

local function info_highlighting(lines)
        local type_regex = vim.regex(": .*$")
        vim.api.nvim_buf_add_highlight(0, -1, 'Identifier', 0, 0, -1)
        vim.api.nvim_buf_add_highlight(0, -1, 'Comment', 1, 0, -1)
        for i=3,#lines do
                vim.api.nvim_buf_add_highlight(0, -1, 'Comment', i-1, 0, -1)
                vim.api.nvim_buf_add_highlight(0, -1, 'Identifier', i-1, 0, 16)
                vim.api.nvim_buf_add_highlight(0, -1, 'Number', i-1, 19, 30)
                vim.api.nvim_buf_add_highlight(0, -1, 'String', i-1, 34, -1)
                match_highlight('Type', type_regex, lines[i], i, {1, 0})
        end
end

local function header_settings(bufname, buf)
        if not buf then
                buf = vim.api.nvim_get_current_buf()
        end
        vim.api.nvim_buf_set_name(buf, bufname)

        vim.api.nvim_buf_set_option(0, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(0, 'swapfile', false)
        vim.api.nvim_buf_set_option(0, 'filetype', 'FITS-header')
        vim.api.nvim_buf_set_option(0, 'bufhidden', 'wipe')

        local opts = {noremap=true, nowait=true}
        vim.api.nvim_buf_set_keymap(0, "n", "q", ":lua vim.api.nvim_win_close(0, true)<cr>", opts)

        vim.wo.wrap = false
        vim.wo.cursorline = true

end

local function display_header(filename)
        return function ()
                local line = vim.api.nvim_win_get_cursor(0)[1]
                local header_idx = line - 3
                local header = vim.fn.FITSHeader(filename, header_idx)

                --vim.cmd('enew') -- make new buffer in current window
                vim.cmd('new') -- make new window in a split
                local buf = vim.api.nvim_get_current_buf()
                local lines = {}
                for i,v in ipairs(header) do
                        local to_append = ""
                        if #v[3] > 0 then
                                to_append = " / " .. v[3]
                        end
                        lines[#lines+1] = string.format("%-8s | %-40s", v[1], v[2]) .. to_append
                end
                vim.api.nvim_buf_set_lines(buf, 0, -1, true, lines)
                header_settings("Header "..tostring(header_idx).." "..filename, buf)
                header_highlighting(lines, header)
        end
end

local function inspect_fits(filename)
        local info = vim.fn.FITSInfo(filename)

        -- The first time this funcion is executed, it is Nil ?
        if info == vim.NIL then
                info = vim.fn.FITSInfo(filename)
        end

        local lines = {}
        local mlines = {}
        local path_list = vim.split(filename, '/')

        local width = vim.bo.textwidth
        if width == 0 then
                width = 80
        end

        lines[1] = text_center(path_list[#path_list], width)
        lines[2] = string.rep("-", width)
        mlines[1] = menu.do_nothing
        mlines[2] = menu.do_nothing

        local offset = 2
        for i,v in pairs(info) do
                lines[i+offset] = info_to_string(v)
                mlines[i+offset] = display_header(filename)
        end


        menu.picker(lines, mlines)
        info_highlighting(lines)
end

return {
        inspect_fits = inspect_fits,
        display_header = display_header,
}
