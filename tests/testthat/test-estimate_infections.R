context("estimate_infections")

reported_cases <- EpiNow2::example_confirmed[1:30]

# Add a dummy breakpoint (used only when optionally estimating breakpoints)
reported_cases <- reported_cases[, breakpoint := data.table::fifelse(date == as.Date("2020-03-16"),
                                                                     1, 0)]
generation_time <- get_generation_time(disease = "SARS-CoV-2", source = "ganyani", max_value = 10)
incubation_period <- get_incubation_period(disease = "SARS-CoV-2", source = "lauer", max_value = 10)
reporting_delay <- list(mean = log(3), mean_sd = 0.1, sd = log(2), sd_sd = 0.1, max = 10)

test_that("estimate_infections successfully returns estimates using default settings", {
  skip_on_cran()
  out <- suppressWarnings(estimate_infections(reported_cases, generation_time = generation_time,
                             delays = list(reporting_delay), samples = 100, 
                             stan_args=list(chains = 2, warmup = 100)))
  
  
  expect_equal(names(out), c("samples", "summarised"))
  expect_true(nrow(out$samples) > 0)
  expect_true(nrow(out$summarised) > 0)
})


test_that("estimate_infections fails as expected when given a very short timeout", {
  skip_on_cran()
  expect_error(estimate_infections(reported_cases, generation_time = generation_time,
                                   delays = list(reporting_delay),
                                   samples = 100, stan_args=list(chains = 2, warmup = 100), 
                                   future = TRUE, max_execution_time = 10))
  expect_error(estimate_infections(reported_cases, generation_time = generation_time,
                                   delays = list(reporting_delay),
                                   samples = 100, stan_args = list(chains = 2, warmup = 100),
                                   future = FALSE, max_execution_time = 10))
})



test_that("estimate_infections works as expected with failing chains", {
  skip_on_cran()
  out <- suppressWarnings(estimate_infections(reported_cases, generation_time = generation_time,
                                              delays = list(reporting_delay),
                                              samples = 100, stan_args = list(chains = 4, warmup = 50,
                                                                              stuck_chains = 2),
                                              future = TRUE))
  expect_equal(names(out), c("samples", "summarised"))
  expect_true(nrow(out$samples) > 0)
  expect_true(nrow(out$summarised) > 0)
  expect_error(suppressWarnings(estimate_infections(reported_cases, generation_time = generation_time,
                                                    delays = list(reporting_delay), samples = 100,
                                                    stan_args = list(chains = 4, warmup = 50,
                                                                     stuck_chains = 1)
                                                    )))
  expect_error(suppressWarnings(estimate_infections(reported_cases, generation_time = generation_time,
                                                    delays = list(reporting_delay),
                                                    stan_args = list(chains = 4, warmup = 50,
                                                                     stuck_chains = 3),
                                                    samples = 100, future = TRUE)))
})


test_that("estimate_infections produces output as expected when using approximate approach", {
  skip_on_cran()
  out <- suppressWarnings(estimate_infections(reported_cases, generation_time = generation_time,
                                              delays = list(reporting_delay),
                                              samples = 1000, method = "approximate"))
  expect_equal(names(out), c("samples", "summarised"))
  expect_true(nrow(out$samples) > 0)
  expect_true(nrow(out$summarised) > 0)
})

