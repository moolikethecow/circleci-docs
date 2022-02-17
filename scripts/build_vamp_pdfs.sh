#!/bin/bash

OUT_DIR="release/tmp"

DATE=$(date +"%m/%d/%Y")

COMMENT="FINAL"

# Build Overview
echo "Building Vamp docs..."
asciidoctor-pdf -v
asciidoctor-pdf -a pdf-style=jekyll/_cci2/_release-pdf/circle-theme.yml -a pdf-fontsdir=jekyll/_cci2/_release-pdf/fonts -a skip-front-matter -a pdf=true -a revdate=${DATE} -D ${OUT_DIR} -o Vamp-Overview.pdf jekyll/_cci2/_continuous_release/index.adoc
echo "Done!"