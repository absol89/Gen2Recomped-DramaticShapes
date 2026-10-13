-- Native GPU fixture; launch tests/gpu_room_sky with DS_MOD_PATH and SHOT_DIR.
return function()
 local shotDir=assert(os.getenv('SHOT_DIR'),'Set SHOT_DIR to an existing writable directory')
 local out=assert(io.open(shotDir..'/gpu.log','w'))
 local ok,err=pcall(function()
  local root=assert(os.getenv('DS_MOD_PATH'),'Set DS_MOD_PATH to this mod checkout')..'/lib/'
  local g=love.graphics
  local M=assert(loadfile(root..'Mat4.lua'))()
  local R=assert(loadfile(root..'RoomBackfaces.lua'))()
  local f=assert(io.open(root..'Voxel3D.lua'));local source=f:read('*a');f:close()
  local shader=g.newShader(assert(source:match('local SHADER = %[%[(.-)%]%]')))
  local data=love.image.newImageData(1,1);data:setPixel(0,0,1,1,1,1)
  local white=g.newImage(data)
  local function send(name,...)
   if shader:hasUniform(name)then shader:send(name,...)end
  end
  for _,name in ipairs({'model','sunModel','sunVP','modelSunVP'})do send(name,'row',M.identity())end
  send('curve',{0,0,0});send('pull',0);send('sunMap',white);send('modelSunMap',white)
  send('sunDark',0);send('modelSunDark',0);send('dayTint',{1,1,1})
  local q={{-1,0,-1},{1,0,-1},{1,0,1},{-1,0,1},oneSided=true}
  local shade=R.shade(q,1);local verts={}
  for _,i in ipairs({1,2,3,1,3,4})do local p=q[i];verts[#verts+1]={p[1],p[2],p[3],.5,.5,shade}end
  local mesh=g.newMesh({{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexShade','float',1}},verts,'triangles','static')
  mesh:setTexture(white)
  for _,inside in ipairs({false,true})do
   local eye={0,inside and -4 or 4,0}
   send('eye',eye)
   send('vp','row',M.mul(M.mul(M.scale(1,-1,1),M.perspective(1,1,.1,20)),M.lookAt(eye,{0,0,0},{0,0,-1})))
   local c=g.newCanvas(64,64,{dpiscale=1})
   g.setCanvas(c);g.clear(1,0,0,1);g.setShader(shader);g.setColor(1,1,1,1);g.setMeshCullMode('none');g.draw(mesh);g.setShader();g.setCanvas()
   local pixels=c:newImageData();local r,green=pixels:getPixel(32,32)
   assert(r>.8 and (inside and green>.8 or not inside and green<.1),'room facing pixel failed')
   local encoded=pixels:encode('png');local shot=assert(io.open(shotDir..'/'..(inside and 'room-inside' or 'room-outside')..'.png','wb'));shot:write(encoded:getString());shot:close()
  end
  out:write('PASS native shader inward/front and discarded/back pixel checks\n');out:flush()
  -- Synthetic palette bypasses engine palette policy; actual sky shader runs.
  package.loaded['src.render.PaletteFX']={}
  local sky=assert(loadfile(root..'Sky.lua'))({require=function()return{}end})
  assert(sky._getShader(),'sky shader compile failed')
  local palette={.7,.7,.7,1,bands={{.05,.1,.4},{.1,.4,.8},{.6,.8,1}}}
  local ray={base={-1,1,-1},du={2,0,0},dv={0,-2,0}}
  local results={}
  for _,flip in ipairs({false,true})do
   local c=g.newCanvas(64,64,{dpiscale=1})
   g.setCanvas(c);g.clear(.7,.7,.7,1);sky.paint(64,64,palette,nil,1,nil,nil,nil,ray,flip);g.setCanvas()
   if flip then
    local resolved=g.newCanvas(64,64,{dpiscale=1});g.setCanvas(resolved);g.clear();g.setColor(1,1,1,1);g.draw(c,0,64,0,1,-1);g.setCanvas();c=resolved
   end
   results[#results+1]=c:newImageData()
  end
  local changed=0
  for y=0,63 do for x=0,63 do
   local a,b,c=results[1]:getPixel(x,y);local d,e,f=results[2]:getPixel(x,y)
   assert(math.max(math.abs(a-d),math.abs(b-e),math.abs(c-f))<.02,'flipped sky elevation mismatch')
   if math.abs(a-.7)>.1 then changed=changed+1 end
  end end
  assert(changed>1000,'sky became flat haze')
  local correctedTop=results[2]:getPixel(32,5)
  local oldFlippedTop=results[1]:getPixel(32,58)
  assert(correctedTop<.3 and oldFlippedTop>.6,
    'fixture must reproduce the old pale-haze top and the corrected blue sky')
  local encoded=results[2]:encode('png');local shot=assert(io.open(shotDir..'/sky-resolved.png','wb'));shot:write(encoded:getString());shot:close()
  out:write('PASS native sky ray pixels agree after Metal-style canvas presentation reversal\n')
 end)
 if not ok then out:write('FAIL '..tostring(err)..'\n')end
 out:close();love.event.quit(ok and 0 or 1)
end
