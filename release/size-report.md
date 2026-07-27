# Android bundle size report

Measured from the signed `1.0.0+4003` release App Bundle on 27 July 2026.

| Metric | Before | Current |
| --- | ---: | ---: |
| Signed AAB | 191.3 MiB | 124.3 MiB |
| Bundled NSFW model | 83.9 MiB raw | 11.3 MiB raw |
| NSFW model compressed inside AAB | 73.9 MiB | 10.4 MiB |
| Estimated arm64 compressed delivery | Not recorded | 50.7 MiB |
| Estimated armeabi-v7a compressed delivery | Not recorded | 47.9 MiB |
| Estimated x86_64 compressed delivery | Not recorded | 52.2 MiB |

Directly installable, permanently signed split APKs were also produced for QA:
arm64-v8a `86.8 MiB`, armeabi-v7a `71.7 MiB`, and x86_64 `92.9 MiB`. These APK
file sizes are not the Play download estimate because the App Bundle delivery
pipeline performs additional device-specific serving and compression.

The AAB itself contains all three ABIs, Play metadata, R8 mapping and native
debug symbols. Members receive only their device ABI, so the delivery estimate
is the relevant download footprint. Play Console will provide the authoritative
device/configuration download size after upload.

The model replacement was checked against OpenNSFW2's three published test
images. Full-model NSFW scores were `0.015542`, `0.982619`, and `0.076506`; the
mobile float16 build returned `0.015408`, `0.982454`, and `0.076301`. Maximum
absolute score drift was `0.000206`, well below the production `> 0.85` review
threshold.
