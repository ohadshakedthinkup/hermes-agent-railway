FROM python:3.14-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates ripgrep ffmpeg \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

RUN git clone --recurse-submodules https://github.com/NousResearch/hermes-agent.git /opt/hermes-agent \
       && cd /opt/hermes-agent && git checkout 8237c7f8ec179c88857f24a174509d985af704b7 \
       && git submodule update --init --recursive

WORKDIR /opt/hermes-agent
RUN apt-get update && apt-get install -y --no-install-recommends build-essential wget \
 && wget -q https://www.sqlite.org/2026/sqlite-autoconf-3510300.tar.gz \
 && tar xzf sqlite-autoconf-3510300.tar.gz && cd sqlite-autoconf-3510300 \
 && ./configure --prefix=/usr/local --enable-fts5 && make -j"$(nproc)" && make install \
 && cd .. && rm -rf sqlite-autoconf-3510300* \
 && apt-get purge -y build-essential wget && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*
ENV LD_LIBRARY_PATH=/usr/local/lib
RUN uv venv venv --python 3.14 \
    && VIRTUAL_ENV=/opt/hermes-agent/venv uv pip install -e ".[all,messaging,anthropic]"

ENV PATH="/opt/hermes-agent/venv/bin:$PATH"
ENV SIDECAR_PYTHON="/opt/hermes-agent/venv/bin/python3"
RUN apt-get update && apt-get install -y --no-install-recommends \
      libnspr4 libnss3 libasound2t64 libatk1.0-0t64 libatk-bridge2.0-0t64 \
      libcups2t64 libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
      libxrandr2 libgbm1 libpango-1.0-0 libcairo2 \
 && rm -rf /var/lib/apt/lists/*


RUN mkdir -p /root/.hermes/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache} \
    && cp cli-config.yaml.example /root/.hermes/config.yaml \
    && touch /root/.hermes/.env

COPY auth_proxy.py /auth_proxy.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
