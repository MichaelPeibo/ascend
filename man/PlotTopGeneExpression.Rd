% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ascend_plots.R
\name{PlotTopGeneExpression}
\alias{PlotTopGeneExpression}
\title{PlotTopGeneExpression}
\usage{
PlotTopGeneExpression(object, n = 50, controls = TRUE)
}
\arguments{
\item{object}{A EMSet object}

\item{n}{Number of genes to be plotted}
}
\description{
Generates a boxplot using \link[ggplot2]{geom_boxplot} of the most expressed genes in the dataset, in a range defined by the user.
}
