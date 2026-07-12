library(rembg)

# identity resize keeps values and shape
m <- matrix((1:12) / 12, 3, 4)
expect_equal(rembg:::.resize_bilinear(m, 3, 4), m)

# 3-channel resize keeps channel dim
a <- array(0.5, c(4, 6, 3))
r <- rembg:::.resize_bilinear(a, 8, 12)
expect_equal(dim(r), c(8L, 12L, 3L))
expect_true(all(abs(r - 0.5) < 1e-9))          # constant stays constant

# orientation: a white block in the top-left stays top-left (no transpose/flip)
z <- matrix(0, 40, 60); z[1:10, 1:15] <- 1
zr <- rembg:::.resize_bilinear(z, 20, 30)
expect_equal(dim(zr), c(20L, 30L))
expect_true(mean(zr[1:4, 1:6]) > 0.8)          # top-left bright
expect_true(mean(zr[16:20, 25:30]) < 0.05)     # bottom-right dark
