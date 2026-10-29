FROM swift:6.4.1-noble

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcairo2-dev \
    libsdl2-dev \
    pkg-config \
    xvfb \
    libharfbuzz-dev \
    libfreetype-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
