FROM steamcmd/steamcmd:ubuntu

# Directories
ENV INSTALL_LOC="/barotrauma"
ENV CONF_BASE="/config_readonly"
ENV CONFIG_LOC="${INSTALL_LOC}/volumes/config"
ENV WORKSHOP_MODS_LOC="${INSTALL_LOC}/volumes/workshopMods"
ENV LOCAL_MODS_LOC="${INSTALL_LOC}/volumes/localMods"
ENV SAVES_LOC="${INSTALL_LOC}/volumes/Multiplayer"

ENV HOME="${INSTALL_LOC}"


# Build args
ARG UID=1000
ARG GID=1000
ARG GAME_PORT=27015
ARG STEAM_PORT=27016
ARG APPID=1026340
ARG LUA_SERVER

# Update and install unicode symbols
RUN apt-get update && \
    apt-get upgrade --assume-yes && \
    apt-get install --no-install-recommends --assume-yes icu-devtools apt-utils curl tar && \
    apt-get clean && \
    rm -rf /var/cache/apt/archives /var/lib/apt/lists/*
    # rm call is probably redundant after the clean call above

# Install the barotrauma server
RUN steamcmd \
    +force_install_dir /barotrauma \
    +login anonymous \
    +app_update "${APPID}" validate \
    +quit

# Download and Install Lua for Barotrauma
RUN if [[ -n "${LUA_SERVER}" ]] ; then curl -L https://github.com/evilfactory/LuaCsForBarotrauma/releases/download/latest/luacsforbarotrauma_patch_linux_server.tar.gz | tar -xzv -C "${INSTALL_LOC}"; fi

# Install scripts
COPY docker-entrypoint.sh /docker-entrypoint.sh

# Copy config_player.xml
COPY config_player.xml "${CONFIG_LOC}/config_player.xml"

# Symlink the game's steam client object into the include directory
RUN ln -s "${INSTALL_LOC}/linux64/steamclient.so" /usr/lib/steamclient.so

# Sort configs and directories
RUN mkdir -p "${CONFIG_LOC}" "${CONF_BASE}"

# Copy serversettings.xml from repo as recently introduced bug
COPY serversettings.xml "${INSTALL_LOC}/serversettings-patch.xml"
RUN [ ! -f "${INSTALL_LOC}/serversettings.xml" ] && mv "${INSTALL_LOC}/serversettings-patch.xml" "${INSTALL_LOC}/serversettings.xml"

RUN mv ${INSTALL_LOC}/serversettings.xml ${INSTALL_LOC}/Data/clientpermissions.xml ${INSTALL_LOC}/Data/permissionpresets.xml ${INSTALL_LOC}/Data/karmasettings.xml "${CONF_BASE}"

RUN ln -s "${CONFIG_LOC}/serversettings.xml" "${INSTALL_LOC}/serversettings.xml" && \
  ln -s ${CONFIG_LOC}/config_player.xml ${INSTALL_LOC}/config_player.xml && \
  ln -s ${CONFIG_LOC}/clientpermissions.xml ${INSTALL_LOC}/Data/clientpermissions.xml && \
  ln -s ${CONFIG_LOC}/permissionpresets.xml ${INSTALL_LOC}/Data/permissionpresets.xml && \
  ln -s ${CONFIG_LOC}/karmasettings.xml ${INSTALL_LOC}/Data/karmasettings.xml

# Setup mods folder
RUN mkdir -p "${INSTALL_LOC}/.local/share/Daedalic Entertainment GmbH/Barotrauma/WorkshopMods/Installed"
RUN mv "${INSTALL_LOC}/.local/share/Daedalic Entertainment GmbH/Barotrauma/WorkshopMods/Installed" "${WORKSHOP_MODS_LOC}"
RUN ln -s "${WORKSHOP_MODS_LOC}" "${INSTALL_LOC}/.local/share/Daedalic Entertainment GmbH/Barotrauma/WorkshopMods/Installed"

# Setup subs folder
RUN mkdir -p "${INSTALL_LOC}/LocalMods"
RUN mv "${INSTALL_LOC}/LocalMods" "${LOCAL_MODS_LOC}"
RUN ln -s "${LOCAL_MODS_LOC}" "${INSTALL_LOC}/LocalMods"

# Setup saves folder
RUN mkdir -p "${INSTALL_LOC}/.local/share/Daedalic Entertainment GmbH" "${SAVES_LOC}" && \
    ln -s "${SAVES_LOC}" "${INSTALL_LOC}/.local/share/Daedalic Entertainment GmbH/Barotrauma"

# Setup ServerLogs folder
RUN mkdir -p "${INSTALL_LOC}/ServerLogs"

# Set directory permissions
RUN chown -R ${UID}:${GID} "${CONFIG_LOC}" "${INSTALL_LOC}" "${WORKSHOP_MODS_LOC}" "${SAVES_LOC}"

# User and I/O
USER "${UID}"
VOLUME "${CONFIG_LOC}" "${WORKSHOP_MODS_LOC}" "${SAVES_LOC}"
EXPOSE "${GAME_PORT}/udp" "${STEAM_PORT}/udp"

# Exec
WORKDIR "${INSTALL_LOC}"
ENTRYPOINT ["/docker-entrypoint.sh"]
