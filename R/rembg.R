# Main entry point ------------------------------------------------------------

#' Remove the background from an image
#'
#' Runs a segmentation model to predict a foreground alpha matte and composites
#' the result into a cutout with a transparent (or solid-colour) background.
#'
#' @param input The image to process: a file path (PNG or JPEG), a raw vector of
#'   encoded PNG/JPEG bytes, or a numeric \code{[h,w]} / \code{[h,w,c]} array in
#'   \code{[0,1]} (or 0-255).
#' @param model Model name to use when \code{session} is not supplied; see
#'   [rembg_models()]. Defaults to \code{"u2net"}.
#' @param session An [rembg_session] from [new_session()]. If \code{NULL}, one is
#'   created for \code{model}. Pass a session to reuse a loaded model across
#'   calls.
#' @param only_mask If \code{TRUE}, return the predicted mask instead of a cutout.
#' @param post_process_mask If \code{TRUE}, clean the mask with a morphological
#'   opening + gaussian blur + threshold before compositing.
#' @param alpha_matting If \code{TRUE}, refine the cutout edges with closed-form
#'   alpha matting (soft hair/fur edges). Slower, and requires the \pkg{Matrix}
#'   package. Falls back to the plain cutout if matting fails.
#' @param alpha_matting_foreground_threshold Mask values (0-255 domain) above
#'   this are treated as definite foreground in the matting trimap. Default 240.
#' @param alpha_matting_background_threshold Mask values (0-255 domain) below
#'   this are treated as definite background in the matting trimap. Default 10.
#' @param alpha_matting_erode_size Pixels by which the trimap foreground and
#'   background regions are eroded, leaving an unknown band for matting to solve.
#'   Default 10.
#' @param bgcolor Optional background colour to composite the cutout onto, as a
#'   length-3 (RGB) or length-4 (RGBA) numeric vector in \code{[0,1]} or 0-255.
#' @param out Optional output file path. If given, the result is written there as
#'   a PNG (in addition to being returned).
#' @param output In-memory return type: \code{"array"} (default) for a numeric
#'   array in \code{[0,1]}, or \code{"raw"} for PNG-encoded bytes.
#' @param ... Passed to [new_session()] when \code{session} is \code{NULL}.
#'
#' @return Depending on \code{output}: an \code{[h,w,4]} RGBA array (or
#'   \code{[h,w]} mask if \code{only_mask}) in \code{[0,1]}, or a raw vector of
#'   PNG bytes. If \code{out} is set, the PNG is also written to that path.
#'
#' @seealso [new_session()], [rembg_models()]
#' @examples
#' \donttest{
#' if (onnxr::onnx_is_installed()) {
#'   cutout <- rembg(system.file("extdata", "example.jpg", package = "rembg"))
#'   dim(cutout)
#' }
#' }
#' @export
rembg <- function(input, model = "u2net", session = NULL, only_mask = FALSE,
                  post_process_mask = FALSE, alpha_matting = FALSE,
                  alpha_matting_foreground_threshold = 240,
                  alpha_matting_background_threshold = 10,
                  alpha_matting_erode_size = 10, bgcolor = NULL, out = NULL,
                  output = c("array", "raw"), ...) {
    output <- match.arg(output)
    if (is.null(session)) {
        session <- new_session(model, ...)
    }

    img <- .read_image(input)
    masks <- .session_predict(session, img)

    results <- lapply(masks, function(mask) {
        if (post_process_mask) mask <- .post_process(mask)
        if (only_mask) {
            return(mask)
        }
        if (alpha_matting) {
            cut <- tryCatch(
                            .alpha_matting_cutout(img, mask,
                    alpha_matting_foreground_threshold,
                    alpha_matting_background_threshold,
                    alpha_matting_erode_size),
                            error = function(e) NULL
            )
            if (!is.null(cut)) {
                return(cut)
            }
        }
        .cutout(img, mask)
    })

    if (length(results) > 1L && !only_mask) {
        res <- .concat_v(results)
    } else {
        res <- results[[1]]
    }

    if (!is.null(bgcolor) && !only_mask) {
        res <- .apply_bgcolor(res, bgcolor)
    }

    if (!is.null(out)) {
        .write_png(res, out)
    }
    if (output == "raw") {
        return(.write_png(res, NULL))
    }
    res
}
