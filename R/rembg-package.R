#' rembg: Remove Image Backgrounds
#'
#' An R port of the Python \emph{rembg} package. Removes the background from an
#' image using pre-trained ONNX segmentation models run through the ONNX Runtime
#' (via \pkg{onnxr}). The main entry point is [rembg()]; models are managed with
#' [new_session()] and listed with [rembg_models()].
#'
#' On first use the ONNX Runtime shared library must be present. If \pkg{onnxr}
#' cannot find it, run \code{onnxr::onnx_install()} once.
#'
#' @name rembg-package
#' @aliases rembg-package
#' @keywords internal
#' @importFrom onnxr onnx_model onnx_run onnx_is_installed
#' @importFrom jpeg readJPEG writeJPEG
#' @importFrom png readPNG writePNG
#' @importFrom utils download.file
#' @importFrom tools md5sum
NULL
