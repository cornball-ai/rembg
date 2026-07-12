% tinyrox says don't edit this manually, but it can't stop you!
\name{new_session}
\alias{new_session}
\title{Create a background-removal session}
\usage{
new_session(model = "u2net", backend = c("cpu", "cuda", "coreml"), ...)
}
\arguments{
\item{model}{Model name; see [rembg_models()]. Defaults to \code{"u2net"}.}

\item{backend}{ONNX Runtime execution backend passed to
[onnxr::onnx_model()]: \code{"cpu"} (default), \code{"cuda"} (NVIDIA GPU,
needs a CUDA runtime build), or \code{"coreml"} (macOS).}

\item{...}{Reserved for future use.}
}
\value{
An object of class \code{"rembg_session"}.
}
\description{
Loads a segmentation model (downloading it on first use) and returns a session
object that [rembg()] can reuse across many images. Building the session once
and passing it to [rembg()] avoids re-loading the model each call.
}
\examples{
\donttest{
if (onnxr::onnx_is_installed()) {
  sess <- new_session("u2netp")
  sess
}
}
}
\seealso{
[rembg()], [rembg_models()]
}
