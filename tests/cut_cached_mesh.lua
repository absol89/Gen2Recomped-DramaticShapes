-- Run with LOVE's data module; graphics uploads are recorded rather than drawn.
package.preload["src.render.Assets"] = function() return {register=function() end} end
local uploads = {}
love.graphics = { newMesh = function(_, count)
  local mesh = {count=count, released=false}
  function mesh:setVertices(data, first)
    uploads[#uploads+1] = {mesh=self, first=first, bytes=data:getString()}
  end
  function mesh:release() self.released=true end
  return mesh
end }
local function record()
  -- Ground, changed prop, and an adjacent unchanged prop, six vertices each.
  return {n=18, chunks={string.rep("x",18*24)}, spans={6,6,8,8,12,6,24,8}}
end
local disk={available=function() return true end,
  loadAux=function() return {grass=record(),flowers=record(),figures={}} end,
  loadTerrain=function() return {terrain=record(),water={n=0},spans=record().spans} end}
local modules={VoxelMeshDisk=disk, Voxel3D={FORMAT={}},
  Structures={invalidate=function() end},
  BuildBudget={begin=function() end,finish=function() end,check=function() end}}
local M=assert(loadfile('lib/ChunkMesher.lua'))({require=function(n) return modules[n] or {} end})
local before,after={},{}
for i=1,16 do before[i],after[i]=1,1 end
after[1]=2
local map={id='ROUTE_30',tileset={blocks={before,after}},blockAt=function() return 1 end}
local neighbor={id='ROUTE_31'}
for _,m in ipairs({map,neighbor}) do
  M.request(m,false,nil,true)
  M.request(m,true,nil,true)
end
while M.pending()>0 do M.pump(true) end
local full,body,grass,flowers=M.peek(map),M.peek(map,true),M.grass(map),M.flowers(map)
local nb=M.peek(neighbor)
assert(full and body and grass and flowers and nb,'cached records failed to upload')
uploads={}
M.refresh(map.id,0,0,map,0)
assert(#uploads==4,'full/body/grass/flowers must all drop only the changed prop')
for _,u in ipairs(uploads) do
  assert(u.first==7 and u.bytes==string.rep(string.char(0),6*24),
    'ground or neighboring prop included in cached Cut upload')
end
assert(M.peek(map)==full and M.peek(map,true)==body and not full.released,
  'Cut discarded the drawable cached terrain')
assert(M.peek(neighbor)==nb and not nb.released,'Cut discarded a neighboring map')
assert(M.request(map,false,nil,true)==full and M.pending()==1,
  'stale terrain must remain drawable while replacement is queued')
print('cached full/body/grass/flower Cut upload and neighbor retention: ok')
