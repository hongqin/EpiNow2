#' Summarise Real-time Results
#'
#' @param regions An character string containing the list of regions to extract results for 
#' (must all have results for the same target date).
#' @param summaries A list of summary data frames as output by `epinow` 
#' @param results_dir An optional character string indicating the location of the results directory to extract results 
#' from.
#' @param target_date A character string indicating the target date to extract results for. All regions must have results 
#' for this date.
#' @param region_scale A character string indicating the name to give the regions being summarised.
#' @importFrom purrr safely map_chr map_dbl map_chr
#' @importFrom data.table setorderv melt merge.data.table dcast
#' @return A list of summary data
#' @export
summarise_results <- function(regions,
                              summaries,
                              results_dir,
                              target_date,
                              region_scale = "Region") {
  
  if (missing(target_date)) {
    target_date <- NULL
  }
  
  if(is.null(target_date)){
    target_date <- "latest"
  }
   
  if (missing(summaries)) {
    summaries <- NULL
  }
  
  if (missing(results_dir)) {
    results_dir <- NULL
  }
  
  if (is.null(results_dir)) {
    if (is.null(summaries)){ 
      stop("Either a results directory or a list of summary data frames must be supplied")
      }
  }else{
    if (!is.null(summaries)) {
      stop("Both a results directory and a list of summary data frames have been supplied.")
    }
  }
  
  if (is.null(summaries)) {
    ## Utility functions
    get_result <- function(file, region) {
      get_raw_result(file = file, 
                     region = region,
                     date = target_date,
                     result_dir = results_dir)
      }
    
    load_data <- purrr::safely(get_result)

    estimates <- purrr::map(regions, ~ load_data(file = "summary.rds", region = .)[[1]])
    names(estimates) <- regions
  }else{
    estimates <- summaries
  }

  
  estimates <- data.table::rbindlist(estimates, idcol = "region")
  
  numeric_estimates  <- data.table::copy(estimates)[measure %in% c("New confirmed cases by infection date",
                                                    "Effective reproduction no.")][,
                                           .(
                                             point = numeric_estimate[[1]]$point,
                                             lower = numeric_estimate[[1]]$lower,
                                             upper = numeric_estimate[[1]]$upper,
                                             mid_lower = numeric_estimate[[1]]$mid_lower,
                                             mid_upper = numeric_estimate[[1]]$mid_upper,
                                             central_lower = numeric_estimate[[1]]$central_lower,
                                             central_upper = numeric_estimate[[1]]$central_upper
                                           ), by = .(region, measure)][,
                                              metric :=  
                                                factor(measure, levels = c("New confirmed cases by infection date",
                                                                          "Effective reproduction no."))][,
                                              measure := NULL]
  
  
  numeric_estimates <- data.table::merge.data.table(numeric_estimates, 
                                                    estimates[measure %in% "Expected change in daily cases"][,
                                                              .(region, `Expected change in daily cases` = estimate)],
                                                    by = "region", all.x = TRUE)
  ## Rank countries by incidence countries
  high_inc_regions <- unique(
    data.table::setorderv(numeric_estimates, cols = "point", order = -1)$region)
  
  numeric_estimates <- numeric_estimates[, region := factor(region, levels = high_inc_regions)]
  
  ## Clean up joined estimate table and munge into a presentation format
  estimates <- estimates[, numeric_estimate := NULL][, 
    measure := factor(measure, levels = c("New confirmed cases by infection date",
                                          "Expected change in daily cases",
                                          "Effective reproduction no.",
                                          "Rate of growth",
                                          "Doubling/halving time (days)"))]
  
  estimates <- data.table::dcast(estimates, region ~ ..., value.var = "estimate")
  
  estimates <- estimates[, (region_scale) := region][, region := NULL]
  
  estimates <- estimates[, c(region_scale, 
                             colnames(estimates)[-ncol(estimates)]), with = FALSE]
  
  out <- list(estimates, numeric_estimates, high_inc_regions)
  
  names(out) <- c("table", "data", "regions_by_inc")
  
  return(out)
}


