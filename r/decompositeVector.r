 ## R script for converting diff to annual scalar (m / a) after adjusting.
## Takayuki NUIMURA 2012

t <- proc.time()

## <preamble>

library(rgdal)

## </preamble>


## <subfunction>

source("../myfunc/readGTIFF.r")

## </subfunction>


## <parameter>


work.dir <- "/work"

## Glacier area mask
gl.area.filepath <- "gl_area_grid2.5.tif"

## Input data list as CSV
# ex. 
# rootname,start,end,diff.year,cellsize
# disp20081024_20101203,10/24/2008,12/03/2010,2.1,2.5
# disp20101024_20111203,10/24/2010,12/03/2011,1.1,2.5
list.csv.filepath <- "lirung_disp_list4alos.csv"


## Threshold values
corr.th <- 0.6
outlier.th <- 100
magnitude.th <- 6

## </parameter>


## <preprocessing>

disp.list <- read.csv(list.csv.filepath)
rootname.list <- disp.list[, 1]
duration.list <- disp.list[, 4]
cellsize.list <- disp.list[, 5]



## </preprocessing>

## Reading target extent information
target <- GDALinfo(paste(work.dir, "/", as.character(rootname.list[1]), ".tif", sep=""))
w <- target["ll.x"]
s <- target["ll.y"]
e <- target["ll.x"] + target["columns"] * target["res.x"]
n <- target["ll.y"] + target["rows"] * target["res.y"]


gl.area.obj <- readGTIFF(gl.area.filepath, w, s, e, n)
gl.area <- gl.area.obj$band1

