###############################################################################
# Build stage: download the server with steamcmd and lay out the filesystem.
# Nothing from this stage ships except what the runtime stage COPYs out of it.
###############################################################################
FROM steamcmd/steamcmd:ubuntu AS build

ENV INSTALL_LOC="/barotrauma"
ENV CONF_BASE="/config_readonly"
ENV CONFIG_LOC="/volumes/config"
ENV WORKSHOP_MODS_LOC="/volumes/workshopMods"
ENV LOCAL_MODS_LOC="/volumes/localMods"
ENV SAVES_LOC="/volumes/Multiplayer"
ENV HOME="${INSTALL_LOC}"

ARG APPID=1026340
ARG LUA_SERVER

# Install the barotrauma server.
# Retried because steamcmd intermittently fails with "Missing configuration".
RUN ok=; for i in 1 2 3; do \
      steamcmd +force_install_dir "${INSTALL_LOC}" +login anonymous +app_update "${APPID}" validate +quit \
        && { ok=1; break; }; \
      echo "steamcmd attempt ${i} failed, retrying..."; sleep 10; \
    done; \
    [ -n "${ok}" ] && rm -rf "${INSTALL_LOC}"/.local/share/Steam/

# Download and install Lua for Barotrauma (always downloaded; only extracted when LUA_SERVER is set)
ADD https://github.com/evilfactory/LuaCsForBarotrauma/releases/download/latest/luacsforbarotrauma_patch_linux_server.tar.gz /tmp/luacs.tar.gz
RUN if [[ -n "${LUA_SERVER}" ]]; then tar -xzf /tmp/luacs.tar.gz -C "${INSTALL_LOC}"; fi

COPY config_player.xml "${CONFIG_LOC}/config_player.xml"
COPY serversettings.xml /tmp/serversettings.xml

# Move the shipped configs to ${CONF_BASE} (the entrypoint seeds ${CONFIG_LOC} from there)
# and symlink the game's config paths into ${CONFIG_LOC}.
# The repo's serversettings.xml is only a fallback for when the install doesn't ship one.
RUN mkdir -p "${CONFIG_LOC}" "${CONF_BASE}" && \
    if [ ! -f "${INSTALL_LOC}/serversettings.xml" ]; then mv /tmp/serversettings.xml "${INSTALL_LOC}/serversettings.xml"; fi && \
    touch "${INSTALL_LOC}/serversettings.xml" "${INSTALL_LOC}"/Data/{clientpermissions,permissionpresets,karmasettings}.xml && \
    mv "${INSTALL_LOC}/serversettings.xml" "${INSTALL_LOC}"/Data/{clientpermissions,permissionpresets,karmasettings}.xml "${CONF_BASE}" && \
    ln -s "${CONFIG_LOC}/serversettings.xml" "${INSTALL_LOC}/serversettings.xml" && \
    ln -s "${CONFIG_LOC}/config_player.xml" "${INSTALL_LOC}/config_player.xml" && \
    for c in clientpermissions permissionpresets karmasettings; do \
      ln -s "${CONFIG_LOC}/${c}.xml" "${INSTALL_LOC}/Data/${c}.xml"; \
    done

# Relocate mods, saves and logs
RUN DAEDALIC="${INSTALL_LOC}/.local/share/Daedalic Entertainment GmbH" && \
    mkdir -p "${DAEDALIC}/Barotrauma/WorkshopMods/Installed" && \
    mv "${DAEDALIC}/Barotrauma/WorkshopMods/Installed" "${WORKSHOP_MODS_LOC}" && \
    ln -s "${WORKSHOP_MODS_LOC}" "${DAEDALIC}/Barotrauma/WorkshopMods/Installed" && \
    mkdir -p "${INSTALL_LOC}/LocalMods" && \
    mv "${INSTALL_LOC}/LocalMods" "${LOCAL_MODS_LOC}" && \
    ln -s "${LOCAL_MODS_LOC}" "${INSTALL_LOC}/LocalMods" && \
    mkdir -p "${SAVES_LOC}" && \
    ln -s "${SAVES_LOC}" "${DAEDALIC}/Barotrauma" && \
    mkdir -p "${INSTALL_LOC}/ServerLogs"


###############################################################################
# Runtime stage: plain Ubuntu plus the server. No steamcmd, no i386 libraries.
# Keep the Ubuntu release in step with the steamcmd/steamcmd:ubuntu base above.
###############################################################################
FROM ubuntu:26.04

ENV INSTALL_LOC="/barotrauma"
ENV CONF_BASE="/config_readonly"
ENV CONFIG_LOC="/volumes/config"
ENV WORKSHOP_MODS_LOC="/volumes/workshopMods"
ENV LOCAL_MODS_LOC="/volumes/localMods"
ENV SAVES_LOC="/volumes/Multiplayer"
ENV HOME="${INSTALL_LOC}"

ARG UID=1000
ARG GID=1000
ARG GAME_PORT=27015
ARG STEAM_PORT=27016

# ICU (unicode support for the .NET server) and CA certificates
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get upgrade --assume-yes && \
    apt-get install --no-install-recommends --assume-yes ca-certificates icu-devtools

# --chown here sets ownership without a second copy of the install in another layer
COPY --from=build --chown=${UID}:${GID} /barotrauma /barotrauma
COPY --from=build --chown=${UID}:${GID} /volumes /volumes
COPY --from=build /config_readonly /config_readonly

# Symlink the game's steam client object into the include directory
RUN ln -s "${INSTALL_LOC}/linux64/steamclient.so" /usr/lib/steamclient.so

COPY docker-entrypoint.sh /docker-entrypoint.sh

# User and I/O
USER "${UID}"
VOLUME "${CONFIG_LOC}" "${WORKSHOP_MODS_LOC}" "${SAVES_LOC}"
EXPOSE "${GAME_PORT}/udp" "${STEAM_PORT}/udp"

# Exec
WORKDIR "${INSTALL_LOC}"
ENTRYPOINT ["/docker-entrypoint.sh"]
