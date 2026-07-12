% tinyrox says don't edit this manually, but it can't stop you!
\name{rembg-package}
\alias{rembg-package}
\title{rembg: Remove Image Backgrounds}
\description{
An R port of the Python \emph{rembg} package. Removes the background from an
image using pre-trained ONNX segmentation models run through the ONNX Runtime
(via \pkg{onnxr}). The main entry point is [rembg()]; models are managed with
[new_session()] and listed with [rembg_models()].
}
\details{
On first use the ONNX Runtime shared library must be present. If \pkg{onnxr}
cannot find it, run \code{onnxr::onnx_install()} once.

}
\keyword{internal}
