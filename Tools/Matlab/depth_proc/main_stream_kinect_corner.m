clear all;
close all;

% 4 bytes in float (single precision)
DEPTH_W = 512;
DEPTH_H = 424;
DEPTH_MAX = 2000;%8000;
DEPTH_MIN = 200;

run('../startup.m');
%
RGB_W = 1920;
RGB_H = 1080;
rgb_img = uint8(zeros([RGB_H, RGB_W, 3]));

% 1 second timeout
s_depth = zmq('subscribe', 'tcp', '192.168.123.246', 43346);
s_color = zmq('subscribe', 'tcp', '192.168.123.246', 43347);
%s_mesh = zmq('subscribe', 'tcp', '192.168.123.232', 43344);
%s_mesh = zmq( 'subscribe', 'ipc', 'mesh0' );
s_field = zmq('publish', 'tcp', 1999);

while 1
    idx = zmq('poll',1000);  % assume only one channel
    if isempty(idx)
       disp('empty!');
       % return;
    end
    for s = 1:numel(idx)
        s_idx = idx(s);
        [data, has_more] = zmq('receive', s_idx);
        % Get the metadata
        [metadata,offset] = msgpack('unpack', data);
        if has_more, [raw, has_more] = zmq('receive', s_idx); end
        %char(metadata.id)
        if strcmp(char(metadata.id), 'k2_depth') %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% depth 
                tic,
                raw = reshape(typecast(raw, 'single'), [DEPTH_W, DEPTH_H]);
                uisetting; % See uisetting.m       size(D)
                 
                % TASK: localization at the corner 
                ui.taskMode = 11 ;
                ui.figures(3) = 5;
                % TODO: moving average? 
                
                [res, meta] = detectPlanes6(raw, metadata, ui);  
                pose = localizeCorner_v4(res,metadata);
                % TASK: localization at the corner 
                if (pose.isValid1 + pose.isValid2) > 0
                    if pose.isValid1 == 1 && pose.isValid2 == 0
                        distance = pose.x;
                    else % both 1
                        if pose.theta_body > 0
                            distance = [pose.x pose.y];
                        else
                            distance = [pose.y pose.x];                            
                        end
                    end
                    yaw = pi - pose.theta_body;
                    if yaw  > pi
                        yaw = -2*pi + yaw;
                    end                  
                    
                    distance
                    yaw
                    
                    data = struct('dist',distance, 'yaw',yaw); % yaw degree
                    packed_data=msgpack('pack',data);                    
                    zmq('send',s_field,packed_data);
                end
                 toc,
               
        elseif strcmp(char(metadata.id), 'k2_rgb') %%%%%%%%%%%%%%%%%%%%%%%%% RGB
            % rgb_img = djpeg(raw);
            % set(h_rgb, 'CData', rgb_img);            
         
        elseif 0 %strcmp(char(metadata.id), 'mesh0')
          
         
        end
    end
    drawnow;
end