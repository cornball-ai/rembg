# Cutout, background colour and mask post-processing ---------------------------

# Build an [h,w,4] RGBA cutout from an [h,w,3] image and an [h,w] mask.
.cutout <- function(img, mask) {
    h <- dim(img)[1]; w <- dim(img)[2]
    rgba <- array(0, c(h, w, 4L))
    rgba[,, 1:3] <- img
    rgba[,, 4] <- mask
    rgba
}

# Stack RGBA arrays vertically (upstream get_concat_v_multi). Used only by the
# multi-mask models that will be added later; single-mask models never hit it.
.concat_v <- function(arrs) {
    if (length(arrs) == 1L) {
        return(arrs[[1]])
    }
    hs <- vapply(arrs, function(a) dim(a)[1], integer(1))
    w <- dim(arrs[[1]])[2]; nc <- dim(arrs[[1]])[3]
    out <- array(0, c(sum(hs), w, nc))
    off <- 0L
    for (a in arrs) {
        hh <- dim(a)[1]
        out[(off + 1):(off + hh),,] <- a
        off <- off + hh
    }
    out
}

# Normalise a colour to length-4 RGBA in [0,1]. Accepts length 3 or 4, in [0,1]
# or 0-255.
.norm_color <- function(color) {
    if (length(color) == 3L) color <- c(color, if (max(color) > 1) 255 else 1)
    if (length(color) != 4L) {
        stop("bgcolor must have 3 or 4 values.", call. = FALSE)
    }
    if (max(color) > 1) {
        color <- color / 255
    }
    color
}

# Composite an [h,w,4] cutout over a solid background colour (upstream
# apply_background_color / PIL alpha_composite). Returns an [h,w,4] array.
.apply_bgcolor <- function(rgba, color) {
    color <- .norm_color(color)
    h <- dim(rgba)[1]; w <- dim(rgba)[2]
    fa <- rgba[,, 4]
    ba <- color[4]
    oa <- fa + ba * (1 - fa)
    safe <- ifelse(oa <= 0, 1, oa)
    out <- array(0, c(h, w, 4L))
    for (c in 1:3) {
        out[,, c] <- (rgba[,, c] * fa + color[c] * ba * (1 - fa)) / safe
    }
    out[,, 4] <- oa
    out
}

# --- mask post-processing (optional; off by default) -------------------------
# Port of upstream post_process: grayscale morphological opening + gaussian blur
# + threshold. Not bit-identical to skimage/scipy but the same operation.

.pad_replicate <- function(m, p = 1L) {
    h <- nrow(m) ; w <- ncol(m)
    m[c(rep(1L, p), 1:h, rep(h, p)), c(rep(1L, p), 1:w, rep(w, p)), drop = FALSE]
}

# Reduce over a plus-shaped 3x3 neighbourhood (skimage disk(1)) with `fun`.
.plus_reduce <- function(m, fun) {
    pm <- .pad_replicate(m, 1L)
    h <- nrow(m) ; w <- ncol(m)
    ctr <- pm[2:(h + 1), 2:(w + 1)]
    up <- pm[1:h, 2:(w + 1)]
    dn <- pm[3:(h + 2), 2:(w + 1)]
    lf <- pm[2:(h + 1), 1:w]
    rt <- pm[2:(h + 1), 3:(w + 2)]
    fun(ctr, up, dn, lf, rt)
}

.gaussian_1d <- function(sigma) {
    r <- as.integer(ceiling(3 * sigma))
    x <- seq.int(-r, r)
    k <- exp(-(x ^ 2) / (2 * sigma ^ 2))
    k / sum(k)
}

.conv_axis <- function(m, k, axis) {
    r <- (length(k) - 1L) / 2L
    h <- nrow(m) ; w <- ncol(m)
    out <- matrix(0, h, w)
    if (axis == 1L) {
        pm <- m[c(rep(1L, r), 1:h, rep(h, r)),, drop = FALSE]
        for (i in seq_along(k)) {
            out <- out + k[i] * pm[i:(i + h - 1L),, drop = FALSE]
        }
    } else {
        pm <- m[, c(rep(1L, r), 1:w, rep(w, r)), drop = FALSE]
        for (i in seq_along(k)) {
            out <- out + k[i] * pm[, i:(i + w - 1L), drop = FALSE]
        }
    }
    out
}

# mask: [h,w] in [0,1]. Returns a binary [h,w] mask in {0,1}.
.post_process <- function(mask) {
    er <- .plus_reduce(mask, function(...) pmin(...)) # erosion
    op <- .plus_reduce(er, function(...) pmax(...)) # dilation -> opening
    k <- .gaussian_1d(2)
    bl <- .conv_axis(.conv_axis(op, k, 1L), k, 2L)
    (bl >= 0.5) * 1
}
