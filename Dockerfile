FROM dpage/pgadmin4:latest
ENV PGADMIN_LISTEN_PORT=8080

COPY servers.json /pgadmin4/servers.json

