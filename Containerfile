# DJOS: Fedora atómico con KDE Plasma, pensado para DJs y producción de audio.
# Base: Universal Blue (Fedora Kinoite + driver de NVIDIA), que se arma todos los días desde Fedora.
ARG BASE_IMAGE=ghcr.io/ublue-os/kinoite-nvidia
ARG FEDORA_VERSION=44

FROM scratch AS ctx
COPY build /build
COPY system /system

FROM ${BASE_IMAGE}:${FEDORA_VERSION}
ARG FEDORA_VERSION
LABEL org.opencontainers.image.title="DJOS" djos.fedora="${FEDORA_VERSION}"

RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    bash /ctx/build/build.sh

RUN bootc container lint
