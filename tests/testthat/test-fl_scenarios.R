test_that("fl_scenarios returns tibble with expected columns", {
  scenarios <- fl_scenarios()
  expect_s3_class(scenarios, "tbl_df")
  expected_cols <- c("scenario_id", "flood_factor", "slope_threshold",
                     "max_width", "cost_threshold", "size_threshold",
                     "hole_threshold", "run", "description",
                     "ecological_process", "citation_keys")
  expect_true(all(expected_cols %in% names(scenarios)))
})

test_that("fl_scenarios has three default scenarios", {
  scenarios <- fl_scenarios()
  expect_equal(nrow(scenarios), 3L)
  expect_equal(scenarios$scenario_id, c("ff02", "ff04", "ff06"))
})

test_that("fl_scenarios flood_factor values match scenario IDs", {
  scenarios <- fl_scenarios()
  expect_equal(scenarios$flood_factor, c(2, 4, 6))
})

test_that("fl_scenarios non-flood_factor params match defaults", {
  scenarios <- fl_scenarios()
  params <- fl_params()
  for (p in c("slope_threshold", "max_width", "cost_threshold",
              "size_threshold", "hole_threshold")) {
    default_val <- as.numeric(params$default[params$parameter == p])
    expect_true(all(scenarios[[p]] == default_val),
                info = paste(p, "should match flood_params.csv default"))
  }
})

test_that("fl_scenarios run column is logical", {
  scenarios <- fl_scenarios()
  expect_type(scenarios$run, "logical")
})

test_that("fl_scenarios accepts custom path", {
  tmp <- tempfile(fileext = ".csv")
  on.exit(unlink(tmp))
  header <- paste0(
    "scenario_id,flood_factor,slope_threshold,max_width,",
    "cost_threshold,size_threshold,hole_threshold,run,",
    "description,ecological_process,citation_keys"
  )
  writeLines(
    c(header,
      "custom,3,9,2000,2500,5000,2500,TRUE,Custom scenario,Test,NA"),
    tmp
  )
  scenarios <- fl_scenarios(path = tmp)
  expect_s3_class(scenarios, "tbl_df")
  expect_equal(nrow(scenarios), 1L)
  expect_equal(scenarios$scenario_id, "custom")
})

test_that("fl_scenarios errors on invalid path", {
  expect_error(fl_scenarios(path = "/nonexistent/file.csv"), "not found")
})
