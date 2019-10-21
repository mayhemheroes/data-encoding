#!/bin/sh
set -e

info() { echo "[1;36mInfo:[m $1"; }

git clean -fxd

( cd lib
  info "Build library"
  cargo build --verbose

  info "Test library"
  cargo test --verbose

  ( cd macro
    info "Build macro library"
    cargo build --verbose

    info "Test macro library"
    cargo test --verbose
  )

  if [ "$TRAVIS_RUST_VERSION" = nightly ]; then
    info "Benchmark library"
    cargo bench --verbose

    ( cd macro
      info "Build macro library (no stable feature)"
      cargo build --no-default-features --verbose

      info "Test macro library (no stable feature)"
      cargo test --no-default-features --verbose
    )
  fi
)
( cd bin
  info "Build binary"
  cargo build --verbose

  info "Test binary"
  cargo test --verbose
  ./test.sh

  info "Benchmark binary"
  ./bench.sh
)
( info "Ensure cargo-outdated is installed"
  which cargo-outdated >/dev/null || cargo install cargo-outdated

  info "Test dependencies"
  cargo outdated -w -R --exit-code=1
)

( [ -n "$FUZZIT_API_KEY" ] || exit 0
  [ "$TRAVIS_RUST_VERSION" = nightly ] || exit 0
  cd lib

  info "Ensure the latest version of cargo-fuzz is installed"
  cargo install -f cargo-fuzz

  info "Download fuzzit"
  wget -q -O fuzzit https://github.com/fuzzitdev/fuzzit/releases/latest\
/download/fuzzit_Linux_x86_64
  chmod +x fuzzit

  info "Build fuzzer"
  cargo fuzz run round_trip -- -runs=0

  info "Run regression tests"
  ./fuzzit create job --type local-regression ia0-gh/data-encoding \
           ./fuzz/target/x86_64-unknown-linux-gnu/debug/round_trip

  [ "$TRAVIS_BRANCH" = master ] || exit 0
  [ "$TRAVIS_EVENT_TYPE" = push ] || exit 0

  info "Update continuous test"
  ./fuzzit create job ia0-gh/data-encoding \
           ./fuzz/target/x86_64-unknown-linux-gnu/debug/round_trip
)

( [ -n "$TRAVIS_JOB_ID" ] || exit
  [ "$TRAVIS_RUST_VERSION" = nightly ] || exit
  git clean -fxd

  info "Download kcov"
  wget -q https://github.com/SimonKagstrom/kcov/archive/master.tar.gz

  info "Build kcov"
  tar xf master.tar.gz
  mkdir kcov-master/build
  ( cd kcov-master/build
    cmake ..
    make >/dev/null
  ) || return

  info "Test library coverage"
  ( cd lib; cargo test --verbose --no-run )
  find target/debug -maxdepth 1 -type f -perm /u+x -printf '%P\n' |
    while IFS= read -r test; do
      info "Run $test"
      ./kcov-master/build/src/kcov --include-path=lib/src/ target/kcov-"$test" \
                                   ./target/debug/"$test"
    done; unset test

  info "Send coverage to coveralls.io"
  ./kcov-master/build/src/kcov --coveralls-id="$TRAVIS_JOB_ID" \
                               --merge target/kcov target/kcov-*
) || true

info "Done"
