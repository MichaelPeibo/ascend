#' scranNormalise
#'
#' Normalise an \linkS4class{EMSet} with \pkg{scran}'s deconvolution method by Lun et al. 2016.
#'
#' @details Pooling method of cells is influenced by the size of the cell population.
#' For datasets containing less than 20000 cells, this function will run \code{\link[scran]{computeSumFactors}}
#' with preset sizes of 40, 60, 80 and 100.
#' For datasets containing over 20000 cells, you have the option to use \code{\link[scran]{quickCluster}} to
#' form pools of cells to feed into \code{\link[scran]{computeSumFactors}}. This method is slower and may fail
#' with very large datasets containing over 40000 cells. If \code{\link[scran]{quickCluster}} is not selected,
#' cells will be randomly assigned to a group.
#'
#' @param object An \linkS4class{EMSet} that has not undergone normalisation.
#' @param quickCluster TRUE: Use scran's quickCluster method FALSE: Use 
#' randomly-assigned groups. Default: FALSE
#' @param min.mean Threshold for average counts. This argument is for the 
#' \code{\link{computeSumFactors}} function from \pkg{scran}. The value of 1 is
#' recommended for read count data, while the default value of 1e-5 is best for 
#' UMI data. Default: 1e-5. This argument is only used for newer versions of 
#' \pkg{scran}.
#' @export
#'
scranNormalise <- function(object, quickCluster = FALSE, min.mean = 1e-5) {
  # Scran Normalise Manual
  if (!is.null(object@Log$NormalisationMethod)) {
    stop("This data is already normalised.")
  }
  
  # Check version of scran - this is to ensure we are using the right object
  if (packageVersion("scater") < "1.6.1"){
    print("Converting EMSet to SCESet...")
    sce.obj <- ConvertToSCESet(object, control.list = object@Controls)
    normalised.obj <- SCESetnormalise(sce.obj, object, quickCluster = quickCluster)
  } else{
    print("Converting EMSet to SingleCellExperiment...")
    sce.obj <- ConvertToSCE(object, control.list = object@Controls)
    normalised.obj <- SCEnormalise(sce.obj, object, quickCluster = quickCluster, min.mean = min.mean)
  }

  return(normalised.obj)
}

#' NormWithinBatch
#'
#' Called by NormaliseBatches. Performs normalisation within a batch.
#'
NormWithinBatch <- function(batch.id, expression.matrix = NULL, cell.info = NULL) {
    # Function called by NormaliseBatches
    barcodes <- cell.info[, 1][which(cell.info[, 2] == batch.id)]
    sub.mtx <- expression.matrix[, barcodes]
    
    # Collapse all cells into one cell
    collapsed.mtx <- rowSums(sub.mtx)
    norm.factor <- sum(collapsed.mtx)
    
    ## Scale sub-matrix to normalisation factor
    cpm.mtx <- Matrix::t(Matrix::t(sub.mtx)/norm.factor)
    
    # Output to list for further calculations
    output.list <- list(NormalisationFactor = norm.factor, CpmMatrix = cpm.mtx)
    return(output.list)
}

