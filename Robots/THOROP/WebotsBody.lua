local WebotsBody = {}
local ptable = require'util'.ptable
local ww, cw, mw, sw, fw, rw, kb

function WebotsBody.entry()
	
	ww = Config.wizards.world and require(Config.wizards.world)
	cw = Config.wizards.camera and require(Config.wizards.camera)
	mw = Config.wizards.mesh and require(Config.wizards.mesh)
	kw = Config.wizards.kinect and require(Config.wizards.kinect)
	sw = Config.wizards.slam and require(Config.wizards.slam)
	fw = Config.wizards.feedback and require(Config.wizards.feedback)
	rw = Config.wizards.remote and require(Config.wizards.remote)
	kb = Config.testfile and require(Config.testfile)

	WebotsBody.USING_KB = type(kb)=='table' and type(kb.update)=='function'
	
	if ww then ww.entry() end
  if fw then fw.entry() end
  if rw then rw.entry() end
end

function WebotsBody.update_head_camera(img, sz, cnt, t)
	if cw then cw.update(img, sz, cnt, t) end
end

function WebotsBody.update_head_lidar(metadata, ranges)
  if sw then sw.update(metadata, ranges) end
end

function WebotsBody.update_chest_lidar(metadata, ranges)
	if mw then mw.update(metadata, ranges) end
end

function WebotsBody.update_chest_kinect(metadata, rgb, depth)
	depth.bpp = ffi.sizeof('float')
	depth.data = ffi.string(depth.data, depth.width*depth.height*depth.bpp)
	if kw then kw.update(metadata, rgb, depth) end
end

function WebotsBody.update(keycode)
	if ww then ww.update() end
  if fw then fw.update() end
  if rw then rw.update() end

	if WebotsBody.USING_KB then kb.update(keycode) end
	-- Add logging capability
end

function WebotsBody.exit()
	if ww then ww.exit() end
end

return WebotsBody
