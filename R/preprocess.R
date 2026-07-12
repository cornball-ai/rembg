# Preprocessing ---------------------------------------------------------------
#
# Port of BaseSession.normalize: resize to the model input size, scale by the
# global max pixel value, apply per-channel (x - mean) / std, and assemble an
# NCHW float tensor of shape (1, 3, size, size).

# img: [h,w,3] in [0,1]. Returns a double array with dim c(1, 3, size, size).
.preprocess <- function(img, size, mean, std) {
    small <- .resize_bilinear(img, size, size) * 255 # back to 0-255 like rembg
    allmax <- max(max(small), 1e-6)

    tensor <- array(0.0, dim = c(1L, 3L, size, size))
    for (c in 1:3) {
        tensor[1, c,,] <- (small[,, c] / allmax - mean[c]) / std[c]
    }
    tensor
}
