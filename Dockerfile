# Build stage
FROM erlang:28.0.2.0-alpine as builder
COPY --from=ghcr.io/gleam-lang/gleam:v1.11.0-erlang-alpine /bin/gleam /bin/gleam

WORKDIR /app

# Copy project files
COPY gleam.toml manifest.toml ./
COPY src/ ./src/
COPY test/ ./test/

# Build the application
RUN gleam export erlang-shipment

# Runtime stage
FROM erlang:28.0.2.0-alpine
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