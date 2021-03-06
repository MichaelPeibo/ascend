#' GenerateControlMetrics
#'
#' Function called by \code{\link{GenerateMetrics}} to generate metrics for control-related statistics.
#'
#' @param x Name of a control listed in Controls.
#' @param expression.matrix Transcript counts stored in a sparse matrix object.
#' @param control.list A list of controls supplied by the user.
#' @param total.counts List of total counts generated by \code{\link{GenerateMetrics}}.
#'
GenerateControlMetrics <- function(x, expression.matrix = NULL, control.list = NULL, total.counts = NULL) {
    control.group <- control.list[[x]]
    control.bool <- rownames(expression.matrix) %in% control.group
    control.transcript.counts <- expression.matrix[control.bool, ]
    control.transcript.total.counts <- Matrix::colSums(control.transcript.counts)
    control.pt.matrix <- (control.transcript.total.counts/total.counts) * 100
    named.list <- list(ControlTranscriptCounts = control.transcript.total.counts, PercentageTotalCounts = control.pt.matrix)
    output.list <- list()
    output.list[[x]] <- named.list
    return(output.list)
}

#' GenerateMetrics
#'
#' This function generates the following set of values per cell:
#' \itemize{
#' \item{\strong{Total Counts}: Total number of expressed transcripts per cell}
#' \item{\strong{Total Feature Counts per Cell}: Number of non-control genes expressed per cell}
#' \item{\strong{Total Expression}: Total number of expressed transcripts in the dataset}
#' \item{\strong{Top Gene List}: Entire list of genes organised from most expressed to least expressed across the entire dataset}
#' \item{\strong{Control Transcript Counts}: Total sum of control transcript counts per cell}
#' \item{\strong{Percentage Total Counts}: Percentage of transcripts originating from control genes per cell}
#' \item{\strong{AverageCounts}: Average transcript count for a gene}
#' \item{\strong{GenesPerCell}: Number of unique transcripts expressed by a cell}
#' \item{\strong{CellsPerGene}: Number of cells expressing a gene}
#' \item{\strong{CountsPerGene}: Total number of transcripts produced by that gene expressed by all cells}
#' \item{\strong{Mean Gene Expression}: Mean expression level of a gene across the entire dataset}
#' }
#'
#' This function is called by \code{\link{NewEMSet}} and generates metrics for the new expression matrix.
#' This function can also be called independantly, to update the metrics for a \linkS4class{EMSet} object.
#' @include ascend_objects.R
#' @export
setGeneric(name = "GenerateMetrics", def = function(object) {
    standardGeneric("GenerateMetrics")
})

setMethod("GenerateMetrics", signature("EMSet"), function(object) {
    # Retrieve required objects from EMSet
    expression.matrix <- object@ExpressionMatrix
    control.list <- object@Controls
    metrics.list <- list()

    ### Calculate library size per cell
    total.counts <- Matrix::colSums(expression.matrix)

    # User may have not supplied controls
    if (length(control.list) > 0) {
        # Prepare outputs
        control.transcript.counts.list <- list()
        percentage.lists.counts.list <- list()

        # Generate Metrics
        print("Calculating control metrics...")
        control.counts <- BiocParallel::bplapply(names(control.list), GenerateControlMetrics, expression.matrix = expression.matrix, control.list = control.list,
            total.counts = total.counts)

        # Unpackage stats
        unpacked.control.counts <- unlist(control.counts, recursive = FALSE)
        percentage.lists.counts.list <- lapply(names(unpacked.control.counts), function(x) unpacked.control.counts[[x]][["PercentageTotalCounts"]])
        names(percentage.lists.counts.list) <- names(unpacked.control.counts)
        control.transcript.counts.list <- lapply(names(unpacked.control.counts), function(x) unpacked.control.counts[[x]][["ControlTranscriptCounts"]])
        names(control.transcript.counts.list) <- names(unpacked.control.counts)

        # Calculate feature counts (Exclude controls)
        control.bool <- rownames(expression.matrix) %in% (unlist(control.list, use.names = FALSE))

        if (any(control.bool)) {
            endogenous.exprs.mtx <- expression.matrix[!control.bool, ]
        } else {
            endogenous.exprs.mtx <- expression.matrix
            percentage.lists.counts.list <- lapply(percentage.lists.counts.list, function(x) ifelse(is.na(x), 0, x))
            control.transcript.counts.list <- lapply(control.transcript.counts.list, function(x) ifelse(is.na(x), 0, x))
        }

        total.features.counts.per.cell <- Matrix::colSums(endogenous.exprs.mtx != 0)
        metrics.list <- c(metrics.list, list(TotalFeatureCountsPerCell = total.features.counts.per.cell, ControlTranscriptCounts = control.transcript.counts.list,
            PercentageTotalCounts = percentage.lists.counts.list))
    } else {
        object@Log$Controls <- FALSE
    }

    counts.per.gene <- Matrix::rowSums(expression.matrix)
    average.counts <- Matrix::rowMeans(expression.matrix)
    genes.per.cell <- Matrix::colSums(expression.matrix != 0)
    cells.per.gene <- Matrix::rowSums(expression.matrix != 0)
    mean.gene.expression <- Matrix::rowMeans(expression.matrix)

    # Calculate top gene expression
    total.expression <- sum(expression.matrix)
    sorted.counts.per.gene <- sort(counts.per.gene, decreasing = TRUE)
    top.gene.list <- names(sorted.counts.per.gene)
    top.gene.bool <- rownames(expression.matrix) %in% top.gene.list
    sorted.exprs.mtx <- expression.matrix[top.gene.bool, ]
    top.genes.percentage <- 100 * sum(sorted.counts.per.gene)/total.expression

    # Load generated values into the Metrics slot
    metrics.list <- c(metrics.list, list(TotalCounts = total.counts, TotalExpression = total.expression, TopGeneList = top.gene.list, TopGenesPercentage = top.genes.percentage,
        AverageCounts = average.counts, GenesPerCell = genes.per.cell, CellsPerGene = cells.per.gene, CountsPerGene = counts.per.gene, MeanGeneExpression = mean.gene.expression))
    remove(expression.matrix)
    object@Metrics <- metrics.list
    return(object)
})

