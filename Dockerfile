FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ── Step 1: 32-bit arch + system packages ───────────────────────────────────
RUN dpkg --add-architecture i386 && \
    apt-get update && apt-get install -y --no-install-recommends \
        wget \
        gnupg2 \
        software-properties-common \
        xvfb \
        x11-utils \
        cabextract \
        winbind \
        libgl1-mesa-glx \
        libgl1-mesa-dri \
        libglu1-mesa \
        libpulse0 \
        libpulse0:i386 \
        libasound2 \
        libasound2:i386 \
        fonts-liberation \
        fonts-freefont-ttf \
        p7zip-full \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Step 2: WineHQ repo setup ────────────────────────────────────────────────
RUN mkdir -pm 755 /etc/apt/keyrings && \
    wget -q -O /etc/apt/keyrings/winehq-archive.key \
        https://dl.winehq.org/wine-builds/winehq.key && \
    wget -q -NP /etc/apt/sources.list.d/ \
        https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources && \
    apt-get update

# ── Step 3: Install Wine packages EXPLICITLY ─────────────────────────────────
RUN apt-get install -y --no-install-recommends \
        winehq-stable \
        wine-stable \
        wine-stable-amd64 \
        wine-stable-i386:i386 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Step 4: winetricks ───────────────────────────────────────────────────────
RUN wget -q -O /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

# ── Step 5: ENV — all in one instruction ────────────────────────────────────
ENV PATH="/opt/wine-stable/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    LD_LIBRARY_PATH="/opt/wine-stable/lib:/opt/wine-stable/lib64" \
    WINEDEBUG=-all \
    WINEPREFIX=/root/.wine \
    WINEARCH=win64 \
    DISPLAY=:99

WORKDIR /compiler
COPY ./MT5      /compiler/MT5
COPY ./scripts  /compiler/scripts
COPY compile.sh /compiler/compile.sh
RUN chmod +x /compiler/compile.sh

# ── Step 6: Verify wine binary works ────────────────────────────────────────
# wine64 no longer exists as a separate binary in Wine 9+
# 'wine' handles both 32 and 64-bit executables directly
RUN wine --version

ENTRYPOINT ["/bin/bash", "/compiler/compile.sh"]