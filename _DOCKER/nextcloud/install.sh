sudo docker run \
--init \
--sig-proxy=false \
--name nextcloud-aio-mastercontainer \
--restart always \
--publish 8008:80 --publish 8002:8080 --publish 8443:8443 \
--env SKIP_DOMAIN_VALIDATION=true \
--env APACHE_PORT=8001 --env APACHE_IP_BINDING=0.0.0.0 \
--env NEXTCLOUD_DATADIR="/nextcloud-data" \
--volume nextcloud_aio_mastercontainer:/mnt/docker-aio-config \
--volume /var/run/docker.sock:/var/run/docker.sock:ro \
--dns 8.8.8.8 --dns 1.1.1.1 \
nextcloud/all-in-one:latest
