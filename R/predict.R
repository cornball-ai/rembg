# Prediction ------------------------------------------------------------------
#
# Generic, registry-driven port of the per-model predict() methods: normalise,
# run the model, take the first output's first channel, optionally apply a
# sigmoid, min-max normalise to [0,1] and resize back to the source size.
# u2net_cloth_seg uses a separate multi-class path (.predict_cloth).

# session: an rembg_session. img: [h,w,3] in [0,1].
# Returns a list of [h,w] masks in [0,1] (a list to mirror upstream's multi-mask
# models; the salient models each return a single mask).
.session_predict <- function(session, img, cloth_category = NULL,
                             points = NULL, labels = NULL) {
    if (identical(session$spec$kind, "cloth")) {
        return(.predict_cloth(session, img, cloth_category))
    }
    if (identical(session$spec$kind, "sam")) {
        return(.predict_sam(session, img, points, labels))
    }

    spec <- session$spec
    ih <- dim(img)[1]; iw <- dim(img)[2]

    tensor <- .preprocess(img, spec$size, spec$mean, spec$std)
    out <- onnxr::onnx_run(session$onnx, tensor)

    pred <- out[[1]][1, 1,,] # (size, size)
    if (spec$sigmoid) {
        pred <- 1 / (1 + exp(-pred))
    }

    lo <- min(pred) ; hi <- max(pred)
    denom <- hi - lo
    if (denom <= 0) {
        denom <- 1
    }
    pred <- (pred - lo) / denom

    mask <- .resize_bilinear(pred, ih, iw)
    mask <- pmin(pmax(mask, 0), 1)
    list(mask)
}

# Per-pixel argmax over the channel dim of a (1, C, H, W) output; returns an
# H x W integer matrix of 0-based class indices.
.argmax_channel <- function(out) {
    a <- out[1,,,] # (C, H, W)
    cc <- dim(a)[1]
    best <- matrix(0L, dim(a)[2], dim(a)[3])
    bestval <- a[1,,]
    for (c in 2:cc) {
        v <- a[c,,]
        upd <- v > bestval
        best[upd] <- c - 1L
        bestval[upd] <- v[upd]
    }
    best
}

# u2net_cloth_seg: 4-class segmentation (0 bg, 1 upper, 2 lower, 3 full). Returns
# one binary [h,w] mask per requested garment category.
.predict_cloth <- function(session, img, cloth_category = NULL) {
    spec <- session$spec
    ih <- dim(img)[1]; iw <- dim(img)[2]

    tensor <- .preprocess(img, spec$size, spec$mean, spec$std)
    out <- onnxr::onnx_run(session$onnx, tensor)[[1]] # (1, C, S, S)

    cls <- .argmax_channel(out) # S x S, values 0..C-1
    cls_full <- round(.resize_nn(cls + 0, ih, iw)) # nearest keeps class ids

    class_of <- c(upper = 1L, lower = 2L, full = 3L)
    if (is.null(cloth_category)) {
        cats <- names(class_of)
    } else {
        cats <- cloth_category
    }
    lapply(cats, function(cat) {
        k <- class_of[[cat]]
        if (is.null(k)) {
            stop("cloth_category must be one of 'upper', 'lower', 'full'.",
                 call. = FALSE)
        }
        (cls_full == k) * 1
    })
}
