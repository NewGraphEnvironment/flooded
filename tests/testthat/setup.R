# Helper to locate test data in inst/testdata/
testdata_path <- function(...) {
  system.file("testdata", ..., package = "flooded", mustWork = TRUE)
}

# The drainage flood surface (#68) needs WhiteboxTools. Call inside each test_that():
# a skip outside one does not skip the block.
skip_if_no_whitebox <- function() {
  testthat::skip_if_not(fl_has_whitebox(), "whitebox package or binary not available")
}
