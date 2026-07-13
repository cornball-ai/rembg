library(rembg)

# model_home honours U2NET_HOME, else falls back to R_user_dir
old <- Sys.getenv("U2NET_HOME", unset = NA)
Sys.setenv(U2NET_HOME = "/tmp/rembg_home_dl_test")
expect_equal(model_home(), "/tmp/rembg_home_dl_test")
Sys.unsetenv("U2NET_HOME")
expect_true(grepl("rembg", model_home()))              # R_user_dir default
if (!is.na(old)) Sys.setenv(U2NET_HOME = old)

# --- download consent gate ---------------------------------------------------
tmp <- file.path(tempdir(), "rembg_consent_test")
unlink(tmp, recursive = TRUE)

# tests run non-interactively: a fresh cache dir needs explicit opt-in
expect_error(rembg:::.download_consent(tmp, "model 'x'"))

# pre-consent via option
op <- options(rembg.download = TRUE)
expect_true(rembg:::.download_consent(tmp, "model 'x'"))
options(op)

# pre-consent via environment variable
Sys.setenv(REMBG_DOWNLOAD = "1")
expect_true(rembg:::.download_consent(tmp, "model 'x'"))
Sys.unsetenv("REMBG_DOWNLOAD")

# an existing cache dir counts as prior acknowledgement (no prompt)
dir.create(tmp, recursive = TRUE, showWarnings = FALSE)
expect_true(rembg:::.download_consent(tmp, "model 'x'"))
unlink(tmp, recursive = TRUE)
