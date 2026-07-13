# Segment Anything (SAM) ------------------------------------------------------
#
# SAM is the outlier: two ONNX models (a heavy image encoder + a light prompt
# decoder) and a click-to-segment interface. You pass point prompts (and/or a
# box) and it returns the mask for that object. Port of rembg's SamSession.

# --- bilinear sampling / affine warp (replaces cv2.warpAffine + map_coordinates)
# Sample `image` [h,w] or [h,w,c] at 0-based coordinates (sy rows, sx cols) with
# bilinear interpolation; out-of-range samples contribute 0 (mode="constant").
.bilinear_sample <- function(image, sy, sx) {
    is2d <- length(dim(image)) == 2L
    if (is2d) {
        image <- array(image, c(dim(image), 1L))
    }
    h <- dim(image)[1]; w <- dim(image)[2]; nc <- dim(image)[3]
    oh <- nrow(sy) ; ow <- ncol(sy)
    x0 <- floor(sx) ; y0 <- floor(sy)
    wx <- sx - x0; wy <- sy - y0
    corners <- list(list(y0, x0, (1 - wx) * (1 - wy)),
                    list(y0, x0 + 1, wx * (1 - wy)),
                    list(y0 + 1, x0, (1 - wx) * wy),
                    list(y0 + 1, x0 + 1, wx * wy))
    out <- array(0, c(oh, ow, nc))
    for (cn in corners) {
        yy <- cn[[1]]; xx <- cn[[2]]; wgt <- cn[[3]]
        inb <- yy >= 0 & yy < h & xx >= 0 & xx < w
        if (!any(inb)) {
            next
        }
        lin <- xx[inb] * h + yy[inb] + 1L # column-major index (0-based -> 1-based)
        ww <- wgt[inb]
        for (c in seq_len(nc)) {
            contrib <- numeric(oh * ow)
            contrib[which(inb)] <- image[,, c][lin] * ww
            out[,, c] <- out[,, c] + matrix(contrib, oh, ow)
        }
    }
    if (is2d || nc == 1L) {
        out[,, 1]
    } else {
        out
    }
}

# Affine warp matching the upstream helper: dst(M %*% [x,y,1]) = src(x,y).
.warp_affine <- function(image, m, out_h, out_w) {
    m_inv <- solve(rbind(m, c(0, 0, 1)))[1:2,, drop = FALSE]
    xg <- matrix(0:(out_w - 1), out_h, out_w, byrow = TRUE)
    yg <- matrix(0:(out_h - 1), out_h, out_w)
    src_x <- m_inv[1, 1] * xg + m_inv[1, 2] * yg + m_inv[1, 3]
    src_y <- m_inv[2, 1] * xg + m_inv[2, 2] * yg + m_inv[2, 3]
    .bilinear_sample(image, src_y, src_x)
}

# Download the encoder + decoder ONNX files (no checksums upstream). Returns a
# length-2 list of paths.
.ensure_sam_models <- function(spec, quiet = FALSE) {
    home <- model_home()
    files <- paste0(spec$file, c(".encoder.onnx", ".decoder.onnx"))
    paths <- file.path(home, files)
    if (!all(file.exists(paths))) {
        .download_consent(home, "the SAM encoder + decoder (~350 MB)")
        if (!dir.exists(home)) {
            dir.create(home, recursive = TRUE, showWarnings = FALSE)
        }
    }
    for (i in 1:2) {
        if (!file.exists(paths[i])) {
            if (!quiet) {
                message(sprintf("Downloading SAM model '%s' ...", files[i]))
            }
            tmp <- paste0(paths[i], ".part")
            utils::download.file(paste0(.base_url, files[i]), tmp,
                                 mode = "wb", quiet = quiet)
            file.rename(tmp, paths[i])
        }
    }
    as.list(paths)
}

# session: an rembg_session with $encoder and $decoder. img: [h,w,3] in [0,1].
# points: a length-2 c(x, y) or an N x 2 matrix of (x, y) pixel coords in the
# original image; labels: 1 = foreground, 0 = background (default all 1).
# Returns a list holding one binary [h,w] mask.
.predict_sam <- function(session, img, points = NULL, labels = NULL) {
    ih <- dim(img)[1]; iw <- dim(img)[2]
    if (is.null(points)) {
        points <- matrix(c(iw / 2, ih / 2), 1, 2)
        labels <- 1
    }
    points <- matrix(points, ncol = 2)
    if (is.null(labels)) {
        labels <- rep(1, nrow(points))
    }

    input_h <- 684L; input_w <- 1024L
    scale <- min(input_w / iw, input_h / ih)
    tm <- matrix(c(scale, 0, 0, 0, scale, 0, 0, 0, 1), 3, 3, byrow = TRUE)

    ## encoder: warp image into a 684x1024 canvas, feed 0-255 HWC
    warped <- .warp_affine(round(img * 255), tm[1:2,, drop = FALSE], input_h,
                           input_w)
    emb <- onnxr::onnx_run(session$encoder, warped)[[1]]

    ## decoder point prompt: add the padding point (0,0)/label -1, scale to canvas
    coords <- rbind(points, c(0, 0))
    labs <- c(labels, -1)
    coord_xy <- (cbind(coords, 1) %*% t(tm))[, 1:2, drop = FALSE]
    n <- nrow(coord_xy)

    dec <- onnxr::onnx_run(
                           session$decoder,
                           image_embeddings = emb,
                           point_coords = array(coord_xy, c(1L, n, 2L)),
                           point_labels = array(labs, c(1L, n)),
                           mask_input = array(0, c(1L, 1L, 256L, 256L)),
                           has_mask_input = array(0, 1L),
                           orig_im_size = array(c(input_h, input_w), 2L)
    )
    masks <- dec[[1]] # (1, M, 684, 1024) logits

    ## warp each mask back to the original size and union where positive
    inv_tm <- solve(tm)[1:2,, drop = FALSE]
    acc <- matrix(0, ih, iw)
    for (mi in seq_len(dim(masks)[2])) {
        warped_back <- .warp_affine(masks[1, mi,,], inv_tm, ih, iw)
        acc <- pmax(acc, (warped_back > 0) * 1)
    }
    list(acc)
}
