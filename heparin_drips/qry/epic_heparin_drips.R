library(tidyverse)
library(readxl)
library(lubridate)
library(mbohelpr)
library(openxlsx)
library(themebg)

f <- set_data_path("admin_requests", "heparin_drips")

raw_heparin <- read_excel(
    paste0(f, "raw/meds_heparin.xlsx"),
    skip = 11,
    col_names = c("range_start", "range_end", "mrn", "encounter_csn", "order_id", "med_datetime", "order",
                  "dose", "dose_unit", "route", "freq", "action", "prn", "nurse_unit")
) |>
    rename_all(str_to_lower) |>
    select(-range_start, -range_end) |>
    mutate(across(order, str_to_lower))

raw_enox <- read_excel(
    paste0(f, "raw/meds_anticoag.xlsx"),
    skip = 11,
    col_names = c("range_start", "range_end", "mrn", "encounter_csn", "order_id", "med_datetime", "order",
                  "dose", "dose_unit", "route", "freq", "action", "prn", "nurse_unit")
) |>
    rename_all(str_to_lower) |>
    select(-range_start, -range_end) |>
    mutate(across(order, str_to_lower))

raw_ptt <- read_excel(
    paste0(f, "raw/labs_ptt.xlsx"),
    skip = 11,
    col_names = c("range_start", "range_end", "mrn", "lab_datetime", "lab", "result", "result_unit", "nurse_unit")
) |>
    rename_all(str_to_lower) |>
    select(-range_start, -range_end) |>
    mutate(across(lab, str_to_lower))

raw_hep_vol <- read_excel(
    paste0(f, "raw/flow_heparin_vol.xlsx"),
    skip = 11,
    col_names = c("range_start", "range_end", "mrn", "encounter_csn", "taken_date", "taken_time", "event", 
                  "volume", "nurse_unit")
) |>
    rename_all(str_to_lower) |> 
    mutate(vital_datetime = ymd_hm(paste(taken_date, taken_time))) |> 
    select(-range_start, -range_end, -taken_date, -taken_time) 

zz_loc <- distinct(raw_ptt, nurse_unit) |> arrange(nurse_unit)

l_hvi <- c("HVI 4 CARDIAC CARE UNIT", "HVI 4 CARDIAC IMU", "HVI 5 HEART FAILURE ICU", "HVI 5 HEART FAILURE IMU",
           "HVI 8 CARDIOVASCULAR ICU", "HVI 8 CARDIOVASCULAR IMU")

l_sarofim <- c("HVI SAROFIM 9 HEART ICU", "HVI SAROFIM 9 HEART IMU", "TMC SAROFIM 5 BURN", "TMC SAROFIM 5 SILVER TRAUMA",
               "TMC SAROFIM 6 SHOCK TRAUMA ICU", "TMC SAROFIM 6 TRAUMA IMU", "TMC SAROFIM 7 ORTHO TRAUMA", 
               "TMC SAROFIM 8 MEDICAL ICU", "TMC SAROFIM 8 MEDICAL IMU")

l_cullen <- c("TMC CULLEN 3 IMU", "TMC CULLEN 3 MEDICINE TEACHING", "TMC CULLEN 4 W MEDICINE & ONCOLOGY", 
              "TMC CULLEN 4E ACE", "TMC CULLEN 5 W GENERAL MEDICINE")

l_jones <- c("TMC JONES 3 NEURO IMU", "TMC JONES 3 SPECIALTY SURGERY", "TMC JONES 4 E STROKE", "TMC JONES 4 NEURO ICU",
             "TMC JONES 4 NEUROSURGERY ELECTIVE", "TMC JONES 5 NEUROSCIENCE ACUTE CARE", "TMC JONES 6 E TRANSPLANT",
             "TMC JONES 6 TRAUMA", "TMC JONES 7 ELECTIVE NEURO ICU", "TMC JONES 8 CLINICAL OBSERVATION", 
             "TMC JONES 8 TRANSPLANT SURGICAL CARE", "TMC JONES 9 E BARIATRIC/GENERAL SURGERY", "TMC JONES 9 E STROKE OVERFLOW")

