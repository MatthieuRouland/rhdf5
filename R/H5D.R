
H5Dcreate <- function( h5loc, name, dtype_id, h5space, lcpl=NULL, dcpl=NULL, dapl=NULL ) {
  h5checktype(h5loc, "loc")
  if (length(name)!=1 || !is.character(name)) stop("'name' must be a character string of length 1")
  ## dont check if we have an H5T identifier already    
  if (!grepl(pattern = "^[[:digit:]]+$", dtype_id)) {
    dtype_id<- h5checkConstants( "H5T", dtype_id)
  }
  h5checktype(h5space, "dataspace")
  lcpl = h5checktypeAndPLC(lcpl, "H5P_LINK_CREATE", allowNULL = TRUE)
  dcpl = h5checktypeAndPLC(dcpl, "H5P_DATASET_CREATE", allowNULL = TRUE)
  dapl = h5checktypeAndPLC(dapl, "H5P_DATASET_ACCESS", allowNULL = TRUE)
  did <- .Call("_H5Dcreate", h5loc@ID, name, dtype_id, h5space@ID, lcpl@ID, dcpl@ID, dapl@ID, PACKAGE='rhdf5')
  if (did > 0) {
    h5dataset = new("H5IdComponent", ID = did, native = h5loc@native)
  } else {
    message("HDF5: unable to create dataset")
    h5dataset = FALSE
  }
  invisible(h5dataset)
}

H5Dopen <- function( h5loc, name, dapl = NULL ) {
  h5checktype(h5loc, "loc")
  if (length(name)!=1 || !is.character(name)) stop("'filename' must be a character string of length 1")
  dapl = h5checktypeAndPLC(dapl, "H5P_DATASET_ACCESS", allowNULL = TRUE)
  did <- .Call("_H5Dopen", h5loc@ID, name, dapl@ID, PACKAGE='rhdf5')
  if (as.numeric(did) > 0) {
    h5dataset = new("H5IdComponent", ID = did, native = h5loc@native)
  } else {
    message("HDF5: unable to open dataset")
    h5dataset = FALSE
  }
  invisible(h5dataset)
}

H5Dclose <- function( h5dataset ) {
  h5checktype(h5dataset, "dataset")
  invisible(.Call("_H5Dclose", h5dataset@ID, PACKAGE='rhdf5'))
}

H5Dget_type <- function( h5dataset ) {
  h5checktype(h5dataset, "dataset")
  tid <- .Call("_H5Dget_type", h5dataset@ID, PACKAGE='rhdf5')
  invisible(tid)
}

H5Dget_create_plist <- function( h5dataset ) {
  h5checktype(h5dataset, "dataset")
  pid <- .Call("_H5Dget_create_plist", h5dataset@ID, PACKAGE='rhdf5')
  if (pid > 0) {
    h5plist = new("H5IdComponent", ID = pid, native = h5dataset@native)
  } else {
    message("HDF5: unable to create property list")
    h5plist = FALSE
  }
  invisible(h5plist)
}

H5Dget_space <- function( h5dataset ) {
  h5checktype(h5dataset, "dataset")
  sid <- .Call("_H5Dget_space", h5dataset@ID, PACKAGE='rhdf5')
  if (sid > 0) {
    h5space = new("H5IdComponent", ID = sid, native = h5dataset@native)
  } else {
    message("HDF5: unable to create simple data space")
    h5space = FALSE
  }
  invisible(h5space)
}

H5Dget_storage_size <- function( h5dataset ) {
  h5checktype(h5dataset, "dataset")
  size <- .Call("_H5Dget_storage_size", h5dataset@ID, PACKAGE='rhdf5')
  return(size)
}

.postProcessDataSet <- function(h5dataset, res) {
  
  ## handle NA values in logical dataset
  if (H5Aexists(h5obj=h5dataset, name="storage.mode")) {
    att <- H5Aopen(h5obj=h5dataset, name="storage.mode")
    on.exit(H5Aclose(att))
    if (H5Aread(h5attribute = att) == "logical") {
      na_idx <- which(res == -128)
      if(any(na_idx)) {
        res[na_idx] <- NA_integer_
      }
      storage.mode(res) = "logical"
    }
  }
    
  ## warn about NA conversion for integers if 'rhdf5.NA-OK' is missing
  if(!H5Aexists(h5obj = h5dataset, name = "rhdf5-NA.OK")) {
    if( (storage.mode(res) == "integer" || is(res, "integer64")) && any(is.na(res))) {
      if(storage.mode(res) == "integer") {
        na_val <- "-2^31"
      } else if (is(res, "integer64")) {
        na_val <- "-2^63"
      } else { ## we should never end up here
        na_val <- "DEFAULT"
      }
      message("The value ", na_val, " was detected in the dataset.\n",
              "This has been converted to NA within R.")
    }
  }

  res
}

H5Dread <- function( h5dataset, h5spaceFile=NULL, h5spaceMem=NULL, buf = NULL, compoundAsDataFrame = TRUE,
                     bit64conversion, drop = FALSE ) {
  h5checktype(h5dataset, "dataset")
  h5checktypeOrNULL(h5spaceFile, "dataspace")
  h5checktypeOrNULL(h5spaceMem, "dataspace")
  if (is.null(h5spaceMem)) { sidMem <- NULL } else { sidMem <- h5spaceMem@ID }
  if (is.null(h5spaceFile)) { sidFile <- NULL } else { sidFile <- h5spaceFile@ID }
  if (missing(bit64conversion)) {
    bit64conv = 0L
  } else {
    bit64conv = switch(bit64conversion, int = 0L, double = 1L, bit64 = 2L, default = 0L)
  }
  if (bit64conv == 2L) {
    if (!requireNamespace("bit64",quietly=TRUE)) {
      stop("install package 'bit64' before using bit64conversion='bit64'")
    }
  }
  
  res <- .Call("_H5Dread", h5dataset@ID, sidFile, sidMem, buf, compoundAsDataFrame, 
               bit64conv, drop, h5dataset@native, PACKAGE='rhdf5')
  
  res <- .postProcessDataSet(h5dataset, res)
  res
}

H5Dwrite <- function( h5dataset, buf, h5spaceMem=NULL, h5spaceFile=NULL ) {
  h5checktype(h5dataset, "dataset")
  h5checktypeOrNULL(h5spaceFile, "dataspace")
  h5checktypeOrNULL(h5spaceMem, "dataspace")
  if (is.null(h5spaceMem)) { sidMem <- NULL } else { sidMem <- h5spaceMem@ID }
  if (is.null(h5spaceFile)) { sidFile <- NULL } else { sidFile <- h5spaceFile@ID }
  invisible(.Call("_H5Dwrite", h5dataset@ID, buf, sidFile, sidMem, h5dataset@native, PACKAGE='rhdf5'))
}

H5Dset_extent <- function( h5dataset, size) {
    h5checktype(h5dataset, "dataset")
    size <- as.numeric(size)
    if (!h5dataset@native) size <- rev(size)
    invisible(.Call("_H5Dset_extent", h5dataset@ID, size, PACKAGE='rhdf5'))
}

H5Dchunk_dims <- function(h5dataset) {
    h5checktype(h5dataset, "dataset")
    
    pid <- H5Dget_create_plist(h5dataset)
    on.exit(H5Pclose(pid), add=TRUE)
    
    if (H5Pget_layout(pid) != "H5D_CHUNKED")
        return(NULL)
    else 
        return(rev(H5Pget_chunk(pid)))
}
    