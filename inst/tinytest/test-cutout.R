library(rembg)

img  <- array(0.3, c(5, 7, 3))
mask <- matrix(seq(0, 1, length.out = 35), 5, 7)

cut <- rembg:::.cutout(img, mask)
expect_equal(dim(cut), c(5L, 7L, 4L))
expect_equal(cut[, , 4], mask)
expect_equal(cut[, , 1], img[, , 1])

# opaque background -> fully opaque result; transparent areas take bg colour
bc <- rembg:::.apply_bgcolor(cut, c(255, 255, 255, 255))
expect_true(all(abs(bc[, , 4] - 1) < 1e-9))
expect_true(all(abs(bc[1, 1, 1:3] - 1) < 1e-9))       # mask==0 corner -> white

# colour normalisation
expect_equal(rembg:::.norm_color(c(255, 0, 0)), c(1, 0, 0, 1))
expect_equal(rembg:::.norm_color(c(0, 0, 0, 0.5)), c(0, 0, 0, 0.5))
expect_error(rembg:::.norm_color(c(1, 2)))

# post_process yields a binary mask of the same shape
pp <- rembg:::.post_process(mask)
expect_equal(dim(pp), c(5L, 7L))
expect_true(all(pp %in% c(0, 1)))

# vertical concat stacks heights
a <- array(0.2, c(3, 4, 4)); b <- array(0.8, c(2, 4, 4))
expect_equal(dim(rembg:::.concat_v(list(a, b))), c(5L, 4L, 4L))
