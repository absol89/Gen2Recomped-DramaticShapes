-- The Crystal PlayersHouse kitchen, identified from complete native tile
-- grids. These are a cooker, sink and refrigerator, not generic bookcases.
local V=...
local G=V.require('Gen2ArchitectureVisuals')
local M={MAX_QUADS=1200}
local floor,min=math.floor,math.min
local patterns={
  {kind='cooker',rows={{0x50,0x51},{0x52,0x53}},height=8},
  {kind='sink',rows={{0x43,0x45},{0x18,0x19}},height=8},
  {kind='refrigerator',rows={{0x0A,0x0B},{0x1A,0x1B},{0x2A,0x2B}},height=22},
  {kind='television',rows={{0x06,0x07},{0x16,0x17},{0x08,0x09}},height=22,
    classes={{wall=true},{console=true},{console=true}}},
  {kind='drawers',rows={{0x0E,0x0F},{0x3A,0x3B}},height=8,
    classes={{wall=true,bookcase=true},{wall=true,bookcase=true}}},
}
local function key(x,z)return(z+64)*4096+x+64 end
local function buildModel(p,x,z,data,perRow,w,h)
  local out={};local box=G.geometryWriter(out,512)
  local xx,zz=x*8,(z+#p.rows)*8
  local back,front=zz-14,zz
  local function sample(sx,sy)
    local t=p.rows[floor(sy/8)+1][floor(sx/8)+1]
    return G.texelUV((t%perRow)*8+sx%8,floor(t/perRow)*8+sy%8,w,h)
  end
  local metal=sample(p.kind=='refrigerator' and 3 or 1,p.kind=='refrigerator' and 8 or 1)
  local edge=sample(p.kind=='refrigerator' and 1 or 0,p.kind=='refrigerator' and 6 or 0)
  if p.kind=='television'and data.getPixel then
    -- Pick a visible native mid-tone for the casing returns. The old corner
    -- sample was the screen's near-black outline, so every side read as a
    -- featureless black slab even though the front model was correct.
    local best,bestScore
    for sy=0,15 do for sx=0,15 do local t=p.rows[floor(sy/8)+1][floor(sx/8)+1]
      local ax,ay=(t%perRow)*8+sx%8,floor(t/perRow)*8+sy%8
      local r,g,b,a=data:getPixel(ax,ay);local hi,lo=math.max(r,g,b),math.min(r,g,b);local light=(r+g+b)/3
      if a>.99 and light>.16 and light<.62 then local score=math.abs(light-.34)+(hi-lo)*.2
        if not bestScore or score<bestScore then best,bestScore={ax,ay},score end
      end
    end end
    if best then metal=G.texelUV(best[1],best[2],w,h)end
  end
  local function q(a,b,c,d,tex,shade)
    out[#out+1]={a,b,c,d,uv=tex,shade=shade,own=true}
  end
  -- Map cropped source pixels to a front or horizontal plane. Split at
  -- source tile boundaries and physical8px spans; no full-object stretching.
  local function art(sx0,sy0,sx1,sy1,axis,plane,xo,yo,xscale,yscale)
    local sy=sy0
    while sy<sy1 do
      local ey=min(sy1,(floor(sy/8)+1)*8,sy+8/yscale)
      local sx=sx0
      while sx<sx1 do
        local ex=min(sx1,(floor(sx/8)+1)*8,sx+8/xscale)
        local t=p.rows[floor(sy/8)+1][floor(sx/8)+1]
        local ax,ay=(t%perRow)*8,floor(t/perRow)*8
        local u0,u1=(ax+sx%8+.025)/w,(ax+ex-floor(sx/8)*8-.025)/w
        local v0,v1=(ay+sy%8+.025)/h,(ay+ey-floor(sy/8)*8-.025)/h
        local a,b=xo+(sx-sx0)*xscale,xo+(ex-sx0)*xscale
        if axis=='front' then
          local top,bot=yo-(sy-sy0)*yscale,yo-(ey-sy0)*yscale
          q({a,bot,plane},{b,bot,plane},{b,top,plane},{a,top,plane},
            {{u0,v1},{u1,v1},{u1,v0},{u0,v0}},1)
        else
          local n,s=yo+(sy-sy0)*yscale,yo+(ey-sy0)*yscale
          q({a,plane,n},{b,plane,n},{b,plane,s},{a,plane,s},
            {{u0,v0},{u1,v0},{u1,v1},{u0,v1}},.97)
        end
        sx=ex
      end
      sy=ey
    end
  end
  if p.kind=='refrigerator' then
    -- Source rows2..21 are the two door faces. The original drawing's
    -- white floor strip at x0 is excluded from the refrigerator body.
    local case=sample(3,2) -- native mid-gray enamel; doors retain white art
    local seam=sample(3,6)
    box(xx+1,1,back,xx+16,22,front-1,case)
    -- Two separate raised door leaves; the narrow reveal stays visible at
    -- oblique angles instead of becoming a single featureless wall slab.
    box(xx+1.4,2,front-1.1,xx+15.6,13.6,front-.15,metal)
    box(xx+1.4,14.1,front-1.1,xx+15.6,21.7,front-.15,metal)
    art(2,7,15,12,'front',front-.125,xx+2,21,1,1.2)
    art(2,14,15,22,'front',front-.125,xx+2,13,1,1.25)
    box(xx+1.4,13.6,front-.8,xx+15.6,14.1,front-.14,seam)
    -- Finished inset side panels, door-return seams and low ventilation
    -- slots on both sides. No geometry or wall plane behind it is moved.
    for _,sx in ipairs({xx+.96,xx+16})do
      box(sx,2.5,back+1,sx+.04,20.8,front-2,case)
      box(sx,2.5,front-1.6,sx+.08,21.2,front-1.25,edge)
      box(sx,13.6,back+1,sx+.08,14.1,front-.2,edge)
      for y=3,5 do box(sx, y,front-6,sx+.08,y+.18,front-2.5,edge)end
    end
    box(xx+1,21.7,back,xx+16,22.5,front-.2,case)
    for _,y in ipairs({8.5,17})do
      box(xx+3,y,front-.2,xx+4,y+2.8,front+.8,edge)
      box(xx+3.15,y+.25,front+.8,xx+3.85,y+2.55,front+.9,case)
    end
    box(xx+2,1.1,front-1,xx+15,1.8,front-.1,edge)
    for _,x0 in ipairs({2,13})do for _,zz0 in ipairs({back+1,front-3})do
      box(xx+x0,0,zz0,xx+x0+2,1.2,zz0+2,edge)
    end end
  elseif p.kind=='television' then
    -- The source's lower eight rows are the AV stand, not more TV screen.
    -- The upper cap was previously left classified as WALL, creating the
    -- 32px wooden tower above a second console model of the lower rows.
    box(xx,0,back,xx+16,8,front-.3,metal)
    art(0,16,16,24,'front',front-.275,xx,8,1,1)
    box(xx,8,back+3,xx+16,22,front-1,metal)
    art(0,2,16,16,'front',front-.975,xx,22,1,1)
    art(0,0,16,2,'top',22.025,xx,back+3,1,10/2)
    box(xx+1,7.7,back,xx+15,8.2,front,edge)
  elseif p.kind=='drawers' then
    box(xx,0,back,xx+16,8,front-.3,metal)
    art(0,8,16,16,'front',front-.275,xx,8,1,1)
    art(0,0,16,8,'top',8.025,xx,back,1,14/8)
    for _,y in ipairs({1,5})do box(xx+7,y-.25,front-.1,xx+9,y+.25,front+.35,edge)end
  elseif p.kind=='cooker' then
    box(xx,0,back,xx+16,8,front-.3,metal)
    art(0,8,16,16,'front',front-.275,xx,8,1,1)
    art(0,0,16,8,'top',8.025,xx,back,1,14/8)
    box(xx+3,5.5,front-.1,xx+13,6.1,front+.3,edge)
    -- Two low raised burner rings, rather than two vertical sprite pillars.
    for _,cx in ipairs({4.5,11.5})do
      local cy=back+5
      for i=0,7 do
        local a,b=i*math.pi/4,(i+1)*math.pi/4
        local x0,z0=xx+cx+1.8*math.cos(a),cy+1.8*math.sin(a)
        local x1,z1=xx+cx+1.8*math.cos(b),cy+1.8*math.sin(b)
        q({x0,8.05,z0},{x1,8.05,z1},{x1,8.35,z1},{x0,8.35,z0},edge,.75)
        q({xx+cx,8.35,cy},{x0,8.35,z0},{x1,8.35,z1},{xx+cx,8.35,cy},edge,.95)
      end
    end
  else
    -- A real recessed basin: the surface quads stop at its opening and
    -- the basin floor sits two voxels below the counter's top.
    box(xx,0,back,xx+16,6,front-.3,metal)
    box(xx,6,back,xx+3,8,front,metal)
    box(xx+13,6,back,xx+16,8,front,metal)
    box(xx+3,6,back,xx+13,8,back+3,metal)
    box(xx+3,6,front-3,xx+13,8,front,metal)
    local scale=14/8;local north=3/scale;local south=11/scale
    art(0,0,16,north,'top',8.025,xx,back,1,scale)
    art(0,south,16,8,'top',8.025,xx,front-3,1,scale)
    art(0,north,3,south,'top',8.025,xx,back+3,1,scale)
    art(13,north,16,south,'top',8.025,xx+13,back+3,1,scale)
    art(0,8,16,16,'front',front+.025,xx,8,1,1)
    box(xx+7.5,8,back+2,xx+8.4,10.2,back+2.9,metal)
    box(xx+7.5,9.5,back+2,xx+8.4,10.2,back+5,metal)
  end
  return out
end

function M.build(S,map,data,perRow)
  if S.outdoor or S.homeFixtures or not data or not map.tileset
      or map.tileset.id~='TilesetPlayersHouse' then return 0 end
  perRow=perRow or 16
  local w,h=data:getDimensions();local added=0;local counts={}
  -- Only the verified wood-panel tile, and only cells already resolved as
  -- upright walls. This is the profile's16px wall height, pinned so the
  -- automatic volume detector cannot borrow a nearby TV/cabinet's height.
  -- The tile IDs, logical map cells and any window art remain unchanged.
  local wallPanels=0
  for z=0,map.def.height*4-1 do for x=0,map.def.width*4-1 do
    local k=key(x,z);local s=S.shapeAt[k]
    if S.tileAt[k]==0x11 and not S.skip[k] and s and s.class=='wall'
        and s.art=='upright' and not s.flat then
      local fixed={};for name,value in pairs(s)do fixed[name]=value end
      fixed.h=16;fixed.authored=true;S.shapeAt[k]=fixed
      wallPanels=wallPanels+1
    end
  end end
  for _,p in ipairs(patterns)do
    for z=0,map.def.height*4-#p.rows do for x=0,map.def.width*4-2 do
      local cells={};local matches=true
      for r,row in ipairs(p.rows)do for c,t in ipairs(row)do
        local k=key(x+c-1,z+r-1);local s=S.shapeAt[k]
        local allowed=p.classes and p.classes[r] or {bookcase=true}
        if S.skip[k] or S.tileAt[k]~=t or not s or not allowed[s.class]
            or floor(t/perRow)*8+8>h then matches=false end
        cells[#cells+1]=k
      end end
      if matches then
        local out=buildModel(p,x,z,data,perRow,w,h)
        if added+#out<=M.MAX_QUADS then
          local shape={class='building',art='building',h=p.height,authored=true,flat=false}
          for _,k in ipairs(cells)do S.shapeAt[k]=shape;S.skip[k]=true;S.ground[k]=false end
          for _,q in ipairs(out)do S.objectQuads[#S.objectQuads+1]=q end
          added=added+#out;counts[p.kind]=(counts[p.kind] or 0)+1
        end
      end
    end end
  end
  S.homeFixtures={quads=added,counts=counts,wallPanels=wallPanels}
  return added
end
return M
