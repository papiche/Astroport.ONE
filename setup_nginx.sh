#!/bin/bash
#script to create the nginx configuraiton file

echo "server {" > ~/.zen/tmp/astroport_nginx.conf
echo "    listen 443;" >> ~/.zen/tmp/astroport_nginx.conf
echo "    server_name astroport.locallhost;" >> ~/.zen/tmp/astroport_nginx.conf

for i in {12245..12445};
do
    echo "    location /$i {" >> ~/.zen/tmp/astroport_nginx.conf
    echo "        proxy_pass http://localhost:$i;" >> ~/.zen/tmp/astroport_nginx.conf
    echo "    }" >> ~/.zen/tmp/astroport_nginx.conf
    i=$(($i + 1))
done

echo "}" >> ~/.zen/tmp/astroport_nginx.conf

 ## IN CASE YOU WANT TO ACCESS API THROUGH HTTPS
 echo "~/.zen/tmp/astroport_nginx.conf"
 echo "Add this file to your nginx config and activate https using certbot..."
 echo "TODO: make it easier ;)"
