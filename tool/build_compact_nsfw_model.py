#!/usr/bin/env python3
"""Build the compact, reproducible OpenNSFW2 LiteRT asset.

Run from an isolated Python 3.12 environment containing tensorflow-cpu and
opennsfw2. The shipped model keeps float32 I/O while storing trained weights as
float16, which materially reduces the Android bundle without changing the Dart
inference contract or the moderation decision threshold.
"""

from __future__ import annotations

import argparse
import hashlib
import pathlib

import opennsfw2
import tensorflow as tf


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=pathlib.Path("assets/models/opennsfw2_float16.tflite"),
    )
    args = parser.parse_args()

    model = opennsfw2.make_open_nsfw_model()
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    converted = converter.convert()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(converted)
    digest = hashlib.sha256(converted).hexdigest()
    print(f"bytes={len(converted)}")
    print(f"sha256={digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
