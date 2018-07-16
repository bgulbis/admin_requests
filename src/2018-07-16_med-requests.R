library(tidyverse)
library(lubridate)
library(readxl)

file_nm <- "data/raw/2018-07_med-requests/2018-06-01_2018-07-11_med-requests.xlsx"
data_reqs <- file_nm %>%
    read_excel() %>%
    rename_all(str_to_lower)
    
data_reqs %>%
    write_rds(path = "data/tidy/2018-07_med-requests/med-requests.Rds")
