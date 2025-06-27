FROM dpage/pgadmin4:latest
ENV PGADMIN_LISTEN_PORT=8080
ENV PGADMIN_CONFIG_SERVERS_JSON_PATH=/pgadmin4/servers.json

# Copy servers.json as before
COPY servers.json /pgadmin4/servers.json

# Copy pgpass file and set ownership to the pgadmin user (typically UID 5050)
