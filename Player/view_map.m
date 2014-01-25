function [] = view_map(map_name)
    fid = fopen(map_name);
    dims = fread(fid,2,'*double');
    disp(dims)
    data = fread(fid,inf,'*double');
    fclose(fid);
    map = reshape(data,dims(1),dims(2));

    clear data fid
    figure(1);
    clf;
    imagesc(map');
end