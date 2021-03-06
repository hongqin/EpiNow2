context("epinow")

generation_time <- get_generation_time(disease = "SARS-CoV-2", source = "ganyani", max_value = 15)
incubation_period <- get_incubation_period(disease = "SARS-CoV-2", source = "lauer", max_value = 15)
reporting_delay <- EpiNow2::bootstrapped_dist_fit(rlnorm(100, log(3), 1), max_value = 15)

reported_cases <- EpiNow2::example_confirmed[1:30]

df_non_zero <- function(df) {
  expect_true(nrow(df) > 0)
}

test_that("epinow produces expected output when run with default settings", {
  skip_on_cran()
  out <- suppressWarnings(epinow(reported_cases = reported_cases, generation_time = generation_time,
                delays = list(incubation_period, reporting_delay),
                samples = 100, stan_args = list(warmup = 100, cores = 1, chains = 2)))
  
  expect_equal(names(out), c("estimates", "estimated_reported_cases", "summary", "plots"))
  df_non_zero(out$estimates$samples)
  df_non_zero(out$estimates$summarised)
  df_non_zero(out$estimated_reported_cases$samples)
  df_non_zero(out$estimated_reported_cases$summarised)
  df_non_zero(out$summary)
  expect_equal(names(out$plots), c("infections", "reports", "reff", "growth_rate","summary"))
})



test_that("epinow fails as expected when given a short timeout", {
  skip_on_cran()
  expect_error(suppressWarnings(epinow(reported_cases = reported_cases, generation_time = generation_time,
                delays = list(incubation_period, reporting_delay),
                samples = 100, stan_args = list(warmup = 100, cores = 1, chains = 2),
                max_execution_time = 10)))
})


test_that("epinow fails if given NUTs arguments when using variational inference", {
  skip_on_cran()
  expect_error(suppressWarnings(epinow(reported_cases = reported_cases, generation_time = generation_time,
                                       delays = list(incubation_period, reporting_delay),
                                       method = "approximate",
                                       samples = 100, stan_args = list(warmup = 100, cores = 1, chains = 2))))
})


test_that("epinow fails if given variational inference arguments when using NUTs", {
  skip_on_cran()
  expect_error(suppressWarnings(epinow(reported_cases = reported_cases, generation_time = generation_time,
                                       delays = list(incubation_period, reporting_delay),
                                       method = "exact", stan_args = list(tol_rel_obj = 1))))
})