% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/create.R
\name{create_initial_conditions}
\alias{create_initial_conditions}
\title{Create Initial Conditions Generating Function}
\usage{
create_initial_conditions(data, delays, rt_prior, generation_time, mean_shift)
}
\arguments{
\item{data}{A list of data as produced by \code{create_stan_data.}}

\item{delays}{A list of delays (i.e incubation period/reporting delay) between infection and report.
Each list entry must also be a list containing the mean, standard deviation of the mean (mean_sd),
standard deviation (sd), standard deviation of the standard deviation and the maximum allowed value for the
that delay (assuming a lognormal distribution with all parameters excepting the max allowed value
on the log scale).}

\item{rt_prior}{A list contain the mean and standard deviation (sd) of the gamma distributed prior for
Rt. By default this is assumed to be mean 1 with a standard deviation of 1.}

\item{generation_time}{A list containing the mean, standard deviation of the mean (mean_sd),
standard deviation (sd), standard deviation of the standard deviation and the maximum allowed value for the
generation time (assuming a gamma distribution).}

\item{mean_shift}{Numeric, mean delay shift}
}
\value{
An initial condition generating function
}
\description{
Create Initial Conditions Generating Function
}
