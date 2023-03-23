#!/usr/bin/env bash

for f in patch/*.patch ; do
    if patch -p0 --forward --dry-run --silent < $f; then
        patch -p0 --forward < $f
    fi
done
