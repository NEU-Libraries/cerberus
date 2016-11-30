Loris is installed in /opt/loris (after vagrant destroy/up)
it is available at http://localhost:8080/loris
to retrieve a specific file, get the pid for the image (tif or jpeg2000 is best but regular jpeg will do)
http://localhost:8080/loris/neu:np193b05b (it accepts encoded or non-encoded :)
this will return info.json for the image
to get back full image do http://localhost:8080/loris/neu:np193b05b/full/full/0/default.jpg
more info on iiif image api is here: http://iiif.io/api/image/2.1/#terminology


to convert a 16bit tif to an 8bit tif
convert neu_m040bp236-master.tif -depth 8 neu_m040bp236-master_8bit.tif

if you need to change something in the config, it is located in /opt/loris/etc/loris2.conf
once you change something in the file run sudo ./setup.py install from /opt/loris to have the changes take affect
more info on the loris config is available here: https://github.com/loris-imageserver/loris
