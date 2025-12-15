library(tidyverse)
library(readxl)

df <- read_excel(
    "U:/Data/admin_requests/mhosh/fy19_spine-fusion_patients.xlsx", 
    skip = 5,
    col_names = c(
        "specialty",
        "surgeon",
        "procedure",
        "surgery_date",
        "case_nbr",
        "fin",
        "room",
        "proc_text",
        "in_room_min",
        "los",
        "month",
        "total"
    )
) %>%
    filter(!is.na(fin))

mbo_fin <- edwr::concat_encounters(df$fin)
print(mbo_fin)

# meds <- read_excel("data/external/opioids_clinical-event_code-value.xlsx") %>%
#     mutate(sql_cd = paste0(CODE_VALUE, ", --", DISPLAY))
# 
# openxlsx::write.xlsx(meds, "data/external/event_cd.xlsx")
