module(..., package.seeall)
local vector = require'vector'

cal={}
cal[HOSTNAME] = {}
cal["asus"] = {}
cal["alvin"]={}
cal["teddy"]={}



-- Updated date: Sat Jun 21 20:14:27 2014
cal["asus"].legBias=vector.new({
   2.024974,0.000000,0.000000,0.000000,0.000000,0.000000,
   0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,
   })*math.pi/180

-- Updated date: Sat Sep 20 17:40:14 2014
cal["alvin"].legBias=vector.new({
   1.417500,0.405000,-0.337500,-1.552500,-0.202500,0.810000,
   0.472500,-2.025000,0.405000,-0.810000,-0.202500,-0.202500,
   })*math.pi/180


-- Updated date: Sat Sep 20 17:40:14 2014
cal["teddy"].legBias=vector.new({
   1,0.72,0.02,-0.365,0.32,0.72,
   0.47,-0.69,1.19,-0.88,-0.66,0.03,
   })*math.pi/180


-- Updated date: Tue Sep 23 00:00:50 2014
cal["teddy"].legBias=vector.new({
   1.000000,0.720000,0.020000,-0.365000,0.320000,0.720000,
   0.470000,-0.690000,1.190000,-0.880000,-0.660000,-0.375000,
   })*math.pi/180


-- Updated date: Fri Jan 16 13:20:56 2015
cal["thorop"].legBias=vector.new({
   0.000000,1.890000,0.000000,-1.282500,0.000000,0.000000,
   0.000000,0.000000,0.000000,0.000000,0.000000,0.000000,
   })*math.pi/180
