FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Enable 32-bit architecture and install prerequisites
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    wget \
    gnupg2 \
    software-properties-common \
    xvfb \
    libgl1-mesa-glx \
    libgl1-mesa-dri \
    && apt-get clean

# 2. Install Wine 9.0 (Stable) from WineHQ
RUN mkdir -pm 755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.gpg && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources && \
    apt-get update && \
    apt-get install --install-recommends -y winehq-stable && \
    apt-get clean

# 3. Setup work directory
WORKDIR /compiler
COPY ./MT5 /compiler/MT5
COPY ./scripts /compiler/scripts
COPY compile.sh /compiler/compile.sh

RUN chmod +x /compiler/compile.sh

# Set environment variables to stop Wine from asking questions
ENV WINEDEBUG=-all
ENV WINEPREFIX=/root/.wine
ENV WINEARCH=win64

ENTRYPOINT ["/bin/bash", "/compiler/compile.sh"]