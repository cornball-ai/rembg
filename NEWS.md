# rembg 0.1.0

* First release. An R port of the Python *rembg* background-removal package,
  running pre-trained ONNX segmentation models through **onnxr** (no Python),
  with **jpeg**/**png** and base R for image IO, resize and compositing.
* 16 models plus 3 bring-your-own-model presets: the u2net family, silueta,
  isnet (general/anime), birefnet (7 variants), bria-rmbg, u2net_cloth_seg,
  sam, and u2net_custom / dis_custom / ben_custom.
* `rembg()` outputs a transparent RGBA cutout, the mask only, a solid
  background colour, raw PNG bytes, or a written file.
* Optional closed-form alpha matting (a port of *pymatting*) for soft
  hair/fur edges, JPEG EXIF orientation handling, per-garment clothing
  segmentation, and SAM click-to-segment point prompts.
