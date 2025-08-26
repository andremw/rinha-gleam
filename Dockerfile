# Build stage
FROM ghcr.io/gleam-lang/gleam:v1.11.0-erlang-alpine AS builder

WORKDIR /app

# Copy project files
COPY gleam.toml manifest.toml ./
COPY src/ ./src/
COPY test/ ./test/

# Build the application
RUN gleam export erlang-shipment

# Runtime stage
FROM ghcr.io/gleam-lang/gleam:v1.11.0-erlang-alpine
RUN \
  addgroup --system webapp && \
  adduser --system webapp -g webapp

USER webapp

WORKDIR /app

# Copy built application
COPY --from=builder /app/build/erlang-shipment/ ./

EXPOSE 9999

# Start the application
CMD ["sh", "-c", "./entrypoint.sh run"]