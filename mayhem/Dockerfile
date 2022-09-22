# Build Stage
FROM ghcr.io/evanrichter/cargo-fuzz:latest as builder

## Add source code to the build stage.
ADD . /src
WORKDIR /src

RUN echo building instrumented harnesses && \
    bash -c "pushd lib/fuzz && cargo +nightly -Z sparse-registry fuzz build && popd" && \
    mv target/x86_64-unknown-linux-gnu/release/round_trip /round_trip && \
    echo done

RUN echo building non-instrumented harnesses && \
    export RUSTFLAGS="--cfg fuzzing -Clink-dead-code -Cdebug-assertions -C codegen-units=1" && \
    bash -c "pushd lib/fuzz && cargo +nightly -Z sparse-registry build --release && popd" && \
    mv target/release/round_trip /round_trip_no_inst && \
    echo done

# Package Stage
FROM rustlang/rust:nightly

COPY --from=builder /round_trip /round_trip_no_inst /