# Called by ascend object creation. Adds the control information to the data frame.
AddControlInfo <- function(gene.information, controls) {
    # Verify controls are in the cell information data frame
    gene.information$control <- rep(FALSE, nrow(gene.information))
    gene.information[gene.information[, 1] %in% unlist(controls), ]$control <- TRUE
    return(gene.information)
}

#' ConvertGeneAnnotation
#'
#' Convert gene identifiers used in this \linkS4class{EMSet} to identifiers used in another column of a dataframe stored in the GeneAnnotation slot.
#'
#' @param object A \linkS4class{EMSet} object.
#' @param old.annotation Name of the column containing the current gene annotations.
#' @param new.annotation Name of the column you would like to convert the gene annotations to.
#' @include ascend_objects.R
#' @export
setGeneric(name = "ConvertGeneAnnotation", def = function(object, old.annotation, new.annotation) {
    standardGeneric("ConvertGeneAnnotation")
})

setMethod("ConvertGeneAnnotation", signature("EMSet"), function(object, old.annotation, new.annotation) {
    # Get currently-used gene identifiers Load Gene Annotation
    gene.annotation <- object@GeneInformation

    ## From expression matrix
    present.rownames <- rownames(object@ExpressionMatrix)

    ## From control lists
    control.list <- object@Controls

    # Retrieve new values
    new.identifiers <- gene.annotation[, new.annotation]

    ## Rename expression matrix
    rownames(object@ExpressionMatrix) <- new.identifiers

    # Convert control list
    if (length(control.list) > 0) {
      updated.control.list <- sapply(names(control.list), function(control.name){gene.annotation[, new.annotation][which(gene.annotation[, old.annotation] %in% control.list[[control.name]])]}, USE.NAMES = TRUE)
      object@Controls <- updated.control.list
    }

    # Move new annotation to column 1
    updated.gene.info <- gene.annotation %>% dplyr::select(new.annotation, dplyr::everything())
    object@GeneInformation <- updated.gene.info
    
    # Regenerate metrics
    object <- GenerateMetrics(object)
    
    return(object)
})

#' ExcludeControl
#'
#' Removes the specified control from the expression matrix.
#' @param object A \linkS4class{EMSet} object. It is recommended that you run this step after this object has undergone filtering.
#' @param control.name Name of the control set you want to remove from the dataset.
#' @export
#'
setGeneric(name = "ExcludeControl", def = function(object, control.name) {
    standardGeneric("ExcludeControl")
})

setMethod("ExcludeControl", signature("EMSet"), function(object, control.name) {
    # Identify indices of control genes in the current expression matrix Keep this matrix sparse for faster processing power
    expression.matrix <- object@ExpressionMatrix
    control.list <- object@Controls

    # We can sync up the slots once we update the expression matrix Convert the control list into a boolean so we can remove rows from the sparse matrix
    control.list <- object@Controls[[control.name]]
    control.in.mtx <- rownames(expression.matrix) %in% control.list

    # Remove control genes from the matrix by identified matrices
    endogenous.exprs.mtx <- expression.matrix[!control.in.mtx, ]

    # Reload the expression matrix with the updated matrix
    object@ExpressionMatrix <- endogenous.exprs.mtx
    object <- SyncSlots(object)

    # Update the log
    updated.log <- list()
    updated.log[[control.name]] <- TRUE

    # Update the controls
    object@Controls[[control.name]] <- NULL

    # Update ExcludeControls
    if (is.null(object@Log$ExcludeControls)) {
        remove.log <- updated.log
        object@Log$ExcludeControls <- remove.log
    } else {
        object@Log$ExcludeControls <- c(object@Log$ExcludeControls, updated.log)
    }

    # Update Controls
    if (length(object@Controls) == 0) {
        object@Log$Controls <- FALSE
    }

    # Add removed genes to a list of removed genes
    if (is.null(object@Log$RemovedGenes)) {
        object@Log$RemovedGenes <- control.list
    } else {
        object@Log$RemovedGenes <- c(object@Log$RemovedGenes, control.list)
    }
    # Regenerate metrics and return the updated object
    object <- GenerateMetrics(object)
    return(object)
})

#' DisplayLog
#'
#' Print out the log of an \linkS4class{EMSet}.
#' @include ascend_objects.R
#' @export
setGeneric(name = "DisplayLog", def = function(object) {
    standardGeneric("DisplayLog")
})

setMethod("DisplayLog", signature("EMSet"), function(object) {
    log <- object@Log
    print(log)
})
