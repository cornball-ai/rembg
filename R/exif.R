# EXIF orientation ------------------------------------------------------------
#
# jpeg/png don't parse EXIF, so a phone JPEG that stores pixels sideways with an
# Orientation tag decodes sideways. This reads the tag (1-8) from the JPEG's
# APP1/TIFF header and applies the matching flip/rotate, matching PIL's
# exif_transpose() that upstream rembg calls before processing.

# --- geometric transforms on an [h,w,c] array --------------------------------
.ex_flip_lr <- function(a) a[, rev(seq_len(dim(a)[2])),, drop = FALSE] # mirror x
.ex_flip_tb <- function(a) a[rev(seq_len(dim(a)[1])),,, drop = FALSE] # mirror y
.ex_transpose <- function(a) aperm(a, c(2L, 1L, 3L)) # main diagonal
.ex_rot90cw <- function(a) .ex_flip_lr(.ex_transpose(a)) # 90 clockwise
.ex_rot90ccw <- function(a) .ex_flip_tb(.ex_transpose(a)) # 90 counter-clockwise
.ex_rot180 <- function(a) .ex_flip_lr(.ex_flip_tb(a))

# Apply the correction for EXIF orientation `o` (1-8) to an [h,w,c] array.
# Mapping follows PIL ImageOps.exif_transpose (PIL rotations are CCW).
.apply_orientation <- function(a, o) {
    switch(as.character(o),
           "2" = .ex_flip_lr(a),
           "3" = .ex_rot180(a),
           "4" = .ex_flip_tb(a),
           "5" = .ex_transpose(a), # TRANSPOSE
           "6" = .ex_rot90cw(a), # ROTATE_270 (CCW)
           "7" = .ex_flip_lr(.ex_flip_tb(.ex_transpose(a))), # TRANSVERSE
           "8" = .ex_rot90ccw(a), # ROTATE_90 (CCW)
           a # 1 or unknown -> unchanged
    )
}

# --- read the Orientation tag from JPEG bytes --------------------------------
# Returns an integer 1-8 (1 if not JPEG / no EXIF / unparseable).
.exif_orientation <- function(bytes) {
    tryCatch(.exif_orientation_impl(bytes), error = function(e) 1L)
}

.exif_orientation_impl <- function(bytes) {
    n <- length(bytes)
    if (n < 4L || bytes[1] != as.raw(0xFF) || bytes[2] != as.raw(0xD8)) {
        return(1L)
    }

    # Walk JPEG markers looking for the APP1 (0xFFE1) "Exif" segment.
    i <- 3L
    tiff <- NA_integer_
    while (i + 3L <= n) {
        if (bytes[i] != as.raw(0xFF)) {
            break
        }
        marker <- as.integer(bytes[i + 1L])
        if (marker == 0xD9L || marker == 0xDAL) {
            break # EOI / start of scan
        }
        seglen <- as.integer(bytes[i + 2L]) * 256L + as.integer(bytes[i + 3L])
        if (seglen < 2L) {
            break
        }
        if (marker == 0xE1L) { # APP1
            p <- i + 4L
            if (p + 5L <= n &&
                rawToChar(bytes[p:(p + 3L)]) == "Exif" &&
                bytes[p + 4L] == as.raw(0) && bytes[p + 5L] == as.raw(0)) {
                tiff <- p + 6L # start of TIFF header
                break
            }
        }
        i <- i + 2L + seglen
    }
    if (is.na(tiff) || tiff + 7L > n) {
        return(1L)
    }

    little <- rawToChar(bytes[tiff:(tiff + 1L)]) == "II"
    rd16 <- function(off) {
        b <- as.integer(bytes[off:(off + 1L)])
        if (little) {
            b[1] + 256L * b[2]
        } else {
            256L * b[1] + b[2]
        }
    }
    rd32 <- function(off) {
        b <- as.numeric(bytes[off:(off + 3L)])
        if (little) {
            b[1] + 256 * b[2] + 65536 * b[3] + 16777216 * b[4]
        } else {
            16777216 * b[1] + 65536 * b[2] + 256 * b[3] + b[4]
        }

    }

    ifd <- tiff + rd32(tiff + 4L) # IFD0
    if (ifd + 2L > n) {
        return(1L)
    }
    count <- rd16(ifd)
    for (e in seq_len(count)) {
        base <- ifd + 2L + (e - 1L) * 12L
        if (base + 11L > n) {
            break
        }
        if (rd16(base) == 0x0112L) { # Orientation tag
            val <- rd16(base + 8L) # SHORT in value field
            return(if (val >= 1L && val <= 8L) val else 1L)
        }
    }
    1L
}
