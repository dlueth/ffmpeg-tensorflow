ARG VERSION_CUDA=10.2-cudnn7
ARG VERSION_UBUNTU=18.04

FROM nvidia/cuda:${VERSION_CUDA}-devel-ubuntu${VERSION_UBUNTU} as build

ARG VERSION_FFMPEG=4.3.1
ARG VERSION_LIBTENSORFLOW=1.15.0

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm \
    DEPENDENCIES="autoconf automake build-essential cmake curl git-core libass-dev libfdk-aac-dev libfreetype6-dev libgnutls28-dev libmp3lame-dev libnuma-dev libopus-dev libsdl2-dev libtool libunistring-dev libva-dev libvdpau-dev libvorbis-dev libvpx-dev libxcb-shm0-dev libxcb-xfixes0-dev libxcb1-dev libx264-dev libx265-dev nasm pkg-config texinfo yasm zlib1g-dev" \
    CLEANUP="/usr/local/lib/libcuda.so.1"

COPY script/ /usr/local/sbin/

RUN set -e && bootstrap \
    ### create required symlinks &directories
        && ln -s /usr/local/cuda/lib64/stubs/libcuda.so /usr/local/lib/libcuda.so.1 \
        && mkdir -p /tmp/ffmpeg /deps /deps/usr/local/lib \
    ### prepare libtensorflow
        && curl -kLs https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-gpu-linux-x86_64-${VERSION_LIBTENSORFLOW}.tar.gz | tar -xzC /usr/local -f - \
    ### build ffmpeg
        && curl -kLs https://ffmpeg.org/releases/ffmpeg-${VERSION_FFMPEG}.tar.bz2 | tar --strip 1 -xjC /tmp/ffmpeg -f - \
        && cd /tmp/ffmpeg \
        && ./configure \
            --pkg-config-flags='--static' \
            --extra-libs='-lpthread -lm' \
            --enable-gpl \
            --enable-gnutls \
            --enable-libass \
            --enable-libfdk-aac \
            --enable-libfreetype \
            --enable-libmp3lame \
            --enable-libopus \
            --enable-libvorbis \
            --enable-libvpx \
            --enable-libx264 \
            --enable-libx265 \
            --enable-libtensorflow \
            --enable-nonfree \
        && make -j $(nproc) \
        && make install \
        && cd ~ \
    ### persist dependencies
        && ldd /usr/local/bin/ffmpeg | tr -s '[:blank:]' '\n' | grep '^/' | xargs -I % sh -c 'mkdir -p $(dirname /deps%); cp % /deps%;' \
        && mv /usr/local/lib/libtensorflow* /deps/usr/local/lib \
    ### finalize
        && finalize

ENTRYPOINT ["/usr/local/bin/ffmpeg"]


FROM nvidia/cuda:${VERSION_CUDA}-runtime-ubuntu${VERSION_UBUNTU}

LABEL authors="Vít Novotný <witiko@mail.muni.cz>,Mikuláš Miki Bankovič" \
      org.label-schema.docker.dockerfile="/Dockerfile" \
      org.label-schema.name="jetson.ffmpeg"

ENV DEBIAN_FRONTEND=noninteractive \
    TERM=xterm

COPY script/ /usr/local/sbin/
COPY --from=build /deps /
COPY --from=build /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg

RUN set -e && bootstrap && finalize

ENTRYPOINT ["/usr/local/bin/ffmpeg"]