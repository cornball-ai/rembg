## R CMD check results

0 errors | 0 warnings | 1 note

* This is a new submission.

## Test environments

* local Ubuntu 24.04, R 4.6.0
* GitHub Actions (ubuntu-latest, macos-latest)

## Download / filesystem policy

* No downloads or file writes occur during package load, examples, or tests.
* Segmentation models are downloaded from the package's GitHub releases only on
  an explicit user call to `new_session()` / `rembg()`, and cached in
  `tools::R_user_dir("rembg", "cache")`. The `U2NET_HOME` environment variable
  can override the cache location.
* Examples that would trigger a download are wrapped in `\donttest{}` and further
  guarded by `interactive()`, so they never run during `R CMD check --as-cran`
  (which implies `--run-donttest`).
* The package interfaces the 'ONNX' Runtime through 'onnxr'. The runtime shared
  library is installed separately by the user (`onnxr::onnx_install()`); every
  function that needs it is guarded and skipped where it is unavailable, so the
  checks pass without the runtime present.

## Downstream dependencies

None (new package).
