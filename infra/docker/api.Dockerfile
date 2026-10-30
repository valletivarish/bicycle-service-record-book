# Image for the Express API. Built in CI, pushed to Amazon ECR and run on EC2.
# Build context is code/server.
FROM node:22

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev
COPY src ./src
COPY migrations ./migrations

ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "src/server.js"]
