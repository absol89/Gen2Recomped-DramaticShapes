function love.load()
  local root=assert(os.getenv('DS_MOD_PATH'),'Set DS_MOD_PATH to the mod checkout')
  assert(loadfile(root..'/tests/room_sky_gpu.lua'))()()
end
