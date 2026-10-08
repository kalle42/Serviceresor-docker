FROM node:20-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    chromium \
    curl \
    file \
    jq \
    cron \
    fonts-liberation \
    fonts-noto-color-emoji \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libx11-xcb1 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    xdg-utils \
    bash \
    coreutils \
    procps \
    && rm -rf /var/lib/apt/lists/*

ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true \
    PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium \
    CHROME_BIN=/usr/bin/chromium \
    NODE_ENV=production

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --omit=dev

COPY . .

RUN mkdir -p session-runtime logs && \
    chmod +x run-daily-trips.sh run-track-trip.sh run-check-trip.sh entrypoint.sh tools/sha256sum tools/publish.sh

EXPOSE 8787

ENTRYPOINT ["/app/entrypoint.sh"]