# Alpha matting ---------------------------------------------------------------
#
# Port of the pymatting pieces rembg uses for `alpha_matting = TRUE`:
#   * a trimap built from the mask (foreground/background thresholds + erosion),
#   * closed-form alpha matting (Levin et al.) solved on the unknown band only
#     via a Jacobi-preconditioned conjugate gradient, and
#   * multi-level foreground colour estimation (Germer et al.).
# Everything works on [h,w,3] / [h,w] arrays in [0,1]; needs the Matrix package
# for the sparse Laplacian.

# --- binary erosion by an s x s all-ones structuring element -----------------
# Matches scipy.ndimage.binary_erosion: origin 0 (window offset -floor(s/2) ..
# ceil(s/2)-1); `border` is the assumed value outside the image.
.binary_erode_square <- function(m, size, border = FALSE) {
    h <- nrow(m) ; w <- ncol(m)
    lo <- size %/% 2L; hi <- size - 1L - lo
    mp <- rbind(matrix(border, lo, w), m, matrix(border, hi, w))
    mp <- cbind(matrix(border, nrow(mp), lo), mp, matrix(border, nrow(mp), hi))
    e <- matrix(TRUE, h, w)
    for (dy in 0:(size - 1L)) {
        for (dx in 0:(size - 1L)) {
            e <- e & mp[(1:h) + dy, (1:w) + dx]
        }
    }
    e
}

# Build a trimap (values 0 / 0.5 / 1) from a mask in [0,1]. Thresholds are in the
# 0-255 domain to match rembg's defaults (fg 240, bg 10, erode 10).
.build_trimap <- function(mask, fg_thr, bg_thr, erode) {
    m255 <- mask * 255
    is_fg <- m255 > fg_thr
    is_bg <- m255 < bg_thr
    if (erode > 0) {
        is_fg <- .binary_erode_square(is_fg, erode, border = FALSE)
        is_bg <- .binary_erode_square(is_bg, erode, border = TRUE)
    }
    trimap <- matrix(0.5, nrow(mask), ncol(mask))
    trimap[is_fg] <- 1
    trimap[is_bg] <- 0
    trimap
}