lvl_loc <- c("HVI", "Sarofim", "Jones", "Cullen", "Emergency", "Other")

df_hep_bags <- raw_heparin |> 
    arrange(mrn, encounter_csn, med_datetime) |> 
    filter(
        dose_unit == "Units/kg/hr",
        !str_detect(nurse_unit, "^CH|^CY|^SE")
    ) |> 
    mutate(
        med_date = floor_date(med_datetime, unit = "days"),
        location = case_when(
            nurse_unit %in% l_hvi ~ "HVI",
            nurse_unit %in% l_sarofim ~ "Sarofim",
            nurse_unit %in% l_cullen ~ "Cullen",
            nurse_unit == "TMC EMERGENCY" ~ "Emergency",
            nurse_unit %in% l_jones ~ "Jones",
            .default = "Other"
        ),
        across(location, \(x) factor(x, levels = lvl_loc))
    ) |> 
    distinct(mrn, encounter_csn, med_date, location)

df_drip_first <- df_hep_bags |> 
    arrange(mrn, encounter_csn, med_date) |> 
    distinct(mrn, encounter_csn, med_date) |> 
    rename(heparin_date = med_date)

df_hep_vol <- raw_hep_vol |> 
    arrange(mrn, encounter_csn, vital_datetime) |> 
    mutate(
        vital_date = floor_date(vital_datetime, unit = "days"),
        location = case_when(
            nurse_unit %in% l_hvi ~ "HVI",
            nurse_unit %in% l_sarofim ~ "Sarofim",
            nurse_unit %in% l_cullen ~ "Cullen",
            nurse_unit == "TMC EMERGENCY" ~ "Emergency",
            nurse_unit %in% l_jones ~ "Jones",
            .default = "Other"
        ),
        across(location, \(x) factor(x, levels = lvl_loc))
    ) |> 
    inner_join(df_drip_first, by = c("mrn", "encounter_csn"), relationship = "many-to-many") |> 
    filter(vital_date >= heparin_date) |> 
    distinct(mrn, encounter_csn, vital_date, location) |> 
    rename(med_date = vital_date)

df_drip_dates <- df_hep_bags |> 
    bind_rows(df_hep_vol) |> 
    distinct(mrn, encounter_csn, med_date, location)

df_drip_last <- df_drip_dates |> 
    arrange(mrn, encounter_csn, desc(med_date)) |> 
    distinct(mrn, encounter_csn, med_date) |> 
    rename(heparin_date = med_date)

df_ptt <- raw_ptt |> 
    arrange(mrn, lab_datetime) |> 
    mutate(
        lab_date = floor_date(lab_datetime, unit = "days"),
        censor_high = str_detect(result, ">"),
        censor_low = str_detect(result, "<"),
        across(result, \(x) str_remove_all(x, ">|<")),
        across(result, as.numeric),
        result_groups = case_when(
            result < 50 ~ "<50",
            result >= 50 & result < 90 ~ "50-89",
            result >= 90 & result < 120 ~ "90-119",
            result >= 120 & result < 200 ~ "120-199",
            result >= 200 ~ ">200"
        ),
        across(result_groups, \(x) factor(x, levels = c("<50", "50-89", "90-119", "120-199", ">200"))),
        loc_lab = case_when(
            nurse_unit %in% l_hvi ~ "HVI",
            nurse_unit %in% l_sarofim ~ "Sarofim",
            nurse_unit %in% l_cullen ~ "Cullen",
            nurse_unit == "TMC EMERGENCY" ~ "Emergency",
            nurse_unit %in% l_jones ~ "Jones",
            .default = "Other"
        ),
        across(loc_lab, \(x) factor(x, levels = lvl_loc)),
        time_day = case_when(
            hour(lab_datetime) >= 16 ~ "1600-2359",
            hour(lab_datetime) >= 8 ~ "0800-1559",
            hour(lab_datetime) < 8 ~ "0000-0759"
        ),
        across(time_day, \(x) factor(x, levels = c("0000-0759", "0800-1559", "1600-2359"))),
        day_week = weekdays(lab_datetime),
        across(day_week, \(x) factor(x, levels = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday", 
                                                   "Saturday", "Sunday")))
    ) |> 
    inner_join(df_drip_dates, by = c("mrn", "lab_date" = "med_date"), relationship = "many-to-many")

