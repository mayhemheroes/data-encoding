#!/bin/sh
set -e

info() {
  echo "[1;36m$1[m"
}

info_exec() {
  local dir=$1; shift
  info "( cd $dir && $* )"
  ( cd $dir && "$@" )
}

test_cargo() {
  local dir
  for dir in $(find . -name Cargo.toml | sed 's#^./##;s#/Cargo.toml$##'); do
    [ $1 = clippy -a $dir = www ] && continue
    [ $1 = clippy -a $dir = cmp ] && continue
    [ $1 = build -a $dir = nostd ] && continue
    [ $1 = test -a $dir = nostd ] && continue
    info_exec $dir cargo "$@"
  done
}

test_cargo fmt -- --check
test_cargo clippy -- --deny=warnings
test_cargo audit --deny=warnings
test_cargo build --verbose
test_cargo test --verbose
for v in 1.46 stable nightly; do
  for r in '' --release; do
    build="info_exec lib cargo +$v build --verbose"
    $build $r
    $build $r --no-default-features
    $build $r --no-default-features --features=alloc
    info_exec lib/macro cargo +$v build --verbose $r
  done
  info_exec lib cargo +$v test --verbose
  info_exec lib/macro cargo +$v test --verbose
done
info_exec lib cargo fuzz run round_trip -- -runs=0
info_exec nostd cargo +nightly run --verbose --release
info_exec nostd cargo +nightly run --verbose --release --features=alloc
for v in stable nightly; do
  info_exec bin cargo +$v build --verbose
  info_exec bin cargo +$v build --verbose --release
  info_exec bin cargo +$v test --verbose
  info_exec bin ./test.sh +$v
done

info "Done"
