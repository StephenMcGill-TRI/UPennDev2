local jpeg = require'jpeg'
w = 320
h = 240
w = 128
h = 128
ch = 3;
nbytes = w*h*ch;
if webots then
  ch = 4;--bgra for webots
end
print('Filling a '..w..' by '..h..' image',ch..' channels.')

--if using_luajit then
--  ffi = require 'ffi'
--  img = ffi.new('uint8_t[?]', w*h*ch, 0)
--else
  local carray = require 'carray'
  img = carray.byte(w*h*ch)
--end

print()
print()

for k=1,nbytes,ch do
  -- Blue up top
  img[k] = 0;
  img[k+1] = 0;
  img[k+2] = 255;
  -- Green halfway through
  if k>nbytes/2 then
    img[k] = 255;
    img[k+1] = 255;
    img[k+2] = 0;
  end
end

local c_rgb = jpeg.compressor('rgb')
print('compressing', c_rgb)
c_rgb:quality(95)

t0 = os.clock()
local ntimes = 100
for i=1,ntimes do
	img_jpeg = c_rgb:compress( img:pointer(), w, h )
end
t1 = os.clock()
print(ntimes..' compressions average:', (t1-t0)/ntimes );
print(type(img_jpeg),'Compression Ratio:', #img_jpeg, #img_jpeg/nbytes )


f = io.open('img.jpeg','w')
n = f:write( img_jpeg )
f:close()


--img_jpeg_crop = c_rgb:compress_crop( img:pointer(), w, h, 10, 20, 100, 100 )
--[[
img_jpeg_crop = c_rgb:compress_crop( img:pointer(), w, h, w/4, w/4, 3/4*w, 3/4*h )
f = io.open('img_crop.jpeg','w')
n = f:write( img_jpeg_crop )
f:close()
--]]

-- gray
ch = 1;
nbytes = w*h*ch;
print('Filling a '..w..' by '..h..' image',ch..' channels.')

--if using_luajit then
--  ffi = require 'ffi'
--  img = ffi.new('uint8_t[?]', w*h*ch, 0)
--else
  local carray = require 'carray'
  img = carray.byte(w*h*ch)
--end

for k=1,nbytes,ch do
	img[k] = 255*math.random();
end

print()
print()

local c_gray = jpeg.compressor('gray')
print('compressing',c_gray)
c_rgb:quality(95)
local ntimes = 100
t0=unix.time()
for i=1,ntimes do
	img_jpeg = c_gray:compress( img:pointer(), w, h )
end
t1=unix.time()
print(ntimes..' compressions average:', (t1-t0)/ntimes );

print(type(img_jpeg),'Compression Ratio:', #img_jpeg, #img_jpeg/nbytes )

f = io.open('img_gray.jpeg','w')
n = f:write( img_jpeg )
f:close()

print('cropping...')


img_jpeg_crop = c_gray:compress_crop( img:pointer(), w, h, w/4, h/4, 3/4*w, 3/4*h )
f = io.open('img_gray_crop.jpeg','w')
n = f:write( img_jpeg_crop )
f:close()

os.exit()

ff = io.open('img.jpeg','r')
file_str = ff:read('*a')
print(#file_str)
img_2 = jpeg.uncompress(file_str, #file_str)
print(img_2)
print('width  '..img_2:width())
print('height  '..img_2:height())
print('stride  '..img_2:stride())
--print('color type  '..img_2:color_type())
--print('bit depth  '..img_2:bit_depth())
print('data length  '..img_2:__len())
for i = 1, img_2:stride() * img_2:height(), 3 do
print(img_2[i], img_2[i+1],img_2[i+2])
end

print(img_2:pointer())
