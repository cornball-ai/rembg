library(rembg)

# --- binary erosion ----------------------------------------------------------
m <- matrix(TRUE, 5, 5)
e0 <- rembg:::.binary_erode_square(m, 3L, border = FALSE)
expect_false(e0[1, 1])          # edge eroded (outside treated as FALSE)
expect_true(e0[3, 3])           # interior survives
e1 <- rembg:::.binary_erode_square(m, 3L, border = TRUE)
expect_true(all(e1))            # border TRUE -> nothing eroded

# --- trimap ------------------------------------------------------------------
mask <- matrix(0, 10, 10); mask[, 1:5] <- 1                 # left fg, right bg
tri <- rembg:::.build_trimap(mask, 240, 10, 0)
expect_equal(tri[1, 1], 1)      # foreground
expect_equal(tri[1, 10], 0)     # background
expect_true(all(tri %in% c(0, 0.5, 1)))

# --- conjugate gradient ------------------------------------------------------
A <- Matrix::sparseMatrix(i = c(1, 1, 2, 2), j = c(1, 2, 1, 2), x = c(4, 1, 1, 3))
b <- c(1, 2)
expect_equal(rembg:::.cg(A, b), as.numeric(solve(as.matrix(A), b)), tolerance = 1e-5)

# --- nearest-neighbour resize ------------------------------------------------
g <- matrix(1:12, 3, 4)
r <- rembg:::.resize_nn(g, 6, 8)
expect_equal(dim(r), c(6L, 8L))
expect_equal(r[1, 1], g[1, 1])
expect_true(all(r %in% g))      # nearest -> only original values

# --- closed-form alpha on a synthetic edge -----------------------------------
img <- array(0, c(16, 16, 3)); img[, 1:8, ] <- 0.9; img[, 9:16, ] <- 0.1
tri <- matrix(0.5, 16, 16); tri[, 1:4] <- 1; tri[, 13:16] <- 0
alpha <- rembg:::.estimate_alpha_cf(img, tri)
expect_equal(dim(alpha), c(16L, 16L))
expect_true(all(alpha >= 0 & alpha <= 1))
expect_true(all(alpha[, 1:4] > 0.99))     # known foreground preserved
expect_true(all(alpha[, 13:16] < 0.01))   # known background preserved

# --- foreground estimation + full cutout -------------------------------------
fg <- rembg:::.estimate_foreground_ml(img, alpha)
expect_equal(dim(fg), c(16L, 16L, 3L))
expect_true(all(fg >= 0 & fg <= 1))

mask2 <- matrix(0, 16, 16); mask2[, 1:8] <- 1
cut <- rembg:::.alpha_matting_cutout(img, mask2, 240, 10, 2)
expect_equal(dim(cut), c(16L, 16L, 4L))
expect_true(all(cut[, , 4] >= 0 & cut[, , 4] <= 1))

# --- end-to-end (needs runtime + model) --------------------------------------
if (at_home() && onnxr::onnx_is_installed()) {
  f <- system.file("extdata", "example.jpg", package = "rembg")
  sess <- new_session("u2netp")
  am <- rembg(f, session = sess, alpha_matting = TRUE)
  expect_equal(dim(am)[3], 4L)
  expect_true(min(am[, , 4]) < 0.05 && max(am[, , 4]) > 0.95)
  # matting produces genuinely soft edges (intermediate alpha), unlike a hard cut
  expect_true(sum(am[, , 4] > 0.05 & am[, , 4] < 0.95) > 0)
}
