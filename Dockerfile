FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Enable 32-bit architecture and install basics
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y \
    wget gnupg2 software-properties-common xvfb \
    libgl1-mesa-glx libgl1-mesa-dri iconv \
    && apt-get clean

# 2. Install Wine 9.0 (Stable) from WineHQ
RUN mkdir -pm 755 /etc/apt/keyrings && \
    wget -O /etc/apt/keyrings/winehq-archive.key https://dl.winehq.org/wine-builds/winehq.key && \
    wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources && \
    apt-get update && \
    apt-get install --install-recommends -y winehq-stable && \
    apt-get clean

# 3. THE FIX: Set Path and Library Path so Wine can find its own DLLs
ENV PATH="/opt/wine-stable/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/wine-stable/lib:/opt/wine-stable/lib64:${LD_LIBRARY_PATH}"

WORKDIR /compiler
COPY ./MT5 /compiler/MT5
COPY ./scripts /compiler/scripts
COPY compile.sh /compiler/compile.sh

RUN chmod +x /compiler/compile.sh

# Stop Wine from being noisy
ENV WINEDEBUG=-all
ENV WINEPREFIX=/root/.wine
ENV WINEARCH=win64

ENTRYPOINT ["/bin/bash", "/compiler/compile.sh"]