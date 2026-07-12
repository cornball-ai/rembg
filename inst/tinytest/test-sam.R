library(rembg)

# registry entry
s <- rembg:::.model_spec("sam")
expect_equal(s$kind, "sam")
expect_true("sam" %in% rembg_models())

# --- bilinear sampling (sample a 2x2 grid at once) ---------------------------
im <- matrix(c(1, 2, 3, 4), 2, 2)          # [1,1]=1 [2,1]=2 [1,2]=3 [2,2]=4
sy <- matrix(c(0, 1, 0.5, 9), 2, 2)        # (0,0) (1,1) (0.5,0.5) (9,9)
sx <- matrix(c(0, 1, 0.5, 9), 2, 2)
res <- rembg:::.bilinear_sample(im, sy, sx)
expect_equal(as.vector(res), c(1, 4, 2.5, 0))   # exact / centre avg / out-of-range 0

# --- affine warp -------------------------------------------------------------
im2 <- matrix(1:6, 2, 3)
m_id <- matrix(c(1, 0, 0, 0, 1, 0), 2, 3, byrow = TRUE)
expect_equal(rembg:::.warp_affine(im2, m_id, 2, 3), im2, tolerance = 1e-9)

# doubling scale then sampling the doubled grid recovers the source pixels
m_scale <- matrix(c(2, 0, 0, 0, 2, 0), 2, 3, byrow = TRUE)
big <- rembg:::.warp_affine(im2, m_scale, 4, 6)
expect_equal(dim(big), c(4L, 6L))
expect_equal(big[1, 1], im2[1, 1])         # dst (0,0) <- src (0,0)
expect_equal(big[3, 5], im2[2, 3])         # dst (4,2)*0.5 -> src (2,1) 0-based

# --- end-to-end (needs runtime + the ~350 MB SAM models) ---------------------
if (at_home() && onnxr::onnx_is_installed()) {
  f <- system.file("extdata", "example.jpg", package = "rembg")
  sess <- new_session("sam")
  expect_true(!is.null(sess$encoder) && !is.null(sess$decoder))
  cut <- rembg(f, session = sess, points = c(144, 96))   # centre of the 288x192 fixture
  expect_equal(dim(cut)[3], 4L)
  expect_true(max(cut[, , 4]) > 0.5)         # segmented something
}
