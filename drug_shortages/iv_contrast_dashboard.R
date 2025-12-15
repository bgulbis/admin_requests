# print(getwd())

# set output directory
if (Sys.info()['sysname'] == "Windows") {
    out_dir <- "W:/HER/HER - Pharmacy/Forecasts/IV Contrast"
} else if (Sys.info()['sysname'] == "Darwin") { # macOS
    out_dir <- "/Volumes/public/HER/HER - Pharmacy/Forecasts/IV Contrast"
}

if (!dir.exists(out_dir)) {
    stop("Network drive not available.")
}

source("drug_shortages/src/iv_contrast_forecast.R")

rmarkdown::render(
    input = "drug_shortages/report/iv_contrast_forecast.Rmd",
    output_file = "iv_contrast_forecast.html",
    output_dir = out_dir
)
