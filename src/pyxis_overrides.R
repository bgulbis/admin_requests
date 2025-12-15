library(tidyverse)
library(readxl)
library(lubridate)
library(mbohelpr)

f <- set_data_path("admin_requests", "pyxis")

raw_screen <- read_excel(paste0(f, "raw/pyxis_override_list.xlsx")) |> 
    rename_all(str_to_lower)

df_override <- raw_screen |> 
    filter(
        transactiontype == "Override",
        medid %in% c(66142426, 66108900, 66150404),
        !str_detect(device, "^HC-"),
        !is.na(id)
    )

mbo_fin <- concat_encounters(df_override$id)
print(mbo_fin)