#' Generate Regional Summary Output
#'
#' @param summary_dir A character string giving the directory
#'  in which to store summary of results.
#' @param target_date A character string giving the target date for which to extract results
#' (in the format "yyyy-mm-dd"). Defaults to latest available estimates.
#' @param all_regions Logical, defaults to `TRUE`. Should summary plots for all regions be returned 
#' rather than just regions of interest.
#' @param return_summary Logical, defaults to `TRUE`. Should summary measures be returned.
#' @return A list of summary measures and plots
#' @export
#' @inheritParams summarise_results
#' @inheritParams plot_summary
#' @inheritParams summarise_key_measures
#' @inheritParams regional_epinow
#' @inheritParams get_regional_results
#' @inheritParams report_plots
#' @importFrom purrr map_chr compact
#' @importFrom ggplot2 coord_cartesian guides guide_legend ggsave ggplot_build
#' @importFrom cowplot get_legend
#' @importFrom data.table setDT
#' @importFrom futile.logger flog.info
#' @examples
#' \donttest{
#' ## Set up example delays
#' generation_time <- get_generation_time(disease = "SARS-CoV-2", source = "ganyani")
#' incubation_period <- get_incubation_period(disease = "SARS-CoV-2", source = "lauer")
#' reporting_delay <- EpiNow2::bootstrapped_dist_fit(rlnorm(100, log(6), 1), max_value = 30)
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
#'                                 stan_args = list(cores = 4),
#'                                 summary = FALSE)
#'
#' results_dir <- tempdir()             
#' regional_summary(regional_output = regional_out$regional,
#'                  reported_cases = cases,
#'                  summary_dir = results_dir,
#'                  region_scale = "Country", all_regions = FALSE)
#'
#' } 
#' 
regional_summary <- function(regional_output,
                             reported_cases,
                             results_dir, 
                             summary_dir,
                             target_date,
                             region_scale = "Region",
                             all_regions = TRUE,
                             return_summary = TRUE, 
                             max_plot = 10) {
    
  reported_cases <- data.table::setDT(reported_cases)
  
  if (missing(summary_dir) & !return_summary) {
    stop("Either allow results to be returned or supply a directory for results to be saved into")
  }
  
  if (missing(summary_dir)) {
    summary_dir <- NULL
  }
  
  if (missing(results_dir)) {
    results_dir <- NULL
  }
   
  if (missing(target_date)) {
    target_date <- NULL
  }
  if (!is.null(results_dir) & !missing(regional_output)) {
    stop("Only one of results_dir and regional_output should be specified")
  }
  
  if (missing(regional_output)) {
    regional_output <- NULL
    if (!is.null(results_dir)) {
     futile.logger::flog.info("Extracting results from: %s", results_dir)
      
     regions <- EpiNow2::get_regions(results_dir)
     
       if (is.null(target_date)) {
         target_date <- "latest"
       }
    }
  }else{
    regions <- names(regional_output)
    regional_output <- purrr::compact(regional_output)
  }
  
  futile.logger::flog.trace("Getting regional results")
  ## Get estimates
  results <- get_regional_results(regional_output,
                                  results_dir = results_dir,
                                  samples = FALSE,
                                  forecast = FALSE)
  
  ## Get latest date
  latest_date <- unique(reported_cases[confirm > 0][date == max(date)]$date)
  
  if (!is.null(summary_dir)) {
    ## Make summary directory
    if (!dir.exists(summary_dir)) {
      dir.create(summary_dir)
    }
    saveRDS(latest_date, file.path(summary_dir, "latest_date.rds"))
    data.table::fwrite(reported_cases, file.path(summary_dir, "reported_cases.csv"))
  }
  
  if (!is.null(regional_output)) {
    regional_summaries <- purrr::map(regional_output, ~ .$summary)
  }else{
    regional_summaries <- NULL
  }

  futile.logger::flog.trace("Summarising results")
  
  ## Summarise results to csv
  sum_key_measures <- summarise_key_measures(regional_results = results,
                                             results_dir = results_dir, 
                                             summary_dir = summary_dir, 
                                             type = tolower(region_scale),
                                             date = target_date) 
  
  ## Summarise results as a table
  summarised_results <- summarise_results(regions, 
                                          summaries = regional_summaries,
                                          results_dir = results_dir,
                                          target_date = target_date,
                                          region_scale = region_scale)
  
  force_factor <- function(df) {
    df[,`Expected change in daily cases` :=
         factor(`Expected change in daily cases`,
                levels = c("Increasing", "Likely increasing", "Unsure", 
                           "Likely decreasing", "Decreasing"))] 
    
  }
  
  summarised_results$table <- force_factor(summarised_results$table)
  
  summarised_results$data <- force_factor(summarised_results$data)
  
  if (!is.null(summary_dir)) {
    data.table::fwrite(summarised_results$table, file.path(summary_dir, "summary_table.csv"))
    data.table::fwrite(summarised_results$data,  file.path(summary_dir, "summary_data.csv"))
  }
   

  ## Adaptive add a logscale to the summary plot based on range of observed cases
  log_cases <- (max(summarised_results$data[metric %in% "New confirmed cases by infection date"]$upper, na.rm = TRUE) / 
             min(summarised_results$data[metric %in% "New confirmed cases by infection date"]$lower, na.rm = TRUE)) > 1000

  max_reported_cases <- round(max(reported_cases$confirm, na.rm = TRUE) * max_plot, 0)
  
  ## Summarise cases and Rts
  summary_plot <- plot_summary(summarised_results$data,
                               x_lab = region_scale, 
                               log_cases = log_cases,
                               max_cases = max_reported_cases)
  
  if (!is.null(summary_dir)) {
    suppressWarnings(
      suppressMessages(
        ggplot2::ggsave(file.path(summary_dir, "summary_plot.png"),
                        dpi = 300, height = 12, width = ifelse(length(regions) > 60, 
                                                               ifelse(length(regions) > 120, 36, 24),
                                                               12))
      )
    )
  }
  
  ## Extract regions with highest number of reported cases in the last week
  regions_with_most_reports <- data.table::copy(reported_cases)[, 
          .SD[date >= (max(date, na.rm = TRUE) - lubridate::days(7))],by = "region"]
  regions_with_most_reports <- regions_with_most_reports[, .(confirm = sum(confirm, na.rm = TRUE)), by = "region"]
  regions_with_most_reports <-  data.table::setorderv(regions_with_most_reports, cols = "confirm", order = -1)
  regions_with_most_reports <- regions_with_most_reports[1:6][!is.na(region)]$region
  
  high_plots <- report_plots(
    summarised_estimates = results$estimates$summarised[region %in% regions_with_most_reports], 
    reported = reported_cases[region %in% regions_with_most_reports],
    max_plot = max_plot
  )
  
  high_plots$summary <- NULL
  high_plots <- purrr::map(high_plots,
                            ~ . + ggplot2::facet_wrap(~ region, scales = "free_y", ncol = 2))
  
  
  if (!is.null(summary_dir)) {
    suppressWarnings(
      suppressMessages(
        ggplot2::ggsave(file.path(summary_dir, "high_rt_plot.png"),
                        high_plots$reff, dpi = 300, width = 12, height = 12)
      ))
    
    suppressWarnings(
      suppressMessages(
        ggplot2::ggsave(file.path(summary_dir, "high_infections_plot.png"), 
                        high_plots$infections, dpi = 300, width = 12, height = 12)
      ))
    
     suppressWarnings(
      suppressMessages(
        ggplot2::ggsave(file.path(summary_dir, "high_reported_cases_plot.png"), 
                        high_plots$reports, dpi = 300, width = 12, height = 12)
      ))
  }
  
  if (all_regions) {
    plots_per_row <- ifelse(length(regions) > 60, 
                            ifelse(length(regions) > 120, 8, 5), 3)
    
    plots <- report_plots(summarised_estimates = results$estimates$summarised, 
                          reported = reported_cases,
                          max_plot = max_plot)
    
    plots$summary <- NULL
    plots <- purrr::map(plots,
                        ~ . + ggplot2::facet_wrap(~ region, scales = "free_y",
                                                  ncol = plots_per_row))
    
    
    if (!is.null(summary_dir)) {
      suppressWarnings(
        suppressMessages(
          ggplot2::ggsave(file.path(summary_dir, "rt_plot.png"), 
                          plots$reff, dpi = 300, width = 24,
                          height = 3 * round(length(regions) / plots_per_row, 0), 
                          limitsize = FALSE)
          
        ))
      
      suppressWarnings(
        suppressMessages( 
          ggplot2::ggsave(file.path(summary_dir, "infections_plot.png"), 
                          plots$infections, dpi = 300, width = 24, 
                          height =  3 * round(length(regions) / plots_per_row, 0),
                          limitsize = FALSE)
        ))
      
      suppressWarnings(
        suppressMessages( 
          ggplot2::ggsave(file.path(summary_dir, "reported_cases_plot.png"), 
                          plots$reports, dpi = 300, width = 24, 
                          height =  3 * round(length(regions) / plots_per_row, 0),
                          limitsize = FALSE)
        ))
    }
  }
 
  if (return_summary) {
    out <- list()
    out$latest_date <- latest_date
    out$results <- results
    out$summarised_results <- summarised_results
    out$summary_plot <- summary_plot
    out$summarised_measures <- sum_key_measures
    out$reported_cases <- reported_cases
    out$high_plots <- high_plots
    
    if (all_regions) {
      out$plots <- plots
    }

    return(out)
  }else{
    return(invisible(NULL))
  }
}

