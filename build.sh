#!/bin/sh
# Reproducible build: the same source and Go version give a byte-identical
# .exe, so anyone can rebuild it and compare the SHA-256 with the release.
set -eu
cd "$(dirname "$0")"
command mkdir -p dist
for arch in amd64 arm64; do
	CGO_ENABLED=0 GOOS=windows GOARCH=$arch \
		go build -trimpath -buildvcs=false -ldflags "-s -w -buildid=" \
		-o "dist/Linux-Check-$arch.exe" .
done
cd dist && sha256sum Linux-Check-amd64.exe Linux-Check-arm64.exe | tee SHA256SUMS.txt