# --- closed-form matting Laplacian -------------------------------------------
# Builds the sparse n x n matting Laplacian, computing contributions only from
# 3x3 windows that touch an unknown pixel (the rest are never used). Pixel ids
# are column-major: id(y, x) = (x - 1) * h + y.
.cf_laplacian <- function(image, is_unknown, epsilon = 1e-7) {
    h <- dim(image)[1]; w <- dim(image)[2]
    n <- h * w
    wa <- 9 # window area, radius 1

    # window centres (interior) whose 3x3 neighbourhood contains an unknown pixel
    up <- rbind(FALSE, is_unknown[-h,, drop = FALSE])
    dn <- rbind(is_unknown[-1,, drop = FALSE], FALSE)
    dil <- is_unknown | up | dn
    dil <- dil | cbind(FALSE, dil[, -w, drop = FALSE]) |
    cbind(dil[, -1, drop = FALSE], FALSE)
    interior <- matrix(FALSE, h, w)
    interior[2:(h - 1), 2:(w - 1)] <- TRUE
    centres <- which(dil & interior)
    if (length(centres) == 0L) return(Matrix::sparseMatrix(i = integer(0),
            j = integer(0), x = numeric(0), dims = c(n, n)))
    yc <- ((centres - 1L) %% h) + 1L
    xc <- ((centres - 1L) %/% h) + 1L
    k <- length(centres)

    # gather the 9 window pixels: colours (K x 9 per channel) and ids (K x 9)
    offs <- expand.grid(dy = -1:1, dx = -1:1)
    P <- list(matrix(0, k, 9), matrix(0, k, 9), matrix(0, k, 9))
    ID <- matrix(0L, k, 9)
    for (o in 1:9) {
        yo <- yc + offs$dy[o]; xo <- xc + offs$dx[o]
        ID[, o] <- (xo - 1L) * h + yo
        for (c in 1:3) {
            P[[c]][, o] <- image[cbind(yo, xo, c)]
        }
    }
    # centred window colours
    C <- lapply(P, function(pc) pc - rowMeans(pc))

    # per-window 3x3 colour covariance (+ epsilon) and its inverse (closed form)
    s00 <- rowSums(C[[1]] * C[[1]]) ; s01 <- rowSums(C[[1]] * C[[2]]) ; s02 <- rowSums(C[[1]] * C[[3]])
    s11 <- rowSums(C[[2]] * C[[2]]) ; s12 <- rowSums(C[[2]] * C[[3]]) ; s22 <- rowSums(C[[3]] * C[[3]])
    a00 <- (s00 + epsilon) / wa; a01 <- s01 / wa; a02 <- s02 / wa
    a11 <- (s11 + epsilon) / wa; a12 <- s12 / wa; a22 <- (s22 + epsilon) / wa
    det <- a00 * a12 * a12 + a01 * a01 * a22 + a02 * a02 * a11 -
    a00 * a11 * a22 - 2 * a01 * a02 * a12
    inv <- 1 / det
    m00 <- (a12 * a12 - a11 * a22) * inv; m01 <- (a01 * a22 - a02 * a12) * inv
    m02 <- (a02 * a11 - a01 * a12) * inv; m11 <- (a02 * a02 - a00 * a22) * inv
    m12 <- (a00 * a12 - a01 * a02) * inv; m22 <- (a01 * a01 - a00 * a11) * inv

    # Q = Sigma^-1 C  (K x 9 per channel)
    Q0 <- m00 * C[[1]] + m01 * C[[2]] + m02 * C[[3]]
    Q1 <- m01 * C[[1]] + m11 * C[[2]] + m12 * C[[3]]
    Q2 <- m02 * C[[1]] + m12 * C[[2]] + m22 * C[[3]]

    # scatter the 9x9 window Laplacian:  L_op = [o==p] - (1 + c_o^T Sigma^-1 c_p)/wa
    rows <- integer(81 * k) ; cols <- integer(81 * k) ; vals <- numeric(81 * k)
    t <- 0L
    for (o in 1:9) {
        for (p in 1:9) {
            temp <- C[[1]][, o] * Q0[, p] + C[[2]][, o] * Q1[, p] + C[[3]][, o] * Q2[, p]
            value <- (if (o == p) 1 else 0) - (1 + temp) / wa
            idx <- (t * k + 1L):((t + 1L) * k)
            rows[idx] <- ID[, o]; cols[idx] <- ID[, p]; vals[idx] <- value
            t <- t + 1L
        }
    }
    Matrix::sparseMatrix(i = rows, j = cols, x = vals, dims = c(n, n)) # sums duplicates
}

# Jacobi-preconditioned conjugate gradient for A x = b (A sparse SPD).
.cg <- function(A, b, rtol = 1e-6, maxiter = 5000) {
    d <- Matrix::diag(A) ; d[d == 0] <- 1
    minv <- 1 / d
    x <- numeric(length(b))
    normb <- sqrt(sum(b * b)) ; if (normb == 0) normb <- 1
    r <- b
    z <- minv * r
    p <- z
    rz <- sum(r * z)
    for (it in 1:maxiter) {
        Ap <- as.numeric(A %*% p)
        alpha <- rz / sum(p * Ap)
        x <- x + alpha * p
        r <- r - alpha * Ap
        if (sqrt(sum(r * r)) < rtol * normb) {
            break
        }
        z <- minv * r
        rz_new <- sum(r * z)
        p <- z + (rz_new / rz) * p
        rz <- rz_new
    }
    x
}

# Closed-form alpha from an image and trimap (both in [0,1]); solves the unknown
# band only (Grady's reduced system).
.estimate_alpha_cf <- function(image, trimap) {
    h <- dim(image)[1]; w <- dim(image)[2]
    is_fg <- as.vector(trimap) >= 0.9
    is_bg <- as.vector(trimap) <= 0.1
    is_known <- is_fg | is_bg
    is_unknown <- !is_known
    if (!any(is_bg) || !any(is_fg) || !any(is_unknown)) {
        stop("trimap has no unknown / foreground / background region",
             call. = FALSE)
    }

    L <- .cf_laplacian(image, matrix(is_unknown, h, w))
    uidx <- which(is_unknown) ; kidx <- which(is_known)
    L_U <- L[uidx, uidx, drop = FALSE]
    R <- L[uidx, kidx, drop = FALSE]
    m <- as.numeric(is_fg[kidx])
    x_u <- .cg(L_U, -as.numeric(R %*% m))

    alpha <- as.numeric(is_fg) # 1 at fg, 0 at bg
    alpha[uidx] <- x_u
    matrix(pmin(pmax(alpha, 0), 1), h, w)
}

