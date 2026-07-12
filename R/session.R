# Session ---------------------------------------------------------------------

#' Create a background-removal session
#'
#' Loads a segmentation model (downloading it on first use) and returns a session
#' object that [rembg()] can reuse across many images. Building the session once
#' and passing it to [rembg()] avoids re-loading the model each call.
#'
#' @param model Model name; see [rembg_models()]. Defaults to \code{"u2net"}.
#' @param backend ONNX Runtime execution backend passed to
#'   [onnxr::onnx_model()]: \code{"cpu"} (default), \code{"cuda"} (NVIDIA GPU,
#'   needs a CUDA runtime build), or \code{"coreml"} (macOS).
#' @param ... Reserved for future use.
#'
#' @return An object of class \code{"rembg_session"}.
#' @seealso [rembg()], [rembg_models()]
#' @examples
#' \donttest{
#' if (onnxr::onnx_is_installed()) {
#'   sess <- new_session("u2netp")
#'   sess
#' }
#' }
#' @export
new_session <- function(model = "u2net",
                        backend = c("cpu", "cuda", "coreml"), ...) {
    backend <- match.arg(backend)
    spec <- .model_spec(model)

    if (!onnxr::onnx_is_installed()) {
        stop("ONNX Runtime shared library not found. Run `onnxr::onnx_install()` ",
             "once to install it, then retry.", call. = FALSE)
    }

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
