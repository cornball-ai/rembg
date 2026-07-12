library(rembg)

# End-to-end needs the ONNX runtime + a downloaded model, so only run locally
# (skipped during R CMD check via at_home()).
if (at_home() && onnxr::onnx_is_installed()) {
  f <- system.file("extdata", "example.jpg", package = "rembg")
  sess <- new_session("u2netp")
  expect_inherits(sess, "rembg_session")

  cut <- rembg(f, session = sess)
  expect_equal(length(dim(cut)), 3L)
  expect_equal(dim(cut)[3], 4L)
  expect_true(min(cut[, , 4]) < 0.05)          # some fully transparent background
  expect_true(max(cut[, , 4]) > 0.95)          # some fully solid foreground

  mk <- rembg(f, session = sess, only_mask = TRUE)
  expect_equal(length(dim(mk)), 2L)
  expect_equal(dim(mk), dim(cut)[1:2])

  wc <- rembg(f, session = sess, bgcolor = c(255, 255, 255, 255))
  expect_true(all(abs(wc[, , 4] - 1) < 1e-6))  # opaque after bgcolor
}