#' NormaliseBatches
#'
#' Normalise counts to remove batch effects. This normalisation method is for
#' experiments where data from batches of different samples are combined without
#' undergoing library equalisation.
#'
#' This step must be done prior to any filtering and normalisation between cells.
#'
#' @param object An \linkS4class{EMSet} object.
#' @export
#'
NormaliseBatches <- function(object) {
    if (!is.null(object@Log$NormaliseBatches)) {
        stop("This data is already normalised.")
    }
    
    # Retrieve variables from EMSet object
    exprs.mtx <- GetExpressionMatrix(object, "matrix")
    cell.info <- GetCellInfo(object)
    unique.batch.identifiers <- unique(cell.info[, 2])
    
    # Loop to get batch-specific data PARALLEL
    print("Retrieving batch-specific data...")
    batch.data <- BiocParallel::bplapply(unique.batch.identifiers, NormWithinBatch, expression.matrix = exprs.mtx, cell.info = cell.info)
    
    # Unpacking results
    print("Scaling data...")
    norm.factors <- unlist(lapply(batch.data, function(x) x$NormalisationFactor))
    median.size <- median(norm.factors)
    sub.matrix.list <- lapply(batch.data, function(x) x$CpmMatrix)
    cpm.matrix <- data.frame(sub.matrix.list)
    scaled.matrix <- cpm.matrix * median.size
    
    # Load back into EMSet and write metrics
    print("Returning object...")
    colnames(scaled.matrix) <- cell.info[, 1]
    object@ExpressionMatrix <- ConvertMatrix(scaled.matrix, format = "sparseMatrix")
    object@Log$NormaliseBatches <- TRUE
    updated.object <- GenerateMetrics(object)
    return(updated.object)
}

#' NormaliseLibSize
#'
#' Normalise library sizes by scaling.
#' @param object A \linkS4class{EMSet} object. Please remove spike-ins from the expression matrix before normalising.
#' @export
#'
NormaliseLibSize <- function(object) {
    expression.matrix <- as.matrix(object@ExpressionMatrix)
    norm.factor <- colSums(expression.matrix)
    median.size <- median(norm.factor)
    
    unscaled.matrix <- Matrix::t(Matrix::t(expression.matrix)/norm.factor)
    normalised.exprs.mtx <- unscaled.matrix * median.size
    object@Log <- c(object@Log, list(NormaliseLibSize = TRUE))
    object@ExpressionMatrix <- ConvertMatrix(normalised.exprs.mtx, format = "sparseMatrix")
    new.object <- GenerateMetrics(object)
    new.object@Log <- c(object@Log, list(NormalisationMethod = "NormaliseLibSize"))
    return(new.object)
}


## SUBFUNCTIONS FOR NormaliseByRLE
#' CalculateNormFactor
#'
#' Calculate the normalisation factor between all cells.
#'
CalcNormFactor <- function(x, geo.means) {
    x.geo.means <- cbind(x, geo.means)
    x.geo.means <- x.geo.means[(x.geo.means[, 1] > 0), ]
    non.zero.median <- median(apply(x.geo.means, 1, function(y) {
        y <- as.vector(y)
        y[1]/y[2]
    }))
    return(non.zero.median)
}

#' CalcGeoMeans
#'
#' Calculate the geometric mean around a point.
#'
CalcGeoMeans <- function(x) {
    x <- x[x > 0]
    x <- exp(mean(log(x)))
    return(x)
}

#' NormaliseByRLE
#'
#' Normalisation of expression between cells, by scaling to relative log expression.
#' This method assumes all genes express a pseudo value higher than 0, and also assumes most genes
#'are not differentially expressed. Only counts that are greater than zero are considered in this normalisation method.
#' @param object A \linkS4class{EMSet} object that has undergone filtering. Please ensure spike-ins have been removed before using this function.
#' @export
#'
NormaliseByRLE <- function(object) {
    if (!is.null(object@Log$NormalisationMethod)) {
        stop("This data is already normalised.")
    }
    expression.matrix <- GetExpressionMatrix(object, format = "matrix")
    
    print("Calculating geometric means...")
    geo.means <- apply(expression.matrix, 1, CalcGeoMeans)
    
    print("Calculating normalisation factors...")
    norm.factor <- apply(expression.matrix, 2, function(x) CalcNormFactor(x, geo.means))
    
    print("Normalising data...")
    normalised.matrix <- Matrix::t(Matrix::t(expression.matrix)/norm.factor)
    object@ExpressionMatrix <- ConvertMatrix(normalised.matrix, "sparseMatrix")
    object@Log <- c(object@Log, list(NormalisationMethod = "NormaliseByRLE"))
    return(object)
}
