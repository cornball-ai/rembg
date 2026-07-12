# Bilinear resize -------------------------------------------------------------
#
# Base-R replacement for PIL's LANCZOS resize. Bilinear is not bit-identical to
# LANCZOS but produces visually/numerically equivalent masks for this use. Uses
# a pixel-centre coordinate mapping (like PIL's, without align_corners).

# Resize a [h,w] matrix or [h,w,c] array to (out_h, out_w). Values are passed
# through unchanged (interpolated), so it works on [0,1] images and masks alike.
.resize_bilinear <- function(a, out_h, out_w) {
    d2 <- length(dim(a)) == 2L
    if (d2) {
        dim(a) <- c(dim(a), 1L)
    }
    ih <- dim(a)[1]; iw <- dim(a)[2]; nc <- dim(a)[3]
    out_h <- as.integer(out_h) ; out_w <- as.integer(out_w)

    if (ih == out_h && iw == out_w) {
        if (d2) {
            dim(a) <- c(ih, iw)
        }
        return(a)
    }

    sy <- pmin(pmax(((seq_len(out_h) - 0.5) * ih / out_h) + 0.5, 1), ih)
    sx <- pmin(pmax(((seq_len(out_w) - 0.5) * iw / out_w) + 0.5, 1), iw)
    y0 <- floor(sy) ; y1 <- pmin(y0 + 1, ih) ; wy <- sy - y0
    x0 <- floor(sx) ; x1 <- pmin(x0 + 1, iw) ; wx <- sx - x0

    WX <- matrix(wx, out_h, out_w, byrow = TRUE)
    WY <- matrix(wy, out_h, out_w)

    out <- array(0, c(out_h, out_w, nc))
    for (c in seq_len(nc)) {
        m <- a[,, c]; dim(m) <- c(ih, iw)
        f00 <- m[y0, x0]; f01 <- m[y0, x1]; f10 <- m[y1, x0]; f11 <- m[y1, x1]
        out[,, c] <- f00 * (1 - WX) * (1 - WY) + f01 * WX * (1 - WY) +
        f10 * (1 - WX) * WY + f11 * WX * WY
    }
    if (d2 || nc == 1L) {
        dim(out) <- c(out_h, out_w)
    }
    out
}
