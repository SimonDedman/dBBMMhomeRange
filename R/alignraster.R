# Raster Alignment function
# Simon Dedman simondedman@gmail.com 2021-10-19

#' Automated Boosted Regression Tree modelling and mapping suite
#'
#' Automates delta log normal boosted regression trees abundance prediction.
#' Loops through all permutations of parameters provided (learning
#' rate, tree complexity, bag fraction), chooses the best, then simplifies it.
#' Generates line, dot and bar plots, and outputs these and the predictions
#' and a report of all variables used, statistics for tests, variable
#' interactions, predictors used and dropped, etc. If selected, generates
#' predicted abundance maps, and Unrepresentativeness surfaces.
#' See www.GitHub.com/SimonDedman/gbm.auto for issues, feedback, and development
#' suggestions. See SimonDedman.com for links to walkthrough paper, and papers
#' and thesis published using this package.
#'
#' @param folderroots Character vector of locations of folder roots output by dBBMMhomeRange. Function expects CRS.Rds file and a subfolder with the scaled raster.
#' @param foldernames Character vector names of folders corresponding to files in folderroots, i.e. the names of the objects, arrays, regions, etc.
#' @param pattern For input rasters from scaleraster. Default ".asc".
#' @param scalefolder For input rasters from scaleraster. Default "Scaled".
#' @param scaledname For input rasters from scaleraster. Default "All_Rasters_Scaled".
#' @param savefolder Single character entry, no trailing slash.
#' @param format Default "ascii".
#' @param datatype Default "FLT4S".
#' @param bylayer Default TRUE.
#' @param overwrite Default TRUE.
#' @param returnObj Logical. Return the scaled object to the parent environment? Default FALSE.
#' 
#' @return Line, dot and bar plots, a report of all variables used, statistics
#' for tests, variable interactions, predictors used and dropped, etc. If
#' selected generates predicted abundance maps, and Unrepresentativeness surface
#'
#' @details Errors and their origins:
#' @examples
#' \donttest{
#' # Not run
#' }
#'
#' @author Simon Dedman, \email{simondedman@@gmail.com}
#'
#' @export

#' @import magrittr
#' @importFrom sp bbox
#' @importFrom raster crs setMinMax raster extend writeRaster
#' @importFrom purrr map2
#' @importFrom terra project



# read in rasters & add to list####
alignraster <- function(folderroots = c("/home/simon/Dropbox/PostDoc Work/Rob Bullock accelerometer Lemons 2020.09/dBBMM ASCII/H", # character vector of locations of folder roots output by dBBMMhomeRange. Function expects CRS.Rds file and a subfolder with the scaled raster.
                                        "/home/simon/Dropbox/PostDoc Work/Rob Bullock accelerometer Lemons 2020.09/dBBMM ASCII/L",
                                        "/home/simon/Dropbox/PostDoc Work/Rob Bullock accelerometer Lemons 2020.09/dBBMM ASCII/M"),
                        foldernames = c("H", "L", "M"), # character vector names of folders corresponding to files in folderroots, i.e. the names of the objects, arrays, regions, etc.
                        pattern = ".asc", # for input rasters from scaleraster
                        scalefolder = "Scaled", # for input rasters from scaleraster
                        scaledname = "All_Rasters_Scaled", # for input rasters from scaleraster
                        savefolder = "/home/simon/Dropbox/PostDoc Work/Rob Bullock accelerometer Lemons 2020.09/dBBMM ASCII/Aligned", # single character entry, no trailing slash
                        format = "ascii", # save format
                        datatype = "FLT4S", # save format
                        bylayer = TRUE, # save format
                        overwrite = TRUE, # save format
                        returnObj = FALSE # return rasterlist object?
) {
  if (length(folderroots) != length(foldernames)) stop("length of folderroots and foldernames must be equal")
  # If folderroots or savefolder have a terminal slash, remove it, it's added later
  for (folders in folderroots) {
    if (substr(x = folders, start = nchar(folders), stop = nchar(folders)) == "/") folderroots[which(folderroots %in% folders)] = substr(x = folders, start = 1, stop = nchar(folders) - 1)
  }
  
  if (substr(x = savefolder, start = nchar(savefolder), stop = nchar(savefolder)) == "/") savefolder = substr(x = savefolder, start = 1, stop = nchar(savefolder) - 1)
  
  foldernames %<>% as.list()
  
  # Read in CRS files as list
  crslist <- as.list(paste0(folderroots, "/CRS.Rds")) %>%
    lapply(function(x) readRDS(x))
  names(crslist) <- foldernames # unnecessary?
  
  rasterlist <- 
    as.list(paste0(folderroots, "/", scalefolder, "/", scaledname, pattern)) %>% # Pull all raster names from folderroots into a list
    lapply(function(x) raster::raster(x)) %>% # read in rasters
    lapply(function(x) raster::setMinMax(x)) %>% # set minmax values
    # https://stackoverflow.com/questions/72063819/use-an-arrow-assignment-function-as-r-purrr-map2
    purrr::map2(crslist, ~ {raster::crs(.x) <- .y;.x}) %>%
    purrr::map2(foldernames, ~ {names(.x) <- .y;.x})
  
  # calculate full shared extent
  sharedextent <- lapply(rasterlist, function(x) as.vector(sp::bbox(x))) # xmin #ymin #xmax #ymax
  sharedextent <- data.frame(t(sapply(sharedextent, c)))
  sharedextent <- c(min(sharedextent[1]), # xmin
                    max(sharedextent[3]), # xmax
                    min(sharedextent[2]), # ymin
                    max(sharedextent[4])) # ymax
  
  rasterlist %<>%
    lapply(function(x) raster::extend(x, sharedextent)) # align to same spatial extent
  
  # Convert to SpatRaster format to be used by {terra}
  rasterlist %<>% lapply(function(x) as(x, "SpatRaster"))
  
  # Reproject all rasters simultaneously
  rasterlist %<>% lapply(function(x) project(x, y = rasterlist[[length(rasterlist)]]))
  
  # Convert back to RasterLayer to save CRS
  rasterlist %<>% lapply(function(x) raster::raster(x))
  
  # Save CRS
  rasterlistCRS <- sp::CRS(sp::proj4string(rasterlist[[1]]))
  class(rasterlistCRS) # CRS
  write.csv(sp::proj4string(rasterlistCRS), paste0(savefolder, "/", "CRS.csv"), row.names = FALSE)
  saveRDS(rasterlistCRS, file = paste0(savefolder, "/", "CRS.Rds"))
  
  rasterlist %<>% lapply(function(x) raster::writeRaster(x = x, # resave individual rasters
                                                         filename = paste0(savefolder, "/", names(x)), # , pattern: removed ability to resave as different format
                                                         # error: adds X to start of numerical named objects####
                                                         format = format,
                                                         datatype = datatype,
                                                         if (format != "CDF") bylayer = bylayer,
                                                         overwrite = overwrite))
  
  if (returnObj) return(rasterlist)
} # close function