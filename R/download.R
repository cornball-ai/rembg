# Model download & cache ------------------------------------------------------

#' Directory where downloaded models are cached
#'
#' Models are cached in \code{tools::R_user_dir("rembg", "cache")}, the standard
#' per-package cache location. Set the \env{U2NET_HOME} environment variable to
#' override it, for example to \code{~/.u2net} to share the cache with the Python
#' \emph{rembg} package.
#'
#' @return A file path (character scalar). The directory is not created.
#' @examples
#' model_home()
#' @export
model_home <- function() {
    home <- Sys.getenv("U2NET_HOME", "")
    if (!nzchar(home)) {
        home <- tools::R_user_dir("rembg", "cache")
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

# Ask before writing models into the persistent cache, per CRAN policy. Consent
# is implied once the cache directory exists (acknowledged on first use), or can
# be pre-granted with options(rembg.download = TRUE) or the REMBG_DOWNLOAD
# environment variable (for non-interactive/scripted use).
.download_consent <- function(home, what) {
    if (dir.exists(home)) {
        return(invisible(TRUE))
    }
    if (isTRUE(getOption("rembg.download")) ||
        nzchar(Sys.getenv("REMBG_DOWNLOAD", ""))) {
        return(invisible(TRUE))
    }
    prompt <- sprintf(paste0(
                             "rembg needs to download %s and will cache models in:\n  %s\n",
                             "(Set the U2NET_HOME environment variable to change the location.)"),
                      what, home)
    if (!interactive()) {
        stop(prompt,
             "\n\nThis is a non-interactive session. Allow downloads with ",
             "options(rembg.download = TRUE) or REMBG_DOWNLOAD=1.",
             call. = FALSE)
    }
    if (!isTRUE(utils::askYesNo(paste0(prompt, "\nProceed?")))) {
        stop("Model download declined.", call. = FALSE)
    }
    invisible(TRUE)
}

# Ensure the model file for `model` exists in the cache, downloading if needed.
# Returns the absolute path to the .onnx file.
.ensure_model <- function(model, quiet = FALSE) {
    spec <- .model_spec(model)
    home <- model_home()
    dest <- file.path(home, paste0(model, ".onnx"))

    if (file.exists(dest) && .verify_checksum(dest, spec$checksum)) {
        return(dest)
    }

    .download_consent(home, sprintf("model '%s'", model))
    if (!dir.exists(home)) {
        dir.create(home, recursive = TRUE, showWarnings = FALSE)
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
