# Image IO --------------------------------------------------------------------
#
# Decode to / encode from [h,w,c] arrays of doubles in [0,1] (jpeg/png's native
# layout, which matches numpy's np.array(PIL)). Only PNG and JPEG are supported;
# other formats would need an extra dependency.

# Detect "png" / "jpeg" from the leading magic bytes, or NA.
.image_format <- function(bytes) {
    if (length(bytes) >= 3 &&
        bytes[1] == as.raw(0xFF) && bytes[2] == as.raw(0xD8) &&
        bytes[3] == as.raw(0xFF)) {
        return("jpeg")
    }
    if (length(bytes) >= 4 &&
        bytes[1] == as.raw(0x89) && bytes[2] == as.raw(0x50) &&
        bytes[3] == as.raw(0x4E) && bytes[4] == as.raw(0x47)) {
        return("png")
    }
    NA_character_
}

# Coerce a decoded array to [h,w,3] in [0,1]: grayscale -> RGB, drop alpha.
.as_rgb <- function(a) {
    if (length(dim(a)) == 2L) {
        a <- array(a, c(dim(a), 1L))
    }
    nc <- dim(a)[3]
    if (nc == 1L) {
        a <- array(a[,, 1], c(dim(a)[1], dim(a)[2], 3L))
    } else if (nc >= 3L) {
        a <- a[,, 1:3, drop = FALSE]
    } else {
        stop("Unsupported number of image channels: ", nc, call. = FALSE)
    }
    a
}

# Read any supported input into an [h,w,3] array in [0,1].
#   input: file path (character), raw vector of encoded bytes, or a numeric
#          [h,w] / [h,w,c] array already in [0,1] (or 0-255).
.read_image <- function(input) {
    if (is.character(input)) {
        if (length(input) != 1L || !file.exists(input)) {
            stop("Image file not found: ", input, call. = FALSE)
        }
        bytes <- readBin(input, "raw", n = 8L)
        fmt <- .image_format(bytes)
        a <- switch(fmt,
                    jpeg = jpeg::readJPEG(input),
                    png = png::readPNG(input),
                    stop("Unsupported image format (only PNG and JPEG are supported): ", input,
                         call. = FALSE)
        )
        return(.as_rgb(a))
    }
    if (is.raw(input)) {
        fmt <- .image_format(input)
        a <- switch(fmt,
                    jpeg = jpeg::readJPEG(input),
                    png = png::readPNG(input),
                    stop("Unsupported image format in raw input (only PNG and JPEG).",
                         call. = FALSE)
        )
        return(.as_rgb(a))
    }
    if (is.array(input) || is.matrix(input)) {
        a <- input
        if (max(a, na.rm = TRUE) > 1) {
            a <- a / 255
        }
        return(.as_rgb(a))
    }
    stop("`input` must be a file path, a raw vector, or a numeric array.", call. = FALSE)
}

# Encode an [h,w,c] array in [0,1] to PNG. If `target` is a path, write there and
# return it invisibly; if NULL, return the PNG as a raw vector.
.write_png <- function(a, target = NULL) {
    a[] <- pmin(pmax(a, 0), 1)
    if (is.null(target)) {
        return(png::writePNG(a, target = raw()))
    }
    png::writePNG(a, target = target)
    invisible(target)
}
