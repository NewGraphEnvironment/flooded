test_that("fl_params returns tibble with expected columns", {
  params <- fl_params()
  expect_s3_class(params, "tbl_df")
  expected_cols <- c("parameter", "unit", "default", "source",
                     "citation_keys", "effect", "description")
  expect_true(all(expected_cols %in% names(params)))
})

test_that("fl_params has all fl_valley_confine parameters", {
  params <- fl_params()
  expected_params <- c("flood_factor", "slope_threshold", "max_width",
                       "cost_threshold", "size_threshold", "hole_threshold")
  expect_true(all(expected_params %in% params$parameter))
})

test_that("fl_params accepts custom path", {
  # Write a minimal CSV
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  writeLines(
    c("parameter,unit,default,source,citation_keys,description",
      "test_param,m,10,test,NA,A test parameter"),
    tmp
  )
  params <- fl_params(path = tmp)
  expect_s3_class(params, "tbl_df")
  expect_equal(nrow(params), 1L)
  expect_equal(params$parameter, "test_param")
})

test_that("fl_params errors on invalid path", {
  expect_error(fl_params(path = "/nonexistent/file.csv"), "not found")
})
