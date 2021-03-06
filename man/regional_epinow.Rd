% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/epinow.R
\name{regional_epinow}
\alias{regional_epinow}
\title{Real-time Rt Estimation, Forecasting and Reporting by Region}
\usage{
regional_epinow(
  reported_cases,
  target_folder,
  target_date,
  non_zero_points = 2,
  summary = TRUE,
  summary_dir,
  region_scale = "Region",
  all_regions_summary = TRUE,
  return_estimates = TRUE,
  max_plot = 10,
  return_timings = FALSE,
  ...
)
}
\arguments{
\item{reported_cases}{A data frame of confirmed cases (confirm) by date (date), and region (\code{region}).}

\item{target_folder}{Character string specifying where to save results (will create if not present).}

\item{target_date}{Date, defaults to maximum found in the data if not specified.}

\item{non_zero_points}{Numeric, the minimum number of time points with non-zero cases in a region required for
that region to be evaluated. Defaults to 2.}

\item{summary}{Logical, should summary measures be calculated.}

\item{summary_dir}{A character string giving the directory
in which to store summary of results.}

\item{region_scale}{A character string indicating the name to give the regions being summarised.}

\item{all_regions_summary}{Logical, defaults to \code{TRUE}. Should summary plots for all regions be returned
rather than just regions of interest.}

\item{return_estimates}{Logical, defaults to TRUE. Should estimates be returned.}

\item{max_plot}{Numeric, defaults to 10. A multiplicative upper bound on the number of cases shown on the plot. Based
on the maximum number of reported cases.}

\item{return_timings}{Logical, defaults to FALSE. If not returning estimates can be used to request timing data is returned.}

\item{...}{Pass additional arguments to \code{epinow}}
}
\value{
A list of output stratified at the top level into regional output and across region output summary output
}
\description{
Estimates Rt by region. See the documentation for \code{epinow} for further information.
}
\examples{
 \donttest{
## Construct example distributions
generation_time <- get_generation_time(disease = "SARS-CoV-2", source = "ganyani")
incubation_period <- get_incubation_period(disease = "SARS-CoV-2", source = "lauer")
                   
reporting_delay <- list(mean = log(10), mean_sd = log(2),
                        sd = log(2), sd_sd = log(1.1), max = 30)
                        
## Uses example case vector
cases <- EpiNow2::example_confirmed[1:40]

cases <- data.table::rbindlist(list(
  data.table::copy(cases)[, region := "testland"],
  cases[, region := "realland"]))
  
## Run basic nowcasting pipeline
## Here we reduce the accuracy of the GP approximation in order to reduce runtime
out <- regional_epinow(reported_cases = cases,  generation_time = generation_time,
                       delays = list(incubation_period, reporting_delay),
                       stan_args = list(warmup = 200, cores = ifelse(interactive(), 4, 1)))
}
}
