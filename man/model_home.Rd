% tinyrox says don't edit this manually, but it can't stop you!
\name{model_home}
\alias{model_home}
\title{Directory where downloaded models are cached}
\usage{
model_home()
}
\value{
A file path (character scalar). The directory is not created.
}
\description{
Models are cached in \code{tools::R_user_dir("rembg", "cache")}, the standard
per-package cache location. Set the \env{U2NET_HOME} environment variable to
override it, for example to \code{~/.u2net} to share the cache with the Python
\emph{rembg} package.
}
\examples{
model_home()
}
