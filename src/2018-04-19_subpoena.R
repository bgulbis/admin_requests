library(tidyverse)
library(readxl)
library(lubridate)
library(openxlsx)

df <- read_excel(
    "data/raw/2018-04_subpoena/meds.xlsx"
) %>%
    mutate_at(
        c(
            "Date and Time - Administration",
            "Date and Time - Scheduled"
        ),
        with_tz,
        tzone = "US/Central"
    )    

write.xlsx(df, "data/tidy/2018-04_subpoena/meds.xlsx")
