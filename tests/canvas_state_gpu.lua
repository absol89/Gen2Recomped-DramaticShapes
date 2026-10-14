-- Native LÖVE graphics-state regression; no engine/assets/save profile needed.
local g=love.graphics
local canvas=g.newCanvas(32,32)
local source=g.newCanvas(32,32)
local shader=g.newShader('vec4 effect(vec4 c, Image t, vec2 uv, vec2 sc){return c*Texel(t,uv);}')
local O=assert(loadfile('lib/WorldCanvasOrientation.lua'))({require=function(n)
 if n=='RendererOrientation'then return {metalRenderer=function()return true end}end
 return {new=function(w,h)return true,g.newCanvas(w,h)end}
end})
g.setCanvas(canvas);g.setShader(shader);g.translate(3,5)
g.setColor(.2,.3,.4,.5);g.setScissor(1,2,20,21);g.setBlendMode('add','alphamultiply')
local function check()
 assert(g.getCanvas()==canvas and g.getShader()==shader,'canvas/shader not restored')
 local x,y=g.transformPoint(0,0);assert(x==3 and y==5,'transform not restored')
 local r,b,c,a=g.getColor();assert(math.abs(r-.2)<.001 and math.abs(a-.5)<.001)
 local sx,sy,sw,sh=g.getScissor();assert(sx==1 and sy==2 and sw==20 and sh==21)
 assert(g.getBlendMode()=='add')
end
assert(O.present(source,'world',2)~=source);check()
local draw=g.draw;g.draw=function()error('injected draw failure')end
assert(O.present(source,'world',2)==source);check();g.draw=draw
g.setCanvas();g.setShader();g.origin();g.setScissor();g.setBlendMode('alpha');g.setColor(1,1,1,1)
print('PASS native canvas state on success and failed copy')
