-- Run from mod root with DS_ENGINE_ROOT set. DS_BORDER_SOURCE optionally
-- selects an unpatched host BorderFill.lua for compatibility regression.
local engine = assert(os.getenv("DS_ENGINE_ROOT"), "Set DS_ENGINE_ROOT")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
local Border = assert(loadfile(os.getenv("DS_BORDER_SOURCE")
  or engine .. "/src/world/gen2/BorderFill.lua"))()
package.loaded["src.world.gen2.BorderFill"] = Border
local Guard = assert(loadfile("lib/Gen2BorderGuard.lua"))({generation=function()return 2 end})
local draws, alpha = {}, 1
love = {graphics={
  newQuad=function()return {setViewport=function()end} end,
  setColor=function(_,_,_,a) alpha=a end,
  draw=function(image)
    assert(not image.released, "Cannot use object after it has been released")
    draws[#draws+1]={image,alpha}
  end,
}}
local function image()
  return {getDimensions=function(self)
    assert(not self.released, "Cannot use object after it has been released")
    return 32,32
  end}
end
local function draw(owner,img,key)
  return Border.draw(owner,img,0,0,160,144,1,key)
end
assert(Guard.install())
local installed=Border.draw
assert(Guard.install() and Border.draw==installed, "must not stack wrappers")
for _,duringFade in ipairs({false,true}) do
  local owner,a,b,c={},image(),image(),image()
  assert(draw(owner,a,"A"))
  if duringFade then
    assert(draw(owner,b,"B"))
    assert(draws[#draws][2]<1, "valid transitions must still fade")
  end
  a.released=true
  draws={}
  assert(draw(owner,b,"B"))
  assert(#draws==1 and draws[1][1]==b and draws[1][2]==1)
  b.released=true
  draws={}
  assert(not draw(owner,b,"B") and #draws==0)
  assert(owner.borderLast==nil and owner.borderFrom==nil)
  assert(draw(owner,c,"C"))
end
-- Genuine renderer errors must remain visible, not be swallowed by the guard.
love.graphics.draw=function()error("unrelated renderer failure")end
local ok,err=pcall(draw,{},image(),"A")
assert(not ok and tostring(err):find("unrelated renderer failure",1,true))
local other = assert(loadfile("lib/Gen2BorderGuard.lua"))({generation=function()return 1 end})
assert(not other.install())
package.loaded["src.world.gen2.BorderFill"]={}
assert(not Guard.install(), "unavailable host seam must be optional")
print("PASS Gen2 released border guard: current/outgoing, fade, recovery, errors, optional host, idempotence")
