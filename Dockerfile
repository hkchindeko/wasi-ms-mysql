# syntax=docker/dockerfile:1

FROM --platform=$BUILDPLATFORM rust:1.66.1 AS buildbase
WORKDIR /src
RUN <<EOT bash
    set -ex
    apt-get update
    apt-get install -y \
        git \
        clang
    rustup target add wasm32-wasi
EOT
# This line install WasmEdge including the AOT compiler
RUN curl -sSf https://raw.githubusercontent.com/WasmEdge/WasmEdge/master/utils/install.sh | bash

FROM buildbase AS build
COPY Cargo.toml orders.json update_order.json ./ 
COPY src ./src
# Build the Wasm binary
RUN --mount=type=cache,target=/usr/local/cargo/git/db \
    --mount=type=cache,target=/usr/local/cargo/registry/cache \
    --mount=type=cache,target=/usr/local/cargo/registry/index \
    cargo build --target wasm32-wasi --release
# This line builds the AOT wasm binary
RUN /root/.wasmedge/bin/wasmedgec target/wasm32-wasi/release/wasi-ms-mysql.wasm wasi-ms-mysql.wasm

FROM scratch
COPY --link --from=build /src/wasi-ms-mysql.wasm /wasi-ms-mysql.wasm
ENTRYPOINT [ "wasi-ms-mysql.wasm" ]