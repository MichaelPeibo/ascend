% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ascend_scran.R
\name{scranCellCycle}
\alias{scranCellCycle}
\title{scranCellCycle}
\usage{
scranCellCycle(object, training.set)
}
\arguments{
\item{object}{An \linkS4class{EMSet} object.}

\item{training.set}{A training dataset containing pairs of marker genes.}
}
\description{
Wrapper for \pkg{scran}'s cell cycle functions. Please ensure you are using
*ensembl_id* as your rownames in this dataset. Also ensure you are using
mitochondrial and ribosomal genes as controls.
}
