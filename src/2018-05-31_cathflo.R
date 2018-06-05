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

# find missing -----------------------------------------

test <- read_data(dir_raw, "test", FALSE) %>%
    as.patients()

charges <- "data/external/2018-05_cathflo/charges_2017-04_2017-06.csv" %>%
    read_csv() %>%
    # filter(
    #     qty < 10,
    #     qty > 0
    # ) %>%
    mutate_at(
        "acct",
        str_replace_all,
        pattern = "^C0",
        replacement = ""
    )

test_fin <- concat_encounters(charges$acct)

# run MBO query
#   * Identifiers - by FIN

test_id <- read_data(dir_raw, "id-fin", FALSE) %>%
    as.id()

x <- semi_join(test, test_id, by = "millennium.id")
y <- anti_join(test_id, test, by = "millennium.id") %>%
    left_join(charges, by = c("fin" = "acct"))

pts_orders <- read_data(dir_raw, "patients-orders", FALSE) %>%
    as.patients()

mbo_orders <- concat_encounters(pts_orders$millennium.id)

# run MBO query
#   * Orders Meds - Details with Volume

cathflo <- "alteplase 1 mg INJ (2 mg/2 ml)"

orders <- read_data(dir_raw, "orders-details", FALSE) %>%
    as.order_detail(
        extras = c(
            "order.product" = "Mnemonic (Product)",
            "order.as" = "Mnemonic (Ordered As Name)"
        )
    ) %>%
    mutate_at("ingredient.dose", as.numeric) %>%
    filter(order.product == cathflo | order.as == cathflo)
