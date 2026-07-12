library(rembg)

# --- geometric transforms on a known asymmetric array ------------------------
# m rows: [1 3 5] / [2 4 6]
m <- array(c(1, 2, 3, 4, 5, 6), dim = c(2, 3, 1))

expect_equal(rembg:::.apply_orientation(m, 1L), m)            # identity
expect_equal(rembg:::.apply_orientation(m, 99L), m)           # unknown -> unchanged

# 2 = mirror left-right
expect_equal(rembg:::.apply_orientation(m, 2L)[, , 1],
             matrix(c(5, 6, 3, 4, 1, 2), 2, 3))

# 6 = rotate 90 clockwise -> 3x2
expect_equal(rembg:::.apply_orientation(m, 6L)[, , 1],
             matrix(c(2, 4, 6, 1, 3, 5), 3, 2))

# 8 = rotate 90 counter-clockwise -> 3x2
expect_equal(rembg:::.apply_orientation(m, 8L)[, , 1],
             matrix(c(5, 3, 1, 6, 4, 2), 3, 2))

# rotating CW then CCW returns to start
expect_equal(rembg:::.apply_orientation(rembg:::.apply_orientation(m, 6L), 8L), m)

# --- APP1/TIFF parser --------------------------------------------------------
# Minimal JPEG: SOI + APP1(Exif, little-endian TIFF, Orientation=6) + EOI
app1 <- as.raw(c(
  0xFF, 0xD8,                                     # SOI
  0xFF, 0xE1, 0x00, 0x22,                         # APP1, length 34
  0x45, 0x78, 0x69, 0x66, 0x00, 0x00,             # "Exif\0\0"
  0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00, # TIFF: II, 42, IFD offset 8
  0x01, 0x00,                                     # 1 IFD entry
  0x12, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, # tag 0x0112, SHORT, count 1
  0x06, 0x00, 0x00, 0x00,                         # value 6
  0x00, 0x00, 0x00, 0x00,                         # next IFD = 0
  0xFF, 0xD9                                       # EOI
))
expect_equal(rembg:::.exif_orientation(app1), 6L)

# non-JPEG and no-EXIF cases fall back to 1
expect_equal(rembg:::.exif_orientation(as.raw(c(1, 2, 3, 4))), 1L)
f <- system.file("extdata", "example.jpg", package = "rembg")
expect_equal(rembg:::.exif_orientation(readBin(f, "raw", file.size(f))), 1L)
