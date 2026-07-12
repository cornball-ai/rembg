# Model download & cache ------------------------------------------------------

#' Directory where downloaded models are cached
#'
#' Mirrors the Python \emph{rembg} cache resolution so the two share models:
#' the \env{U2NET_HOME} environment variable if set, otherwise
#' \code{<XDG_DATA_HOME>/.u2net}, otherwise \code{~/.u2net}.
#'
#' @return A file path (character scalar). The directory is not created.
#' @examples
#' model_home()
#' @export
model_home <- function() {
    home <- Sys.getenv("U2NET_HOME", "")
    if (!nzchar(home)) {
        xdg <- Sys.getenv("XDG_DATA_HOME", "~")
        home <- file.path(xdg, ".u2net")
    }
    path.expand(home)
}

# Verify a file against a "md5:..." / "sha256:..." checksum string.
# Returns TRUE/FALSE. sha256 needs the openssl package; if absent we warn and
# skip (treated as pass), matching upstream's MODEL_CHECKSUM_DISABLED escape.
.verify_checksum <- function(path, checksum) {
    if (nzchar(Sys.getenv("MODEL_CHECKSUM_DISABLED", ""))) {
        return(TRUE)
    }
    parts <- strsplit(checksum, ":", fixed = TRUE)[[1]]
    algo <- parts[1]; want <- tolower(parts[2])
    got <- switch(algo,
                  md5 = unname(tools::md5sum(path)),
                  sha256 = {
        if (!requireNamespace("openssl", quietly = TRUE)) {
            warning("Package 'openssl' not available; skipping sha256 verification.",
                    call. = FALSE)
            return(TRUE)
        }
        as.character(openssl::sha256(file(path, "rb")))
    },
                  {
        warning(sprintf("Unknown checksum algorithm '%s'; skipping.", algo),
                call. = FALSE)
        return(TRUE)
    }
    )
    identical(tolower(got), want)
}

# Ensure the model file for `model` exists in the cache, downloading if needed.
# Returns the absolute path to the .onnx file.
.ensure_model <- function(model, quiet = FALSE) {
    spec <- .model_spec(model)
    home <- model_home()
    if (!dir.exists(home)) {
        dir.create(home, recursive = TRUE, showWarnings = FALSE)
    }
    dest <- file.path(home, paste0(model, ".onnx"))

    if (file.exists(dest) && .verify_checksum(dest, spec$checksum)) {
        return(dest)
    }

    url <- paste0(.base_url, spec$file)
    if (!quiet) {
        message(sprintf("Downloading model '%s' ...", model))
    }
    tmp <- paste0(dest, ".part")
    ok <- tryCatch({
        utils::download.file(url, tmp, mode = "wb", quiet = quiet)
        0L
    }, error = function(e) {
        stop(sprintf("Failed to download model '%s' from %s: %s", model, url,
                     conditionMessage(e)), call. = FALSE)
    })

    if (!.verify_checksum(tmp, spec$checksum)) {
        unlink(tmp)
        stop(sprintf("Checksum mismatch for downloaded model '%s' (expected %s). %s",
                     model, spec$checksum,
                     "Set MODEL_CHECKSUM_DISABLED=1 to bypass."), call. = FALSE)
    }
    file.rename(tmp, dest)
    dest
}
