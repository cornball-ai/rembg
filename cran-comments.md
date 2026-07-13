## Resubmission

This is a resubmission of version 0.1.0, replacing my earlier submission of the
same version. Before review I found and corrected an issue: model downloads now
ask for the user's confirmation of the cache location (an interactive prompt on
first use; non-interactive use opts in via `options(rembg.download = TRUE)` or the
`REMBG_DOWNLOAD` environment variable). No models are downloaded during package
load, examples, or tests.

## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* local Ubuntu 24.04, R 4.6.0
* GitHub Actions (ubuntu-latest, macos-latest)

## Download / filesystem policy

* No downloads or file writes occur during package load, examples, or tests.
* Segmentation models are downloaded from the package's GitHub releases only
  after the user confirms the cache location: `utils::askYesNo()` on first use in
  an interactive session, or an explicit opt-in via `options(rembg.download =
  TRUE)` / `REMBG_DOWNLOAD=1` in non-interactive use. Models are cached in
  `tools::R_user_dir("rembg", "cache")`, overridable via `U2NET_HOME`.
* Examples that would trigger a download are wrapped in `\donttest{}` and further
  guarded by `interactive()`, so they never run during `R CMD check --as-cran`
  (which implies `--run-donttest`).
* The package interfaces the 'ONNX' Runtime through 'onnxr'. The runtime shared
  library is installed separately by the user (`onnxr::onnx_install()`); every
  function that needs it is guarded and skipped where it is unavailable, so the
  checks pass without the runtime present.

## Downstream dependencies

None (new package).
