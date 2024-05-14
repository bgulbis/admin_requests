library(tidyverse)
library(readxl)
library(lubridate)
library(mbohelpr)
library(openxlsx)

f <- set_data_path("admin_requests", "")

raw_fins_feb <- read_excel(paste0(f, "raw/med_hist_fins.xlsx"), sheet = 1) |>
    rename_all(str_to_lower)

mbo_feb <- concat_encounters(raw_fins_feb$fin)
print(mbo_feb)

raw_fins_mar <- read_excel(paste0(f, "raw/med_hist_fins.xlsx"), sheet = 2) |>
    rename_all(str_to_lower)

mbo_mar <- concat_encounters(raw_fins_mar$fin, 800)
print(mbo_mar)

df_fins_feb <- read_excel(paste0(f, "raw/med_hist_disch_dates_feb.xlsx")) |>
    rename_all(str_to_lower)

df_fins_mar <- get_xlsx_data(paste0(f, "raw"), "med_hist_disch_dates_mar") |> 
    rename_all(str_to_lower)
