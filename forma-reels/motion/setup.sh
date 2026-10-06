#!/bin/sh
# One-time setup: Python + Node deps and the Kokoro voice model (~120 MB, into .kokoro/).
set -e
cd "$(dirname "$0")"
pip install kokoro-onnx soundfile numpy
npm install
mkdir -p .kokoro
base=https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0
[ -f .kokoro/kokoro.onnx ] || curl -L -o .kokoro/kokoro.onnx $base/kokoro-v1.0.int8.onnx
[ -f .kokoro/voices.bin ] || curl -L -o .kokoro/voices.bin $base/voices-v1.0.bin
