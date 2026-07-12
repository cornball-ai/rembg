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
Mirrors the Python \emph{rembg} cache resolution so the two share models:
the \env{U2NET_HOME} environment variable if set, otherwise
\code{<XDG_DATA_HOME>/.u2net}, otherwise \code{~/.u2net}.
}
\examples{
model_home()
}
