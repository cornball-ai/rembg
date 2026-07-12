% tinyrox says don't edit this manually, but it can't stop you!
\name{rembg}
\alias{rembg}
\title{Remove the background from an image}
\usage{
rembg(input, model = "u2net", session = NULL, only_mask = FALSE,
      post_process_mask = FALSE, alpha_matting = FALSE,
      alpha_matting_foreground_threshold = 240,
      alpha_matting_background_threshold = 10, alpha_matting_erode_size = 10,
      cloth_category = NULL, bgcolor = NULL, out = NULL,
      output = c("array", "raw"), ...)
}
\arguments{
\item{input}{The image to process: a file path (PNG or JPEG), a raw vector of
encoded PNG/JPEG bytes, or a numeric \code{[h,w]} / \code{[h,w,c]} array in
\code{[0,1]} (or 0-255).}

\item{model}{Model name to use when \code{session} is not supplied; see
[rembg_models()]. Defaults to \code{"u2net"}.}

\item{session}{An [rembg_session] from [new_session()]. If \code{NULL}, one is
created for \code{model}. Pass a session to reuse a loaded model across
calls.}

\item{only_mask}{If \code{TRUE}, return the predicted mask instead of a cutout.}

\item{post_process_mask}{If \code{TRUE}, clean the mask with a morphological
opening + gaussian blur + threshold before compositing.}

\item{alpha_matting}{If \code{TRUE}, refine the cutout edges with closed-form
alpha matting (soft hair/fur edges). Slower, and requires the \pkg{Matrix}
package. Falls back to the plain cutout if matting fails.}

\item{alpha_matting_foreground_threshold}{Mask values (0-255 domain) above
this are treated as definite foreground in the matting trimap. Default 240.}

\item{alpha_matting_background_threshold}{Mask values (0-255 domain) below
this are treated as definite background in the matting trimap. Default 10.}

\item{alpha_matting_erode_size}{Pixels by which the trimap foreground and
background regions are eroded, leaving an unknown band for matting to solve.
Default 10.}

\item{cloth_category}{For the \code{"u2net_cloth_seg"} model only: which
garment(s) to segment, one or more of \code{"upper"}, \code{"lower"},
\code{"full"}. \code{NULL} (default) returns all three, stacked vertically.}

\item{bgcolor}{Optional background colour to composite the cutout onto, as a
length-3 (RGB) or length-4 (RGBA) numeric vector in \code{[0,1]} or 0-255.}

\item{out}{Optional output file path. If given, the result is written there as
a PNG (in addition to being returned).}

\item{output}{In-memory return type: \code{"array"} (default) for a numeric
array in \code{[0,1]}, or \code{"raw"} for PNG-encoded bytes.}

\item{...}{Passed to [new_session()] when \code{session} is \code{NULL}.}
}
\value{
Depending on \code{output}: an \code{[h,w,4]} RGBA array (or
  \code{[h,w]} mask if \code{only_mask}) in \code{[0,1]}, or a raw vector of
  PNG bytes. If \code{out} is set, the PNG is also written to that path.
}
\description{
Runs a segmentation model to predict a foreground alpha matte and composites
the result into a cutout with a transparent (or solid-colour) background.
}
\examples{
\donttest{
if (onnxr::onnx_is_installed()) {
  cutout <- rembg(system.file("extdata", "example.jpg", package = "rembg"))
  dim(cutout)
}
}
}
\seealso{
[new_session()], [rembg_models()]
}
