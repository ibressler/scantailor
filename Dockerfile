# A Dockerfile to build and package from source
#
#   podman build . -t scantailor --build-arg TZ=Europe/Berlin -v $(pwd):/usr/src/st
#
# Run the container interactively:
#
#   xhost local:$(id -un)  # adds authorization for X forwarding (Wayland not tested)
#   podman run --rm -it -e DISPLAY --net host scantailor
#

FROM ubuntu:24.04 as builder
ARG TZ
# Set the environment variable for non-interactive installation
ENV DEBIAN_FRONTEND=noninteractive
# Set the timezone by given argument
ENV TZ=${TZ}

# install a newer CMake
RUN apt-get update && \
    apt-get install -y git ca-certificates gpg wget && \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null \
        | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg]' \
        'https://apt.kitware.com/ubuntu/ noble main' \
        | tee /etc/apt/sources.list.d/kitware.list && \
    apt-get update && apt-get install -y cmake

# build and install recent podofo first
WORKDIR /usr/src
RUN git clone https://github.com/podofo/podofo.git
RUN apt-get install -y build-essential libfontconfig1-dev libfreetype-dev libxml2-dev \
    libssl-dev libjpeg-dev libpng-dev libtiff-dev
WORKDIR podofo/build
RUN cmake .. && make && make install && ldconfig

# install build requirements for scantailor
RUN apt-get update && \
    apt-get install -y build-essential vim libssl-dev liblzma-dev zlib1g-dev \
        libzstd-dev libjpeg-dev libxml2-dev libopenjp2-7-dev libopenjp2-tools \
        libopenjpip-dec-server libopenjpip-server libpng-dev libtiff-dev \
        libfreetype-dev pkg-config libboost-test-dev qttools5-dev libeigen3-dev \
        libfontconfig-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /usr/src
#RUN git clone https://github.com/crwolff/scantailor-pdf.git st
RUN ls -la st
WORKDIR st/build
RUN cmake .. -DBUILD_CLI=1 && make && make install

FROM ubuntu:24.04
ARG TZ
ENV DEBIAN_FRONTEND=noninteractive
# install runtime dependencies and cleanup development packages later
RUN apt-get update && \
    apt-get install -y libopenjp2-7 libtiff6 libqt5opengl5t64 libqt5xml5t64 && \
    apt-get purge -y $(dpkg -l | awk '/-dev[\s:]/{split($2,a,":"); print a[1]}') && \
    apt-get --purge autoremove && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/lib/libpodofo.so.*.*.* /usr/lib/
COPY --from=builder /usr/local/bin/scantailor /usr/bin/scantailor
COPY --from=builder /usr/local/bin/scantailor-cli /usr/bin/scantailor-cli
RUN cd /usr/lib && \
    ln -s libpodofo.so.*.*.* libpodofo.so.3 && \
    ln -s libpodofo.so.3 libpodofo.so && \
    ldconfig

CMD scantailor
