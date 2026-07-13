library(rembg)

# the three presets, two profiles
for (nm in c("u2net_custom", "dis_custom", "ben_custom")) {
  expect_equal(rembg:::.model_spec(nm)$kind, "custom")
}
expect_equal(rembg:::.model_spec("u2net_custom")$size, 320L)
expect_equal(rembg:::.model_spec("u2net_custom")$mean, c(0.485, 0.456, 0.406))
expect_equal(rembg:::.model_spec("dis_custom")$size, 1024L)
expect_equal(rembg:::.model_spec("dis_custom")$mean, c(0.5, 0.5, 0.5))
expect_equal(rembg:::.model_spec("ben_custom")$std, c(1, 1, 1))

# end-to-end (needs runtime + a cached model to reuse as a "custom" model)
if (at_home() && onnxr::onnx_is_installed()) {
  expect_error(new_session("u2net_custom"))                 # model_path required
  expect_error(new_session(model_path = "/no/such/model.onnx"))

  mp <- file.path(model_home(), "u2netp.onnx")
  if (file.exists(mp)) {
    f <- system.file("extdata", "example.jpg", package = "rembg")
    # u2net_custom profile == the u2netp profile, so feeding u2netp.onnx matches
    a <- rembg(f, session = new_session("u2net_custom", model_path = mp))
    b <- rembg(f, session = new_session("u2netp"))
    expect_equal(a, b, tolerance = 1e-6)

    # explicit-profile escape hatch (no preset name)
    sess <- new_session(model_path = mp, size = 320,
                        mean = c(0.485, 0.456, 0.406), std = c(0.229, 0.224, 0.225))
    expect_inherits(sess, "rembg_session")
    expect_equal(sess$model, "custom")
    expect_equal(rembg(f, session = sess), b, tolerance = 1e-6)
  }
}
