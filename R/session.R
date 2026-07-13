# Session ---------------------------------------------------------------------

#' Create a background-removal session
#'
#' Loads a segmentation model (downloading it on first use) and returns a session
#' object that [rembg()] can reuse across many images. Building the session once
#' and passing it to [rembg()] avoids re-loading the model each call.
#'
#' @param model Model name; see [rembg_models()]. Defaults to \code{"u2net"}. The
#'   \code{"u2net_custom"}, \code{"dis_custom"} and \code{"ben_custom"} presets
#'   run your own local \code{.onnx} (via \code{model_path}) through a fixed
#'   preprocessing profile.
#' @param backend ONNX Runtime execution backend passed to
#'   [onnxr::onnx_model()]: \code{"cpu"} (default), \code{"cuda"} (NVIDIA GPU,
#'   needs a CUDA runtime build), or \code{"coreml"} (macOS).
#' @param model_path Optional path to a local \code{.onnx} file to run instead of
#'   a downloaded model (bring-your-own-model). Required for the \code{*_custom}
#'   presets; when set, \code{model} selects the preprocessing profile.
#' @param size Input size (pixels) for a custom \code{model_path}; defaults to the
#'   profile of \code{model} (320 for a bare \code{model_path}).
#' @param mean Length-3 per-channel normalisation mean for a custom
#'   \code{model_path}; defaults to the profile of \code{model}.
#' @param std Length-3 per-channel normalisation standard deviation for a custom
#'   \code{model_path}; defaults to the profile of \code{model}.
#' @param ... Reserved for future use.
#'
#' @return An object of class \code{"rembg_session"}.
#' @seealso [rembg()], [rembg_models()]
#' @examples
#' \donttest{
#' # interactive() guard: new_session() downloads the model on first use
#' if (interactive() && onnxr::onnx_is_installed()) {
#'   sess <- new_session("u2netp")
#'   sess
#'   # bring your own model:
#'   # new_session("u2net_custom", model_path = "~/.u2net/my_model.onnx")
#' }
#' }
#' @export
new_session <- function(model = "u2net",
                        backend = c("cpu", "cuda", "coreml"),
                        model_path = NULL, size = NULL, mean = NULL,
                        std = NULL, ...) {
    backend <- match.arg(backend)

    if (!onnxr::onnx_is_installed()) {
        stop("ONNX Runtime shared library not found. Run `onnxr::onnx_install()` ",
             "once to install it, then retry.", call. = FALSE)
    }

    # Bring-your-own-model: run a local .onnx through a preprocessing profile,
    # taken from a *_custom preset or from explicit size/mean/std.
    is_custom_name <- model %in% names(.MODELS) &&
    identical(.MODELS[[model]]$kind, "custom")
    if (!is.null(model_path) || is_custom_name) {
        if (is.null(model_path)) {
            stop("Model '", model,
                 "' is a custom model; pass `model_path` to a ",
                 "local .onnx file.", call. = FALSE)
        }
        path <- path.expand(model_path)
        if (!file.exists(path)) {
            stop("model_path not found: ", model_path, call. = FALSE)
        }
        prof <- if (is_custom_name) {
            .MODELS[[model]]
        } else {
            list(size = 320L, mean = .imagenet_mean, std = .imagenet_std)
        }
        spec <- .model(
            if (is.null(size)) prof$size else size,
            if (is.null(mean)) prof$mean else mean,
            if (is.null(std)) prof$std else std,
                       FALSE, basename(path), "none", kind = "custom"
        )
        return(structure(
                         list(model = if (is_custom_name) {
                        model
                    } else {
                        "custom"
                    }, spec = spec,
                              backend = backend, path = path,
                              onnx = onnxr::onnx_model(path, backend = backend)),
                         class = "rembg_session"
            ))
    }

    spec <- .model_spec(model)

    # SAM loads two models (encoder + decoder) instead of one.
    if (identical(spec$kind, "sam")) {
        paths <- .ensure_sam_models(spec)
        return(structure(
                         list(model = model, spec = spec, backend = backend,
                              encoder = onnxr::onnx_model(paths[[1]], backend = backend),
                              decoder = onnxr::onnx_model(paths[[2]], backend = backend)),
                         class = "rembg_session"
            ))
    }

    path <- .ensure_model(model)
    onnx <- onnxr::onnx_model(path, backend = backend)

    structure(
              list(model = model, spec = spec, backend = backend, path = path,
                   onnx = onnx),
              class = "rembg_session"
    )
}

#' @export
print.rembg_session <- function(x, ...) {
    cat("<rembg_session>\n")
    cat("  model:   ", x$model, "\n", sep = "")
    if (identical(x$spec$kind, "sam")) {
        cat("  models:  encoder + decoder (click-to-segment)\n", sep = "")
    } else {
        cat("  input:   ", x$spec$size, "x", x$spec$size, "\n", sep = "")
    }
    cat("  backend: ", x$backend, "\n", sep = "")
    invisible(x)
}