#' Summarise rt and cases
#'
#' @param regional_results A list of dataframes as produced by `get_regional_results`
#' @param results_dir Character string indicating the directory from which to extract results.
#' @param summary_dir Character string the directory into which to save results as a csv.
#' @param type Character string, the region identifier to apply (defaults to region).
#' @inheritParams get_regional_results
#' @return A list of summarised Rt, cases by date of infection and cases by date of report
#' @export
#' @importFrom data.table setnames fwrite
summarise_key_measures <- function(regional_results,
                                   results_dir, summary_dir, 
                                   type = "region", date) {
  
  if (missing(regional_results)) {
    regional_results <- NULL
  }
  
  if (is.null(regional_results)) {
    if (missing(results_dir)) {
      results_dir <- NULL
    }
    
    if (is.null(results_dir)) {
      stop("Missing results directory")
    }
    
    if (missing(summary_dir)) {
      summary_dir <- NULL
    }
    
    if (missing(date)) {
      date <- "latest"
    }
    
    timeseries <- EpiNow2::get_regional_results(results_dir = results_dir,
                                                date = date, forecast = FALSE, 
                                                samples = FALSE)
  }else{
    timeseries <- regional_results 
  }
  

  summarise_variable <- function(df, dof = 0) {
    df <- df[, .(region, date, type, median = round(median, dof),
           mean = round(mean, dof), sd = round(sd, dof),
           lower_20 = round(central_lower, dof), upper_20 = round(central_upper, dof),
           lower_50 = round(lower, dof), upper_50 = round(upper, dof),
           lower_90 = round(bottom, dof), upper_90 = round(top, dof))]
    
    data.table::setnames(df, "region", type)
    
    return(df)
  }

  save_variable <- function(df, name) {
      if (!is.null(summary_dir)) {
        data.table::fwrite(df, paste0(summary_dir, "/", name, ".csv"))
      }
  }
  
  out <- list()
  
  ## Clean and save Rt estimates
  out$rt <- summarise_variable(timeseries$estimates$summarised[variable == "R"], 2)
  save_variable(out$rt, "rt")
  
  ## Clean and save growth rate estimates
  out$growth_rate <- summarise_variable(timeseries$estimates$summarised[variable == "growth_rate"], 3)
  save_variable(out$growth_rate, "growth_rate")
  
  ## Clean and save case estimates
  out$cases_by_infection <- summarise_variable(timeseries$estimates$summarised[variable == "infections"], 0)
  save_variable(out$cases_by_infection, "cases_by_infection")
  
  ## Clean and save case estimates
  out$cases_by_report <- summarise_variable(timeseries$estimates$summarised[variable == "reported_cases"], 0)
  save_variable(out$cases_by_report, "cases_by_report")

  return(out)
}
