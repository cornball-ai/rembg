% tinyrox says don't edit this manually, but it can't stop you!
\name{new_session}
\alias{new_session}
\title{Create a background-removal session}
\usage{
new_session(model = "u2net", backend = c("cpu", "cuda", "coreml"),
            model_path = NULL, size = NULL, mean = NULL, std = NULL, ...)
}
\arguments{
\item{model}{Model name; see [rembg_models()]. Defaults to \code{"u2net"}. The
\code{"u2net_custom"}, \code{"dis_custom"} and \code{"ben_custom"} presets
run your own local \code{.onnx} (via \code{model_path}) through a fixed
preprocessing profile.}

\item{backend}{ONNX Runtime execution backend passed to
[onnxr::onnx_model()]: \code{"cpu"} (default), \code{"cuda"} (NVIDIA GPU,
needs a CUDA runtime build), or \code{"coreml"} (macOS).}

\item{model_path}{Optional path to a local \code{.onnx} file to run instead of
a downloaded model (bring-your-own-model). Required for the \code{*_custom}
presets; when set, \code{model} selects the preprocessing profile.}

\item{size}{Input size (pixels) for a custom \code{model_path}; defaults to the
profile of \code{model} (320 for a bare \code{model_path}).}

\item{mean}{Length-3 per-channel normalisation mean for a custom
\code{model_path}; defaults to the profile of \code{model}.}

\item{std}{Length-3 per-channel normalisation standard deviation for a custom
\code{model_path}; defaults to the profile of \code{model}.}

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
# interactive() guard: new_session() downloads the model on first use
if (interactive() && onnxr::onnx_is_installed()) {
  sess <- new_session("u2netp")
  sess
  # bring your own model:
  # new_session("u2net_custom", model_path = "~/.u2net/my_model.onnx")
}
}
}
\seealso{
[rembg()], [rembg_models()]
}
