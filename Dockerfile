FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# ── Step 1: 32-bit arch + core system packages ──────────────────────────────
# cabextract  → needed by winetricks to unpack MS redistributables
# winbind     → needed by Wine for NT domain auth stubs (prevents crashes)
# xvfb        → virtual framebuffer so MetaEditor can open a "window"
# x11-utils   → gives us xdpyinfo to verify Xvfb started correctly
# iconv is part of libc-bin (pre-installed) — do NOT add it here
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
        libgstreamer1.0-0 \
        libgstreamer-plugins-base1.0-0 \
        fonts-liberation \
        fonts-freefont-ttf \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Step 2: WineHQ Stable (pinned to jammy repo) ────────────────────────────
RUN mkdir -pm 755 /etc/apt/keyrings && \
    wget -q -O /etc/apt/keyrings/winehq-archive.key \
        https://dl.winehq.org/wine-builds/winehq.key && \
    wget -q -NP /etc/apt/sources.list.d/ \
        https://dl.winehq.org/wine-builds/ubuntu/dists/jammy/winehq-jammy.sources && \
    apt-get update && \
    apt-get install --install-recommends -y winehq-stable && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# ── Step 3: winetricks (needed to install vcrun / fonts MetaEditor requires) ─
RUN wget -q -O /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

# ── Step 4: ENV — single instruction avoids BuildKit UndefinedVar warning ───
ENV PATH="/opt/wine-stable/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    LD_LIBRARY_PATH="/opt/wine-stable/lib:/opt/wine-stable/lib64" \
    WINEDEBUG=-all \
    WINEPREFIX=/root/.wine \
    WINEARCH=win64 \
    DISPLAY=:99

WORKDIR /compiler

# ── Step 5: Copy your project files ─────────────────────────────────────────
COPY ./MT5      /compiler/MT5
COPY ./scripts  /compiler/scripts
COPY compile.sh /compiler/compile.sh
RUN chmod +x /compiler/compile.sh

# ── Step 6: Pre-bake the Wine prefix inside the image ───────────────────────
# Doing this at BUILD time means the prefix is cached in the Docker layer.
# At runtime we skip the slow wineboot init entirely.
RUN Xvfb :99 -screen 0 1024x768x24 & \
    sleep 3 && \
    wine wineboot --init && \
    wineserver --wait && \
    winetricks -q corefonts vcrun2019 && \
    wineserver --wait && \
    echo "Wine prefix pre-baked successfully"

ENTRYPOINT ["/bin/bash", "/compiler/compile.sh"]