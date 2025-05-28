FROM debian:bookworm-slim AS builder
ENV DEBIAN_FRONTEND=noninteractive \
    NITRO_BUILD_IGNORE_TIMESTAMPS=1

# install everything Makefile needs
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      git cmake make gcc g++ lbzip2 python3 xz-utils \
      curl wget gnupg2 software-properties-common \
      golang-go rustc cargo clang lld wabt

WORKDIR /workspace
# pull in your code + Makefile
RUN git clone --branch main --depth 1 --recurse-submodules \
      https://github.com/plumenetwork/plume-nitro.git .

# run *every* build target
RUN make build \
         build-solidity \
         build-wasm-libs \
         build-wasm-bin \
         build-prover-header \
         build-prover-lib \
         build-prover-bin \
         build-jit \
         build-replay-env

###############################################################################
# Final image with only runtime bits
###############################################################################
FROM debian:bookworm-slim
RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates wabt && \
    rm -rf /var/lib/apt/lists/*

# copy all the baked artifacts
COPY --from=builder /workspace/target/bin/* /usr/local/bin/
COPY --from=builder /workspace/target/machines/ /usr/local/share/nitro/machines/
# (copy any other files your node needs, e.g. .make/, contracts/, etc.)

ENTRYPOINT ["nitro"]
CMD ["--help"]
