#' Get Folders with Nowcast Results
#'
#' @param results_dir A character string giving the directory in which results
#'  are stored (as produced by `regional_rt_pipeline`).
#'
#' @return A named character vector containing the results to plot.
#' @export
get_regions <- function(results_dir) {
  
  # Regions to include - based on folder names
  regions <- list.files(results_dir, recursive = FALSE)
  
  ## Put into alphabetical order
  regions <- regions[order(regions)]
  
  names(regions) <- regions
  
  
  return(regions)
}



#' Get a Single Raw Result
#'
#' @param file Character string giving the result files name.
#' @param region Character string giving the region of interest.
#' @param date Target date (in the format `"yyyy-mm-dd`).
#' @param result_dir Character string giving the location of the target directory 
#' @export
#' @return An R object read in from the targeted .rds file
get_raw_result <- function(file, region, date, 
                           result_dir) {
  file_path <- file.path(result_dir, region, date, file)
  object <- readRDS(file_path)
  
  return(object)
}

#' Get Combined Regional Results
#' @param regional_output A list of output as produced by `regional_epinow` and stored in the 
#' `regional` list.
#' @param results_dir A character string indicating the folder containing the `EpiNow2`
#' results to extract.
#' @param date A Character string (in the format "yyyy-mm-dd") indicating the date to extract
#' data for. Defaults to "latest" which finds the latest results available.
#' @param samples Logical, defaults to `TRUE`. Should samples be returned. 
#' @param forecast Logical, defaults to `FALSE`. Should forecast results be returned.
#' @return A list of estimates, forecasts and estimated cases by date of report.
#' @export
#' @importFrom purrr map safely
#' @importFrom data.table rbindlist
#' @examples
#' \donttest{
#' # Construct example distributions
#' generation_time <- get_generation_time(disease = "SARS-CoV-2", source = "ganyani")
#' incubation_period <- get_incubation_period(disease = "SARS-CoV-2", source = "lauer")
#' reporting_delay <- EpiNow2::bootstrapped_dist_fit(rlnorm(100, log(6), 1), max_value = 30)
#' 
#'                         
#' # Uses example case vector from EpiSoon
#' cases <- EpiNow2::example_confirmed[1:30]
#' 
#' cases <- data.table::rbindlist(list(
#'   data.table::copy(cases)[, region := "testland"],
#'   cases[, region := "realland"]))
#'   
#' # Run basic nowcasting pipeline
#' regional_out <- regional_epinow(reported_cases = cases,
#'                                 generation_time = generation_time,
#'                                 delays = list(incubation_period, reporting_delay),
#'                                 stan_args = list(cores = ifelse(interactive(), 4, 1)),
#'                                 summary = FALSE)
#'
#' summary_only <- get_regional_results(regional_out$regional, forecast = FALSE, samples = FALSE)
#' names(summary_only)
#' 
#' all <- get_regional_results(regional_out$regional, forecast = TRUE)
#' names(all)
#' }

get_regional_results <- function(regional_output,
                                 results_dir, date,
                                 samples = TRUE,
                                 forecast = FALSE) {
  if (missing(regional_output)) {
    regional_output <- NULL
  }
  
  if (is.null(regional_output)) {
    ## Assign to latest likely date if not given
    if (missing(date)) {
      date <- "latest"
    }
    ## Find all regions
    regions <- list.files(results_dir, recursive = FALSE)
    names(regions) <- regions
    
    load_data <- purrr::safely(EpiNow2::get_raw_result)
  
    # Get estimates -----------------------------------------------------------
    get_estimates_file <- function(samples_path, summarised_path) {
      out <- list()
      
      if (samples) {
        samples <- purrr::map(regions, ~ load_data(samples_path, .,
                                                   result_dir = results_dir,
                                                   date = date)[[1]])
        samples <- data.table::rbindlist(samples, idcol = "region",  fill = TRUE)
        out$samples <- samples
      }
      ## Get incidence values and combine
      summarised <- purrr::map(regions, ~ load_data(summarised_path, .,
                                                    result_dir = results_dir,
                                                    date = date)[[1]])
      summarised <- data.table::rbindlist(summarised, idcol = "region", fill = TRUE)
      out$summarised <- summarised
      return(out)
    }
    out <- list()
    out$estimates <- get_estimates_file(samples_path = "estimate_samples.rds",
                                        summarised_path = "summarised_estimates.rds")
    
    if (forecast) {
      out$forecast <- get_estimates_file(samples_path = "forecast_samples.rds",
                                         summarised_path = "summarised_forecast.rds")
      
      out$estimated_reported_cases <- get_estimates_file(samples_path = "estimated_reported_cases_samples.rds",
                                                         summarised_path = "summarised_estimated_reported_cases.rds")
    }
  }else{
    get_estimates_data <- function(data) {
      out <- list()
      if (samples) {
        samples <- purrr::map(regional_output, ~ .[[data]]$samples)
        samples <- data.table::rbindlist(samples, idcol = "region", fill = TRUE)
        out$samples <- samples
      }
      ## Get incidence values and combine
      summarised <- purrr::map(regional_output, ~ .[[data]]$summarised)
      summarised <- data.table::rbindlist(summarised, idcol = "region", fill = TRUE)
      out$summarised <- summarised
      return(out)
    }
    
    out <- list()
    out$estimates <- get_estimates_data("estimates")
    
    if (forecast) {
      out$forecast <- get_estimates_data("forecasts")
      out$estimated_reported_cases <- get_estimates_data("estimated_reported_cases")
    }
  }
  return(out)
}



#' Get a Literature Distribution
#'
#' @param data A `data.table` in the format of `generation_times`.
#' @param disease A character string indicating the disease of interest.
#' @param source A character string indicating the source of interest.
#' @param max_value Numeric, the maximum value to allow. Defaults to 30 days.
#'
#' @return A list defining a distribution
#' @export
#'
#' @examples
#' 
#' get_dist(EpiNow2::generation_times, disease = "SARS-CoV-2", source = "ganyani") 
#' 
get_dist <- function(data, disease, source, max_value = 30) {
  
  target_disease <- disease
  target_source <- source
  data <- data[disease == target_disease][source == target_source]
  
  dist <- as.list(data[, .(mean, mean_sd, sd, sd_sd, max = max_value)])
  return(dist)
}

#'  Get a Literature Distribution for the Generation Time
#'
#' @description Extracts a literature distribution from `generation_times`
#' @inheritParams get_dist
#' @inherit get_dist
#' @export
#'
#' @examples
#' get_generation_time(disease = "SARS-CoV-2", source = "ganyani")
get_generation_time <- function(disease, source, max_value = 30) {
  dist <- get_dist(EpiNow2::generation_times,
                   disease = disease, source = source, 
                   max_value = max_value)
  
  return(dist)
}


#'  Get a Literature Distribution for the Incubation Period
#'
#' @description Extracts a literature distribution from `incubation_periods`
#' @inheritParams get_dist
#' @inherit get_dist
#' @export
#'
#' @examples
#' get_incubation_period(disease = "SARS-CoV-2", source = "lauer")
get_incubation_period <- function(disease, source, max_value = 30) {
  dist <- get_dist(EpiNow2::incubation_periods,
                   disease = disease, source = source, 
                   max_value = max_value)
  
  return(dist)
}
