library(tidyverse)
library(readxl)
library(mbohelpr)
library(openxlsx)

f <- set_data_path("admin_requests", "")

df_count <- read_excel(paste0(f, "raw/dispense_doses_count.xlsx")) |> 
    rename_all(str_to_lower) |> 
    mutate(
        pyxis = disp_event_type == "Device Dispense",
        across(pyxis, ~coalesce(., FALSE))
    ) |> 
    group_by(facility, dispense_month, pyxis) |> 
    summarize(
        across(num_dispensed, \(x) sum(x, na.rm = TRUE)),
        .groups = "drop"
    ) |> 
    mutate(across(pyxis, \(x) if_else(x, "Pyxis", "Pharmacy"))) |> 
    pivot_wider(names_from = pyxis, values_from = num_dispensed)

write.xlsx(df_count, paste0(f, "final/dispense_doses_count.xlsx"), overwrite = TRUE)
