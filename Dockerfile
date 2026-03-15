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
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN wget -q -O /usr/local/bin/winetricks \
        https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && \
    chmod +x /usr/local/bin/winetricks

ENV WINEDEBUG=-all \
    WINEPREFIX=/root/.wine \
    WINEARCH=win64 \
    DISPLAY=:99

RUN wine --version

WORKDIR /compiler
COPY ./MT5      /compiler/MT5
COPY ./scripts  /compiler/scripts
COPY compile.sh /compiler/compile.sh
RUN chmod +x /compiler/compile.sh

ENTRYPOINT ["/bin/bash", "/compiler/compile.sh"]