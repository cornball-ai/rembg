# Prediction ------------------------------------------------------------------
#
# Generic, registry-driven port of the per-model predict() methods: normalise,
# run the model, take the first output's first channel, optionally apply a
# sigmoid, min-max normalise to [0,1] and resize back to the source size.

# session: an rembg_session. img: [h,w,3] in [0,1].
# Returns a list of [h,w] masks in [0,1] (a list to mirror upstream's multi-mask
# models; the v0.1 registry models each return a single mask).
.session_predict <- function(session, img) {
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
