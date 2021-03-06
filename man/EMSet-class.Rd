% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ascend_objects.R
\docType{class}
\name{EMSet-class}
\alias{EMSet-class}
\title{Expression and Metadata Set (EMSet)}
\description{
An S4 class to contain data in a format ascend can work with for analysis.
}
\section{Slots}{

\describe{
\item{\code{ExpressionMatrix}}{Transcript counts stored as a sparse matrix, where rows are transcript/gene identifiers and columns are invididual cells.}

\item{\code{GeneInformation}}{A data frame containing information a set of gene identifiers, such as gene symbols or ENSEMBL transcript identifiers. This data frame also holds information on controls and any information provided by the user.}

\item{\code{CellInformation}}{A data frame containing each cell identifier, its associated batch/sample and additional information such as conditions.}

\item{\code{Controls}}{A named list featuring gene identifiers to use as controls. These gene identifiers must match the identifiers used in the expression matrix.}

\item{\code{PCA}}{Objects related to dimension reduction, such as a PCA matrixand a list of percentage variance values per principle component (PC). Populated by \code{\link{RunPCA}}.}

\item{\code{Clusters}}{Objects related to clustering, including a distance matrix, a hclust object, cell identifiers and their associated cluster. Populated by \code{\link{RunCORE}}.}

\item{\code{Metrics}}{A list of values generated by the \code{\link{GenerateMetrics}} function.}

\item{\code{Log}}{A record of functions used on an \linkS4class{EMSet}.}
}}

