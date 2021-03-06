% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ascend_scran.R
\name{SCEnormalise}
\alias{SCEnormalise}
\title{SCEnormalise}
\usage{
SCEnormalise(sce.obj, em.set, quickCluster = FALSE, min.mean = 1e-05)
}
\arguments{
\item{sce.obj}{A \linkS4class{SingleCellExperiment} object}

\item{em.set}{An \linkS4class{EMSet} that the sce.set originated from}

\item{quickCluster}{Normalise with quickCluster Default: FALSE}

\item{min.mean}{Argument to pass on to \code{\link{computeSumFactors}} from
\pkg{scran} Default: 1e-5}
}
\description{
Called by scranNormalise - runs normalisation on \pkg{SingleCellExperiment}
object and converts it back to EMSets.
}
