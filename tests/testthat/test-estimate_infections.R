context("estimate_infections")

reported_cases <- EpiNow2::example_confirmed[1:30]

# Add a dummy breakpoint (used only when optionally estimating breakpoints)
reported_cases <- reported_cases[, breakpoint := data.table::fifelse(date == as.Date("2020-03-16"),
                                                                     1, 0)]
# Set up example generation time
generation_time <- list(mean = EpiNow2::covid_generation_times[1, ]$mean,
                        mean_sd = EpiNow2::covid_generation_times[1, ]$mean_sd,
                        sd = EpiNow2::covid_generation_times[1, ]$sd,
                        sd_sd = EpiNow2::covid_generation_times[1, ]$sd_sd,
                        max = 10)
# Set delays between infection and case report
reporting_delay <- list(mean = log(2),
                        mean_sd = log(1.1),
                        sd = log(1.3),
                        sd_sd = log(1.1),
                        max = 10)


test_that("estimate_infections successfully returns estimates using default settings", {
  skip_on_cran()
  out <- suppressWarnings(estimate_infections(reported_cases, family = "negbin",
                             generation_time = generation_time,
                             delays = list(reporting_delay),
                             samples = 200, warmup = 100, verbose = FALSE,
                             chains = 2))
  
  
  expect_equal(names(out), c("samples", "summarised"))
  expect_true(nrow(out$samples) > 0)
  expect_true(nrow(out$summarised) > 0)
})

test_that("estimate_infections fails as expected when given a very short timeout", {
  skip_on_cran()
  expect_error(estimate_infections(reported_cases, family = "negbin",
                                   generation_time = generation_time,
                                   delays = list(reporting_delay),
                                   samples = 500, warmup = 200, verbose = FALSE,
                                   chains = 2, future = TRUE, max_execution_time = 10))
  expect_error(estimate_infections(reported_cases, family = "negbin",
                                   generation_time = generation_time,
                                   delays = list(reporting_delay),
                                   samples = 500, warmup = 200, verbose = FALSE,
                                   chains = 2, future = FALSE, max_execution_time = 10))
})



test_that("estimate_infections works as expected with failing chains", {
  skip_on_cran()
  out <- suppressWarnings(estimate_infections(reported_cases, family = "negbin",
                                              generation_time = generation_time,
                                              delays = list(reporting_delay),
                                              samples = 100, warmup = 50, verbose = FALSE,
                                              chains = 4, stuck_chains = 2, future = TRUE))
  expect_equal(names(out), c("samples", "summarised"))
  expect_true(nrow(out$samples) > 0)
  expect_true(nrow(out$summarised) > 0)
  expect_error(suppressWarnings(estimate_infections(reported_cases, family = "negbin",
                                                    generation_time = generation_time,
                                                    delays = list(reporting_delay),
                                                    samples = 100, warmup = 50, verbose = FALSE,
                                                    chains = 4, stuck_chains = 1)))
  expect_error(suppressWarnings(estimate_infections(reported_cases, family = "negbin",
                                                    generation_time = generation_time,
                                                    delays = list(reporting_delay),
                                                    samples = 100, warmup = 50, verbose = FALSE,
                                                    chains = 4, stuck_chains = 3, future = TRUE)))
})
