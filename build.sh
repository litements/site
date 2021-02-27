#!/usr/bin/env bash

pip install -U pip setuptools
pip install markdown-include mkdocs mkdocs-markdownextradata-plugin mkdocs-material mkdocstrings pymdown-extensions mkdocs-minify-plugin

mkdocs build
