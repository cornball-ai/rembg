library(rembg)

f <- system.file("extdata", "example.jpg", package = "rembg")
expect_true(nzchar(f))

img <- rembg:::.read_image(f)
expect_equal(length(dim(img)), 3L)
expect_equal(dim(img)[3], 3L)
expect_true(min(img) >= 0 && max(img) <= 1)

# magic-byte format detection
expect_equal(rembg:::.image_format(readBin(f, "raw", 8L)), "jpeg")
expect_true(is.na(rembg:::.image_format(as.raw(c(1, 2, 3, 4)))))

# .as_rgb: grayscale -> 3 channels, RGBA -> drop alpha
expect_equal(dim(rembg:::.as_rgb(matrix(0.5, 4, 5))), c(4L, 5L, 3L))
expect_equal(dim(rembg:::.as_rgb(array(0.5, c(4, 5, 4)))), c(4L, 5L, 3L))

# 0-255 arrays are scaled into [0,1]
expect_true(max(rembg:::.read_image(array(255, c(2, 2, 3)))) <= 1)

# raw round-trip: encode then read back
raw_png <- rembg:::.write_png(rembg:::.cutout(img, matrix(1, dim(img)[1], dim(img)[2])), NULL)
expect_true(is.raw(raw_png))
back <- rembg:::.read_image(raw_png)
expect_equal(dim(back)[1:2], dim(img)[1:2])
