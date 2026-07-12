library(rembg)

# registry entry
cs <- rembg:::.model_spec("u2net_cloth_seg")
expect_equal(cs$size, 768L)
expect_equal(cs$kind, "cloth")

# argmax over the channel dimension of a (1, C, H, W) output
out <- array(0, c(1, 4, 2, 3))
out[1, 2, 1, 1] <- 5     # pixel (1,1) -> class 1
out[1, 4, 2, 3] <- 9     # pixel (2,3) -> class 3
am <- rembg:::.argmax_channel(out)
expect_equal(dim(am), c(2L, 3L))
expect_equal(am[1, 1], 1L)
expect_equal(am[2, 3], 3L)
expect_equal(am[1, 2], 0L)  # all-zero -> class 0

# vertical stacking of 2D masks
a <- matrix(1, 2, 3); b <- matrix(2, 4, 3)
expect_equal(dim(rembg:::.concat_v(list(a, b))), c(6L, 3L))

# end-to-end (needs runtime + the cloth model)
if (at_home() && onnxr::onnx_is_installed()) {
  f <- system.file("extdata", "example.jpg", package = "rembg")
  sess <- new_session("u2net_cloth_seg")

  up <- rembg(f, session = sess, cloth_category = "upper")
  expect_equal(dim(up)[3], 4L)

  all3 <- rembg(f, session = sess)              # upper + lower + full, stacked
  expect_equal(dim(all3)[1], 3L * dim(up)[1])
  expect_equal(dim(all3)[2], dim(up)[2])

  expect_error(rembg(f, session = sess, cloth_category = "bogus"))
}