df_enox_after <- raw_enox |> 
    mutate(med_date = floor_date(med_datetime, unit = "days")) |>
    inner_join(df_drip_last, by = c("mrn", "encounter_csn"), relationship = "many-to-many") |> 
    filter(
        str_detect(order, "enoxaparin"),
        !(dose == 40 & str_detect(freq, "Every 24 hours")),
        !(dose == 30 & str_detect(freq, "Every 12 hours")),
        med_date >= heparin_date
    ) |> 
    distinct(mrn, encounter_csn, med_date) |> 
    summarize(
        enox_days = n(),
        .by = c(mrn, encounter_csn)
    )

df_oac_after <- raw_enox |> 
    mutate(med_date = floor_date(med_datetime, unit = "days")) |>
    inner_join(df_drip_last, by = c("mrn", "encounter_csn"), relationship = "many-to-many") |> 
    filter(
        !str_detect(order, "enoxaparin|fondaparinux"),
        med_date >= heparin_date
    ) |> 
    distinct(mrn, encounter_csn, med_date) |> 
    summarize(
        oac_days = n(),
        .by = c(mrn, encounter_csn)
    )    

data_patient_days <- df_drip_dates |> 
    filter(location != "Other") |> 
    summarize(
        heparin_days = n(),
        .by = c(mrn, encounter_csn)
    ) |> 
    left_join(df_enox_after, by = c("mrn", "encounter_csn")) |> 
    left_join(df_oac_after, by = c("mrn", "encounter_csn"))
    
data_anticoag <- data_patient_days |> 
    summarize(
        num_patients = n(),
        across(heparin_days, list(mean = mean, sd = sd)),
        enox_after = sum(!is.na(enox_days), na.rm = TRUE),
        oac_after = sum(if_else(!is.na(oac_days) & is.na(enox_days), 1, 0), na.rm = TRUE)
    )

data_summary <- df_ptt |> 
    filter(
        loc_lab != "Other",
        location != "Other",
        !is.na(result)
    ) |> 
    select(mrn, encounter_csn, everything(), -location)

write.xlsx(data_summary, paste0(f, "final/heparin_ptt_data.xlsx"), overwrite = TRUE)

data_sum_patients <- data_summary |> 
    distinct(mrn, lab_date) |> 
    count(lab_date, name = "num_patients") |> 
    summarize(across(num_patients, list(mean = mean, sd = sd)))

data_sum_ptt <- data_summary |> 
    count(lab_date, name = "num_ptt") |> 
    summarize(across(num_ptt, list(mean = mean, sd = sd)))

data_sum_ptt_gt200 <- data_summary |> 
    filter(result_groups == ">200") |> 
    count(lab_date, name = "num_ptt") |> 
    summarize(across(num_ptt, list(mean = mean, sd = sd)))

data_sum_patients_gt200 <- data_summary |> 
    filter(result_groups == ">200") |> 
    distinct(mrn, encounter_csn, lab_date) |> 
    count(lab_date, name = "num_ptt") |> 
    summarize(across(num_ptt, list(mean = mean, sd = sd)))

data_sum_location <- data_summary |> 
    count(lab_date, loc_lab, name = "num_ptt") |> 
    summarize(
        across(num_ptt, list(mean = mean, sd = sd)),
        .by = loc_lab
    )

data_sum_weekday <- data_summary |> 
    count(lab_date, day_week, name = "num_ptt") |> 
    summarize(
        across(num_ptt, list(mean = mean, sd = sd)),
        .by = day_week
    )

data_sum_shift <- data_summary |> 
    count(lab_date, time_day, name = "num_ptt") |> 
    summarize(
        across(num_ptt, list(mean = mean, sd = sd)),
        .by = time_day
    )

