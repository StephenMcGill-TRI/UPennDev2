Camera = require "OPCam"

Camera.get_image();
Camera.stream_off();
Camera.stop();
print(Camera.get_width())
print(Camera.get_height())
