# rembg

Remove image backgrounds in R. An R port of the Python
[rembg](https://github.com/danielgatis/rembg) package by Daniel Gatis.

It runs pre-trained segmentation models (U-2-Net, ISNet, BiRefNet, BRIA RMBG)
through the ONNX Runtime to predict a foreground alpha matte, then composites a
cutout with a transparent (or solid-colour) background. Inference goes through
[onnxr](https://cran.r-project.org/package=onnxr) (a `cpp11` binding to ONNX
Runtime, no Python). Images are decoded with `jpeg`/`png` and everything else is
base-R array math, so the dependency footprint is small.

## Install

```r
# 1. the ONNX Runtime binding + the runtime library (one-time, ~35 MB CPU build)
install.packages("onnxr")
onnxr::onnx_install()

# 2. this package
# install.packages("rembg")   # once on CRAN
```

## Use

```r
library(rembg)

# simplest: path in, RGBA array out (default model "u2net")
cutout <- rembg("photo.jpg")
png::writePNG(cutout, "cutout.png")

# reuse a model across many images
sess <- new_session("isnet-general-use")
rembg("a.jpg", session = sess, out = "a.png")
rembg("b.jpg", session = sess, out = "b.png")

# just the mask, or a solid background
mask  <- rembg("photo.jpg", only_mask = TRUE)
white <- rembg("photo.jpg", bgcolor = c(255, 255, 255, 255))
```

`input` accepts a file path, a raw vector of PNG/JPEG bytes, or a numeric
`[h,w,c]` array. Output is an `[h,w,4]` array in `[0,1]` by default, `raw` PNG
bytes with `output = "raw"`, and a written PNG when `out` is a path.

## Models

```r
rembg_models()
```

`u2net`, `u2netp`, `u2net_human_seg`, `silueta`, `isnet-general-use`,
`isnet-anime`, `birefnet-general`, `birefnet-general-lite`, `birefnet-portrait`,
`birefnet-dis`, `birefnet-hrsod`, `birefnet-cod`, `birefnet-massive`,
`bria-rmbg`.

Models download on first use into `~/.u2net` (or `U2NET_HOME`), the same cache
the Python `rembg` uses, so the two share downloads.

## Notes

- Needs a GPU? `new_session(model, backend = "cuda")` (requires a CUDA runtime
  build via `onnxr::onnx_install(cuda = TRUE)`).
- Fidelity: masks match Python `rembg` closely (≈99.9% pixel agreement) but are
  not bit-identical. We resize with bilinear where PIL uses LANCZOS; the
  difference shows only at soft edges (hair, fur).
- JPEG EXIF orientation is honoured, so sideways-stored phone photos are
  corrected on read (like PIL's `exif_transpose`).
- Not yet ported: alpha matting, the SAM and cloth-segmentation models, and
  custom-model paths.

## License

MIT. Original Python `rembg` © Daniel Gatis (MIT).
