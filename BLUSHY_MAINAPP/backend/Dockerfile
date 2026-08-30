# Node 24 to match what the app is developed and tested against.
FROM node:24-slim

WORKDIR /app

# Dependencies first, so a code change does not reinstall them.
COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

ENV NODE_ENV=production
# Hosts set PORT themselves; server.js already reads it.
EXPOSE 3000

CMD ["node", "src/server.js"]