for (i in 1:length(rootname.list)) {
    rootname <- as.character(rootname.list[i])
    cat("Processing: ", rootname, "\n")


    ## <processing>

    ## Input
    disp.filename <- paste(rootname, ".tif", sep="")

    ## Output
    disp.summary.filename <- paste(rootname, "_summary.csv", sep="")
    disp.x.filename <- paste(rootname, "_x", cellsize.list[i], ".tif", sep="")
    disp.y.filename <- paste(rootname, "_y", cellsize.list[i], ".tif", sep="")
    corr.filename <- paste(rootname, "_corr", cellsize.list[i], ".tif", sep="")
    scalar.filename <- paste(rootname, "_scalar", cellsize.list[i], ".tif", sep="")
    direct.filename <- paste(rootname, "_direct", cellsize.list[i], ".tif", sep="")

    disp.filepath <- paste(work.dir, "/", disp.filename, sep="")
    disp.summary.filepath <- paste(work.dir, "/", disp.summary.filename, sep="")
    disp.x.filepath <- paste(work.dir, "/", disp.x.filename, sep="")
    disp.y.filepath <- paste(work.dir, "/", disp.y.filename, sep="")
    corr.filepath <- paste(work.dir, "/", corr.filename, sep="")
    scalar.filepath <- paste(work.dir, "/", scalar.filename, sep="")
    direct.filepath <- paste(work.dir, "/", direct.filename, sep="")

    ## Skip processed scene
    if (file.exists(disp.x.filepath)) {
        cat(disp.filename, " has already been processed! \n")
    } else if (!file.exists(disp.filepath)) {
        ## Skip unprepared scene
        cat(disp.filename, " has not yet been prepared! \n")
    } else {

        disp.x.obj <- readGDAL(disp.filepath, band=1)
        disp.y.obj <- readGDAL(disp.filepath, band=2)
        corr.obj <- readGDAL(disp.filepath, band=3)
        scalar.obj <- disp.x.obj #Recycling object
        direct.obj <- disp.x.obj #Recycling object

        disp.x <- disp.x.obj$band1## * cellsize.list[i]
        disp.y <- disp.y.obj$band1## * cellsize.list[i]
        corr <- corr.obj$band1

        ## Normalize duration to annual
        disp.x <- disp.x / duration.list[i]
        disp.y <- disp.y / duration.list[i]

        ## Correlation filter
        disp.x[corr < corr.th] <- NA
        disp.y[corr < corr.th] <- NA

        ## Separation for on and off glacier
        disp.x.bedrock <- disp.x
        disp.y.bedrock <- disp.y
        disp.x.glacier <- disp.x
        disp.y.glacier <- disp.y
        disp.x.bedrock[!is.na(gl.area)] <- NA
        disp.y.bedrock[!is.na(gl.area)] <- NA
        disp.x.glacier[is.na(gl.area)] <- NA
        disp.y.glacier[is.na(gl.area)] <- NA


        ## Static summary before calibration
        disp.x.bedrock.median <- median(disp.x.bedrock, na.rm=T)
        disp.y.bedrock.median <- median(disp.y.bedrock, na.rm=T)
        disp.x.bedrock.sd <- sd(disp.x.bedrock, na.rm=T)
        disp.y.bedrock.sd <- sd(disp.y.bedrock, na.rm=T)
        disp.x.glacier.median <- median(disp.x.glacier, na.rm=T)
        disp.y.glacier.median <- median(disp.y.glacier, na.rm=T)
        disp.x.glacier.sd <- sd(disp.x.glacier, na.rm=T)
        disp.y.glacier.sd <- sd(disp.y.glacier, na.rm=T)




        bias.x <- disp.x.bedrock.median
        bias.y <- disp.y.bedrock.median

        disp.x.bedrock <- disp.x.bedrock - bias.x
        disp.y.bedrock <- disp.y.bedrock - bias.y
        disp.x.glacier <- disp.x.glacier - bias.x
        disp.y.glacier <- disp.y.glacier - bias.y
        disp.x <- disp.x - bias.x
        disp.y <- disp.y - bias.y

        #Excluding outlier value.
        disp.x.bedrock[abs(disp.x.bedrock) > outlier.th] <- NA
        disp.y.bedrock[abs(disp.y.bedrock) > outlier.th] <- NA

        disp.x.bedrock.sd.calib <- sd(disp.x.bedrock, na.rm=T)
        disp.y.bedrock.sd.calib <- sd(disp.y.bedrock, na.rm=T)

        #Excluding anomaly value outside X sigma.
        disp.x.bedrock[abs(disp.x.bedrock) > disp.x.bedrock.sd.calib * magnitude.th] <- NA
        disp.y.bedrock[abs(disp.y.bedrock) > disp.y.bedrock.sd.calib * magnitude.th] <- NA
        disp.x.glacier[abs(disp.x.glacier) > disp.x.bedrock.sd.calib * magnitude.th] <- NA
        disp.y.glacier[abs(disp.y.glacier) > disp.y.bedrock.sd.calib * magnitude.th] <- NA
        disp.x[abs(disp.x) > disp.x.bedrock.sd.calib * magnitude.th] <- NA
        disp.y[abs(disp.y) > disp.y.bedrock.sd.calib * magnitude.th] <- NA

        ## Static summary after calibration
        disp.x.bedrock.median.calib <- median(disp.x.bedrock, na.rm=T)
        disp.y.bedrock.median.calib <- median(disp.y.bedrock, na.rm=T)
        disp.x.bedrock.sd.calib <- sd(disp.x.bedrock, na.rm=T)
        disp.y.bedrock.sd.calib <- sd(disp.y.bedrock, na.rm=T)
        disp.x.glacier.median.calib <- median(disp.x.glacier, na.rm=T)
        disp.y.glacier.median.calib <- median(disp.y.glacier, na.rm=T)
        disp.x.glacier.sd.calib <- sd(disp.x.glacier, na.rm=T)
        disp.y.glacier.sd.calib <- sd(disp.y.glacier, na.rm=T)

        stats.summary <- data.frame(
                         pre.calib <- c(
                                      disp.x.bedrock.median,
                                      disp.y.bedrock.median,
                                      disp.x.bedrock.sd,
                                      disp.y.bedrock.sd,
                                      disp.x.glacier.median,
                                      disp.y.glacier.median,
                                      disp.x.glacier.sd,
                                      disp.y.glacier.sd
                                      ),
                         post.calib <- c(
                                       disp.x.bedrock.median.calib,
                                       disp.y.bedrock.median.calib,
                                       disp.x.bedrock.sd.calib,
                                       disp.y.bedrock.sd.calib,
                                       disp.x.glacier.median.calib,
                                       disp.y.glacier.median.calib,
                                       disp.x.glacier.sd.calib,
                                       disp.y.glacier.sd.calib
                                       )
                         )
        colnames(stats.summary) <- c("pre.calib", "post.calib")
        rownames(stats.summary) <- c("x.bedrock.median", "y.bedrock.median", "x.bedrock.sd", "y.bedrock.sd", "x.glacier.median", "y.glacier.median", "x.glacier.sd", "y.glacier.sd")

        #Scalar calculation
        scalar <- sqrt(disp.x^2 + disp.y^2)

        ## Direction calculation
        direct <- atan2(disp.y, disp.x) / pi * 180


        disp.x[is.na(disp.x)] <- -9999
        disp.y[is.na(disp.y)] <- -9999
        corr[is.na(corr)] <- -9999
        scalar[is.na(scalar)] <- -9999
        direct[is.na(direct)] <- -9999

        disp.x.obj@data <- data.frame(band1=disp.x)
        disp.y.obj@data <- data.frame(band1=disp.y)
        corr.obj@data <- data.frame(band1=corr)
        scalar.obj@data <- data.frame(band1=scalar)
        direct.obj@data <- data.frame(band1=direct)

        ## </processing>


        ## <output>

        write.csv(stats.summary, disp.summary.filepath)
        writeGDAL(disp.x.obj, disp.x.filepath, mvFlag=-9999)
        writeGDAL(disp.y.obj, disp.y.filepath, mvFlag=-9999)
        writeGDAL(corr.obj, corr.filepath, mvFlag=-9999)
        writeGDAL(scalar.obj, scalar.filepath, mvFlag=-9999)
        writeGDAL(direct.obj, direct.filepath, mvFlag=-9999)

        ## </output>


    }
}

print(proc.time() - t)

rm(list=ls())
