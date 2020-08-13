library(tidyverse)
library(readxl)
library(mbohelpr)

data_dir <- "U:/Data/admin_requests/burn_cse/"

df <- read_excel("U:/Data/admin_requests/burn_cse/external/burn_cse_patients_baseline.xlsx") %>%
    rename(fin = `Encounter No`)

fin <- edwr::concat_encounters(df$fin)
print(fin)

raw_opioids <- get_data(data_dir, "opioids_baseline")

df_meds <- raw_opioids %>%
    arrange(fin, event_datetime) %>%
    filter(
        is.na(iv_event),
        dose > 0
    )

df_mme_meds <- calc_morph_eq(df_meds) %>%
    group_by(fin) %>%
    summarize_at("mme_iv", sum, na.rm = TRUE)

df_mme_no_ultram <- df_meds %>%
    filter(medication != "tramadol") %>%
    calc_morph_eq(df_meds) %>%
    group_by(fin) %>%
    summarize_at("mme_iv", sum, na.rm = TRUE) %>%
    rename(mme_no_tramdol = mme_iv)

df_drips <- raw_opioids %>%
    arrange(fin, event_datetime) %>%
    filter(!is.na(iv_event))

df_mme_drip <- df_drips %>%
    drip_runtime(id = fin, med_datetime = event_datetime) %>%
    mutate(dose = rate * duration) %>%
    group_by(fin, medication) %>%
    summarize_at("dose", sum, na.rm = TRUE) %>%
    filter(dose > 0) %>%
    mutate(
        route = "IV",
        med_product = medication,
        dose_unit = if_else(
            medication == "FENTanyl",
            "micrograms",
            "mg"
        )
    ) %>%
    calc_morph_eq() %>%
    group_by(fin) %>%
    summarize_at("mme_iv", sum, na.rm = TRUE) %>%
    rename(mme_drips = mme_iv)

raw_pca <- get_data(data_dir, "pca_baseline") %>%
    arrange(fin, event_datetime, event) %>%
    select(-event_id) %>%
    pivot_wider(names_from = event, values_from = result) %>%
    rename(
        demand_dose = `PCA Demand Dose`,
        demand_unit = `PCA Demand Dose Unit`,
        delivered = `PCA Doses Delivered`,
        medication = `PCA Drug`,
        lockout = `PCA Lockout Interval (minutes)`,
        demands = `PCA Total Demands`,
        loading_dose = `PCA Loading Dose`,
        cont_rate = `PCA Continuous Rate Dose`
    ) %>%
    mutate_at(
        c(
            "demand_dose",
            "delivered",
            "lockout", 
            "demands",
            "loading_dose",
            "cont_rate"
        ),
        as.numeric
    ) 
    
df_mme_pca <- raw_pca %>%
    group_by(fin, medication) %>%
    mutate(
        duration = difftime(
            lead(event_datetime),
            event_datetime,
            units = "hours"
        )
    ) %>%
    group_by(fin, medication, event_datetime) %>%
    mutate(
        demand_total = demand_dose * delivered,
        cont_total = as.numeric(duration) * cont_rate,
        dose = sum(demand_total, cont_total, loading_dose, na.rm = TRUE)
    ) %>%
    group_by(fin, medication) %>%
    summarize_at("dose", sum, na.rm = TRUE) %>%
    filter(
        !is.na(medication),
        dose > 0
    ) %>%
    mutate(
        route = "IV",
        med_product = medication,
        dose_unit = if_else(
            medication == "FENTanyl",
            "micrograms",
            "mg"
        )
    ) %>%
    calc_morph_eq() %>%
    group_by(fin) %>%
    summarize_at("mme_iv", sum, na.rm = TRUE) %>%
    rename(mme_pca = mme_iv)

data_mme <- df_mme_meds %>%
    full_join(df_mme_no_ultram, by = "fin") %>%
    full_join(df_mme_drip, by = "fin") %>%
    full_join(df_mme_pca, by = "fin") %>%
    group_by(fin) %>%
    mutate(
        total_mme = sum(mme_iv, mme_drips, mme_pca, na.rm = TRUE),
        total_mme_no_tramadol = sum(mme_no_tramdol, mme_drips, mme_pca, na.rm = TRUE))

openxlsx::write.xlsx(data_mme, "U:/Data/admin_requests/burn_cse/final/burn_pts_morph_equivalents.xlsx")