# --- multi-level foreground estimation ---------------------------------------
.resize_nn <- function(src, oh, ow) {
    ih <- dim(src)[1]; iw <- dim(src)[2]
    ys <- pmin(pmax(floor((0:(oh - 1)) * ih / oh) + 1L, 1L), ih)
    xs <- pmin(pmax(floor((0:(ow - 1)) * iw / ow) + 1L, 1L), iw)
    if (length(dim(src)) == 3L) {
        src[ys, xs,, drop = FALSE]
    } else {
        src[ys, xs, drop = FALSE]
    }
}

.estimate_foreground_ml <- function(image, alpha, regularization = 1e-5,
                                    n_small = 10L, n_big = 2L,
                                    small_size = 32L, gradient_weight = 1) {
    h0 <- dim(image)[1]; w0 <- dim(image)[2]
    fg <- alpha > 0.9; bg <- alpha < 0.1
    fmean <- vapply(1:3, function(c) sum(image[,, c][fg]) / (sum(fg) + 1e-5),
                    numeric(1))
    bmean <- vapply(1:3, function(c) sum(image[,, c][bg]) / (sum(bg) + 1e-5), numeric(1))
    F_prev <- array(rep(fmean, each = 1), c(1, 1, 3))
    B_prev <- array(rep(bmean, each = 1), c(1, 1, 3))

    n_levels <- max(1L, as.integer(ceiling(log2(max(w0, h0)))))
    clampshift <- function(idx, n) pmin(pmax(idx, 1L), n)

    for (il in 0:n_levels) {
        ww <- round(w0 ^ (il / n_levels)) ; hh <- round(h0 ^ (il / n_levels))
        img <- .resize_nn(image, hh, ww)
        al <- .resize_nn(alpha, hh, ww)
        Fc <- .resize_nn(F_prev, hh, ww)
        Bc <- .resize_nn(B_prev, hh, ww)
        if (ww <= small_size && hh <= small_size) {
            n_iter <- n_small
        } else {
            n_iter <- n_big
        }

        a0 <- al; a1 <- 1 - a0
        a01 <- a0 * a1
        rows <- 1:hh; cols <- 1:ww
        nb <- list(c(0L, -1L), c(0L, 1L), c(-1L, 0L), c(1L, 0L)) # dx/dy pairs (dy,dx)

        for (iter in seq_len(n_iter)) {
            a00 <- a0 * a0; a11 <- a1 * a1
            b0 <- array(0, c(hh, ww, 3)) ; b1 <- array(0, c(hh, ww, 3))
            for (c in 1:3) { b0[,, c] <- a0 * img[,, c]; b1[,, c] <- a1 * img[,, c] }
            for (s in nb) {
                ry <- clampshift(rows + s[1], hh) ; cx <- clampshift(cols + s[2], ww)
                grad <- abs(a0 - al[ry, cx, drop = FALSE])
                da <- regularization + gradient_weight * grad
                a00 <- a00 + da; a11 <- a11 + da
                for (c in 1:3) {
                    b0[,, c] <- b0[,, c] + da * Fc[ry, cx, c]
                    b1[,, c] <- b1[,, c] + da * Bc[ry, cx, c]
                }
            }
            det <- a00 * a11 - a01 * a01; idet <- 1 / det
            for (c in 1:3) {
                Fc[,, c] <- pmin(pmax(idet * (a11 * b0[,, c] - a01 * b1[,, c]), 0), 1)
                Bc[,, c] <- pmin(pmax(idet * (a00 * b1[,, c] - a01 * b0[,, c]), 0), 1)
            }
        }
        F_prev <- Fc; B_prev <- Bc
    }
    F_prev
}

# --- public-ish cutout -------------------------------------------------------
# image [h,w,3] in [0,1], mask [h,w] in [0,1]; returns [h,w,4] RGBA in [0,1].
.alpha_matting_cutout <- function(image, mask, fg_thr, bg_thr, erode) {
    trimap <- .build_trimap(mask, fg_thr, bg_thr, erode)
    alpha <- .estimate_alpha_cf(image, trimap)
    fg <- .estimate_foreground_ml(image, alpha)
    rgba <- array(0, c(dim(image)[1], dim(image)[2], 4L))
    rgba[,, 1:3] <- fg
    rgba[,, 4] <- alpha
    rgba
}
