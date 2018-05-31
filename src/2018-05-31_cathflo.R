library(tidyverse)
library(lubridate)
library(edwr)

dir_raw <- "data/raw/2018-05_cathflo"

dirr::gzip_files(dir_raw)

# run MBO query
#   * Patients - by Medication (Generic)
#       - Facility (Curr): HH HERMANN;HH Trans Care;HH Rehab;HH Clinics
#       - Medication (Generic): alteplase
#       - Admit date: 2/1/2018 - 4/30/2018

pts <- read_data(dir_raw, "patients", FALSE) %>%
    as.patients()

mbo_pts <- concat_encounters(pts$millennium.id)

# run MBO query
#   * Medications - Inpatient - Prompt
#       - Medication (Generic): alteplase

meds <- read_data(dir_raw, "meds-inpt", FALSE) %>%
    as.meds_inpt() %>%
    filter(
        is.na(event.tag),
        med.dose >= 1,
        med.dose <= 2
    ) %>%
    mutate_at("med.dose", factor)


