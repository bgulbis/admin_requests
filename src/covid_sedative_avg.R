library(tidyverse)
library(lubridate)
library(readxl)
library(mbohelpr)
library(openxlsx)

df_shic <- read_excel("data/tidy/covid/sedatives_analgesics_avg.xlsx") %>%
    rename_all(str_to_lower) %>%
    rename(rate = infusion_rate)

df_units <- df_shic %>%
    distinct(medication, infusion_unit) %>%
    filter(!is.na(infusion_unit))

df_run <- df_shic %>%
    drip_runtime(
        id = encntr_id, 
        med_datetime = dose_datetime,
        # rate = infusion_rate,
        rate_unit = infusion_unit
    ) 

df_sum <- df_run %>%
    summarize_drips(id = encntr_id)

df_drips <- df_sum %>%
    group_by(medication) %>%
    summarize_at(
        c(
            "time_wt_avg_rate",
            "duration"
        ),
        mean, 
        na.rm = TRUE
    ) %>%
    left_join(df_units, by = "medication") %>%
    select(
        medication,
        avg_rate = time_wt_avg_rate,
        infusion_unit,
        avg_duration = duration
    )

df_bags <- df_shic %>%
    filter(iv_event == "Begin Bag")

df_bags_cnt <- df_bags %>%
    count(encntr_id, medication) 

write.xlsx(df_drips, "data/external/covid/sedatives_avg.xlsx")
