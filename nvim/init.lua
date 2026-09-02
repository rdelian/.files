-- zig 0.16 fix: wrapper strips `pc-windows` -> `windows`
if vim.fn.has("win32") == 1 then
  vim.env.CC = vim.fn.stdpath("config") .. "/bin/zig-cc.cmd"
  vim.env.CXX = vim.fn.stdpath("config") .. "/bin/zig-cxx.cmd"
else
  vim.env.CC = "zig cc"
  vim.env.CXX = "zig c++"
end

require("config.lazy")
