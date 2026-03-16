FROM scottyhardy/docker-wine:latest

ENV DEBIAN_FRONTEND=noninteractive

USER root
RUN apt-get update && apt-get install -y --no-install-recommends \
        wget \
        xvfb \
        x11-utils \
        cabextract \
        fonts-liberation \
        fonts-freefont-ttf \
        p7zip-full \
        file \
        xxd \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget -q -O /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

ENV WINEDEBUG=-all \
    WINEPREFIX=/root/.wine \
    WINEARCH=win64 \
    DISPLAY=:99

# Pre-bake Wine prefix at build time — network available here
# so winetricks can download corefonts and vcrun2019
RUN Xvfb :99 -screen 0 1024x768x24 -ac +extension GLX +render -noreset & \
    sleep 4 && \
    wineboot && \
    wineserver --wait && \
    wine reg add "HKCU\\Software\\Wine\\WineDbg" /v ShowCrashDialog /t REG_DWORD /d 0 /f && \
    wine reg add "HKCU\\Software\\Wine" /v Version /t REG_SZ /d "win10" /f && \
    wineserver --wait && \
    winetricks -q corefonts vcrun2019 && \
    wineserver --wait && \
    echo "Wine prefix pre-baked successfully"

RUN wine --version

WORKDIR /compiler
COPY ./MT5      /compiler/MT5
COPY ./scripts  /compiler/scripts
COPY compile.sh /compiler/compile.sh
RUN chmod +x /compiler/compile.sh

ENTRYPOINT ["/bin/bash", "/compiler/compile.sh"]