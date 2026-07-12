library(rembg)

mean <- c(0.485, 0.456, 0.406)
std  <- c(0.229, 0.224, 0.225)

img <- array(0.5, c(10, 20, 3))                 # constant mid-grey
tt <- rembg:::.preprocess(img, 32L, mean, std)

expect_equal(dim(tt), c(1L, 3L, 32L, 32L))
expect_equal(typeof(tt), "double")

# constant image -> global max == every pixel, so ratio 1; channel value = (1-mean)/std
expect_equal(as.numeric(tt[1, 1, 1, 1]), (1 - mean[1]) / std[1], tolerance = 1e-6)
expect_equal(as.numeric(tt[1, 2, 5, 5]), (1 - mean[2]) / std[2], tolerance = 1e-6)
expect_equal(as.numeric(tt[1, 3, 9, 9]), (1 - mean[3]) / std[3], tolerance = 1e-6)
