# Image for the Express API. Built in CI, pushed to Amazon ECR and run on EC2.
# Build context is server/.

# Stage 1 installs the production dependencies with npm.
FROM node:22-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Stage 2 is what runs. npm, corepack and yarn are removed: the app never needs them
# at runtime, and their bundled packages were most of the image's HIGH CVEs.
FROM node:22-alpine
RUN rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
      /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack \
      /opt/yarn-* /usr/local/bin/yarn /usr/local/bin/yarnpkg
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY package.json ./
COPY src ./src
COPY migrations ./migrations

ENV NODE_ENV=production
# The built-in unprivileged user of the node image; the app needs no root.
USER node
EXPOSE 3000
CMD ["node", "src/server.js"]
