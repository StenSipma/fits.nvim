fun! Setup()
        lua for k in pairs(package.loaded) do if k:match("^fits") or k:match("^menu") then package.loaded[k] = nil end end
endfunction

command -complete=file -nargs=1 FitsInspect :lua require('fits').inspect_fits('<args>')
call Setup()