# g_ptt_range <- df_ptt |> 
#     mutate(across(result_groups, fct_rev)) |> 
#     filter(loc_lab != "other", !is.na(result_groups)) |>
#     ggplot(aes(x = lab_date)) +
#     geom_bar(aes(fill = result_groups)) +
#     scale_fill_brewer(palette = "Set1") +
#     theme_bg()    
# 
# g_ptt_range_totals <- df_ptt |> 
#     # mutate(across(loc_lab, fct_rev)) |> 
#     filter(loc_lab != "other", !is.na(result_groups)) |>
#     ggplot(aes(x = result_groups)) +
#     geom_bar() +
#     # scale_fill_brewer(palette = "Set1") +
#     theme_bg() 
# 
# g_ptt_loc <- df_ptt |> 
#     filter(loc_lab != "other") |> 
#     mutate(across(loc_lab, fct_rev)) |> 
#     ggplot(aes(x = lab_date)) +
#     geom_bar(aes(fill = loc_lab)) +
#     scale_fill_brewer(palette = "Set1") +
#     theme_bg()   
# 
# g_ptt_loc_totals <-data_summary |> 
#     count(lab_date, loc_lab, name = "num_ptt") |> 
#     ggplot(aes(x = loc_lab, y = num_ptt)) +
#     geom_boxplot() +
#     # scale_fill_brewer(palette = "Set1") +
#     theme_bg() 
# 
# g_ptt_weekday <- data_summary |> 
#     count(lab_date, day_week, name = "num_ptt") |> 
#     ggplot(aes(x = day_week, y = num_ptt)) +
#     geom_boxplot() +
#     # scale_fill_brewer(palette = "Set1") +
#     theme_bg() 
# 
# g_ptt_shift <- data_summary |> 
#     count(lab_date, time_day, name = "num_ptt") |> 
#     ggplot(aes(x = time_day, y = num_ptt)) +
#     geom_boxplot() +
#     # scale_fill_brewer(palette = "Set1") +
#     theme_bg()  
# 
# g_pts <- df_drip_dates |> 
#     filter(location != "other") |> 
#     ggplot(aes(x = med_date)) +
#     geom_bar(aes(fill = location)) +
#     scale_fill_brewer(palette = "Set1") +
#     # scale_color_brewer(palette = "Set1") +
#     theme_bg()

d_ptt_range_daily <- data_summary |> 
    filter(!is.na(result_groups)) |> 
    count(lab_date, result_groups, name = "num_ptt") |> 
    pivot_wider(names_from = result_groups, values_from = num_ptt)

d_ptt_loc_daily <- data_summary |> 
    count(lab_date, loc_lab, name = "num_ptt") |> 
    # mutate(
    #     across(loc_lab, str_to_title),
    #     across(loc_lab, \(x) if_else(x == "Hvi", "HVI", x))
    # ) |> 
    pivot_wider(names_from = loc_lab, values_from = num_ptt)

d_loc <- data_summary |> 
    count(lab_date, loc_lab, name = "num_ptt") |> 
    arrange(loc_lab, num_ptt) |> 
    # mutate(
    #     across(loc_lab, str_to_title),
    #     across(loc_lab, \(x) if_else(x == "Hvi", "HVI", x))
    # ) |> 
    select(-lab_date)

d_range <- data_summary |> 
    count(lab_date, result_groups, name = "num_ptt") |> 
    arrange(result_groups, num_ptt) |> 
    select(-lab_date)

d_weekday <- data_summary |> 
    count(lab_date, day_week, name = "num_ptt") |> 
    arrange(day_week, num_ptt) |> 
    select(-lab_date)

d_shift <- data_summary |> 
    count(lab_date, time_day, name = "num_ptt") |> 
    arrange(time_day, num_ptt) |> 
    select(-lab_date)

l <- list(
    "location" = d_loc,
    "weekday" = d_weekday,
    "shift" = d_shift,
    "range" = d_range,
    "ptt_range_daily" = d_ptt_range_daily,
    "ptt_loc_daily" = d_ptt_loc_daily
)

write.xlsx(l, paste0(f, "final/data_for_boxplot.xlsx"), overwrite = TRUE)
