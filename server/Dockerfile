# --- build stage ---
# Use a CN-accessible mirror if the official registry is unreachable.
# Override: --build-arg GOLANG_IMAGE=golang:1.25-alpine
ARG GOLANG_IMAGE=registry.cn-hangzhou.aliyuncs.com/library/golang:1.25-alpine
FROM ${GOLANG_IMAGE} AS build
WORKDIR /src

# China-friendly module proxy; default proxy.golang.org is unreachable here.
# Override at build time with --build-arg GOPROXY=... if needed.
ARG GOPROXY=https://goproxy.cn,direct
ENV GOPROXY=${GOPROXY}
ENV GOSUMDB=off

# Cache deps first.
COPY go.mod go.sum* ./
RUN go mod download

COPY . .
# Static build for a small final image.
RUN CGO_ENABLED=0 GOOS=linux go build -o /out/server ./cmd/server

# --- runtime stage ---
# Use a CN-accessible mirror. Override: --build-arg ALPINE_IMAGE=alpine:3.20
ARG ALPINE_IMAGE=registry.cn-hangzhou.aliyuncs.com/library/alpine:3.20
FROM ${ALPINE_IMAGE}
RUN apk add --no-cache ca-certificates tzdata && \
    cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone
WORKDIR /app
COPY --from=build /out/server /app/server
COPY migrations /app/migrations
ENV MIGRATIONS_DIR=/app/migrations
EXPOSE 8080
ENTRYPOINT ["/app/server"]
