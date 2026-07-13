library(rembg)

# registry completeness
expect_equal(length(rembg_models()), 19L)
expect_true(all(c("u2net", "u2netp", "silueta", "isnet-general-use",
                  "birefnet-general", "bria-rmbg", "u2net_cloth_seg", "sam",
                  "u2net_custom", "dis_custom", "ben_custom") %in% rembg_models()))

# spec lookup and shape
expect_error(rembg:::.model_spec("does-not-exist"))
u <- rembg:::.model_spec("u2net")
expect_equal(u$size, 320L)
expect_false(u$sigmoid)

isn <- rembg:::.model_spec("isnet-general-use")
expect_equal(isn$size, 1024L)
expect_equal(isn$std, c(1, 1, 1))

expect_true(rembg:::.model_spec("birefnet-general")$sigmoid)
expect_equal(substr(rembg:::.model_spec("bria-rmbg")$checksum, 1, 6), "sha256")

# model_home honours U2NET_HOME
old <- Sys.getenv("U2NET_HOME", unset = NA)
Sys.setenv(U2NET_HOME = "/tmp/rembg_home_test")
expect_equal(model_home(), "/tmp/rembg_home_test")
if (is.na(old)) Sys.unsetenv("U2NET_HOME") else Sys.setenv(U2NET_HOME = old)
