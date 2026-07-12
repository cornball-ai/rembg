# Model registry --------------------------------------------------------------
#
# Every model in v0.1.0 follows one generic predict pattern (see predict.R) and
# differs only in: input size, normalisation mean/std, whether a sigmoid is
# applied to the raw output, the download file name and its checksum. So instead
# of one class per model (as upstream), we keep a single table.

# ImageNet normalisation, shared by most models
.imagenet_mean <- c(0.485, 0.456, 0.406)
.imagenet_std <- c(0.229, 0.224, 0.225)

.base_url <- "https://github.com/danielgatis/rembg/releases/download/v0.0.0/"

# One registry entry. `kind` selects the predict path: "salient" (the generic
# single-mask models) or "cloth" (u2net_cloth_seg's multi-class garment masks).
.model <- function(size, mean, std, sigmoid, file, checksum, kind = "salient") {
    list(size = as.integer(size), mean = mean, std = std,
         sigmoid = isTRUE(sigmoid), file = file, checksum = checksum,
         kind = kind)
}

# name -> spec. `checksum` is "md5:..." or "sha256:...".
.MODELS <- list(
                "u2net" = .model(320, .imagenet_mean, .imagenet_std, FALSE,
                                 "u2net.onnx", "md5:60024c5c889badc19c04ad937298a77b"),
                "u2netp" = .model(320, .imagenet_mean, .imagenet_std, FALSE,
                                  "u2netp.onnx", "md5:8e83ca70e441ab06c318d82300c84806"),
                "u2net_human_seg" = .model(320, .imagenet_mean, .imagenet_std, FALSE,
        "u2net_human_seg.onnx", "md5:c09ddc2e0104f800e3e1bb4652583d1f"),
                "silueta" = .model(320, .imagenet_mean, .imagenet_std, FALSE,
                                   "silueta.onnx", "md5:55e59e0d8062d2f5d013f4725ee84782"),
                "isnet-general-use" = .model(1024, c(0.5, 0.5, 0.5), c(1, 1, 1), FALSE,
        "isnet-general-use.onnx", "md5:fc16ebd8b0c10d971d3513d564d01e29"),
                "isnet-anime" = .model(1024, .imagenet_mean, c(1, 1, 1), FALSE,
                                       "isnet-anime.onnx", "md5:6f184e756bb3bd901c8849220a83e38e"),
                "birefnet-general" = .model(1024, .imagenet_mean, .imagenet_std, TRUE,
        "BiRefNet-general-epoch_244.onnx", "md5:7a35a0141cbbc80de11d9c9a28f52697"),
                "birefnet-general-lite" = .model(1024, .imagenet_mean, .imagenet_std, TRUE,
        "BiRefNet-general-bb_swin_v1_tiny-epoch_232.onnx", "md5:4fab47adc4ff364be1713e97b7e66334"),
                "birefnet-portrait" = .model(1024, .imagenet_mean, .imagenet_std, TRUE,
        "BiRefNet-portrait-epoch_150.onnx", "md5:c3a64a6abf20250d090cd055f12a3b67"),
                "birefnet-dis" = .model(1024, .imagenet_mean, .imagenet_std, TRUE,
                                        "BiRefNet-DIS-epoch_590.onnx", "md5:2d4d44102b446f33a4ebb2e56c051f2b"),
                "birefnet-hrsod" = .model(1024, .imagenet_mean, .imagenet_std, TRUE,
        "BiRefNet-HRSOD_DHU-epoch_115.onnx", "md5:c017ade5de8a50ff0fd74d790d268dda"),
                "birefnet-cod" = .model(1024, .imagenet_mean, .imagenet_std, TRUE,
                                        "BiRefNet-COD-epoch_125.onnx", "md5:f6d0d21ca89d287f17e7afe9f5fd3b45"),
                "birefnet-massive" = .model(1024, .imagenet_mean, .imagenet_std, TRUE,
        "BiRefNet-massive-TR_DIS5K_TR_TEs-epoch_420.onnx", "md5:33e726a2136a3d59eb0fdf613e31e3e9"),
                "bria-rmbg" = .model(1024, .imagenet_mean, .imagenet_std, FALSE,
                                     "bria-rmbg-2.0.onnx", "sha256:5b486f08200f513f460da46dd701db5fbb47d79b4be4b708a19444bcd4e79958"),
                "u2net_cloth_seg" = .model(768, .imagenet_mean, .imagenet_std, FALSE,
        "u2net_cloth_seg.onnx", "md5:2434d1f3cb744e0e49386c906e5a08bb",
        kind = "cloth"),
                "sam" = .model(1024, .imagenet_mean, .imagenet_std, FALSE,
                               "sam_vit_b_01ec64", "none", kind = "sam")
)

#' Available background-removal models
#'
#' Returns the names of the segmentation models that [new_session()] and
#' [rembg()] can use. Models are downloaded on first use.
#'
#' @return A character vector of model names.
#' @examples
#' rembg_models()
#' @export
rembg_models <- function() names(.MODELS)

# Look up a spec or stop with a helpful message.
.model_spec <- function(model) {
    spec <- .MODELS[[model]]
    if (is.null(spec)) {
        stop(sprintf("Unknown model '%s'. Available models: %s", model,
                     paste(names(.MODELS), collapse = ", ")), call. = FALSE)
    }
    spec
}
