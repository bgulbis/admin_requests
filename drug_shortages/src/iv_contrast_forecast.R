library(tidyverse)
library(readxl)
library(lubridate)
library(mbohelpr)
library(tsibble)
library(fable)
library(feasts)
library(plotly)
library(fcasthelpr)

f <- set_data_path("admin_requests", "drug_shortages")

intervention_start <- mdy("5/11/2022")
pred_days <- 30

raw_orders <- get_xlsx_data(path = paste0(f, "raw"), pattern = "iv_contrast_orders") |> 
# raw_orders <- read_excel(paste0(f, "raw/iv_contrast_orders_2019-2022.xlsx")) |> 
    rename_all(str_to_lower)


# check for missing data --------------------------------------------------

message(paste("Data updated through", format(max(raw_orders$order_datetime), "%m/%d/%Y")))

first_day <- mdy("5/1/2022")
last_day <- as.Date(max(raw_orders$order_datetime))

all_days <- seq.Date(first_day, last_day, by = "day")

chk_days <- raw_orders |> 
    mutate(across(order_datetime, as.Date)) |> 
    distinct(order_datetime) |> 
    arrange(order_datetime) |> 
    filter(order_datetime >= first_day)

x <- tibble(days = all_days)

if (nrow(chk_days) != length(all_days)) stop("Missing data for some days")


# data tidying ------------------------------------------------------------

df_orders <- raw_orders |> 
    mutate(date = floor_date(order_datetime, unit = "days")) |> 
    filter(!is.na(dose_quantity))

df_orders_daily <- df_orders |> 
    group_by(product, date) |> 
    summarize(across(dose_quantity, sum, na.rm = TRUE), .groups = "drop") |> 
    arrange(date, product) |> 
    filter(!str_detect(product, "oral SOLN")) 

df_orders_monthly <- df_orders_daily |> 
    mutate(order_month = floor_date(date, unit = "month")) |> 
    group_by(product, order_month) |> 
    summarize(across(dose_quantity, sum, na.rm = TRUE), .groups = "drop") |> 
    arrange(order_month, product)

df_orders_avg <- df_orders_monthly |> 
    group_by(product) |> 
    summarize(across(dose_quantity, mean, na.rm = TRUE))

df_prod_select <- filter(df_orders_avg, dose_quantity > 5)

ts_data <- df_orders_daily |> 
    semi_join(df_prod_select, by = "product") |> 
    mutate(across(date, as.Date)) |> 
    as_tsibble(key = product, index = date) |> 
    fill_gaps(dose_quantity = 0L, .full = TRUE) |> 
    mutate(intervention = if_else(date >= intervention_start, TRUE, FALSE))

# fit_test <- ts_data |>
#     model(
#         ARIMA = ARIMA(dose_quantity ~ intervention),
#         ARIMA_L = ARIMA(log(dose_quantity + 1) ~ intervention)
#         VAR = VAR(dose_quantity),
#         VAR_X = VAR(dose_quantity ~ intervention),
#         VAR_XL = VAR(log(dose_quantity + 1) ~ intervention)
#     )
# 
# x <- accuracy(fit_test)


# model data --------------------------------------------------------------

fit_data <- ts_data |> 
    model(
        # ARIMA = ARIMA(dose_quantity),
        ARIMA = ARIMA(dose_quantity ~ intervention),
        ARIMA_D = decomposition_model(
            STL(dose_quantity),
            ARIMA(trend),
            ARIMA(season_week),
            ARIMA(remainder)
        ),
        ETS = ETS(dose_quantity),
        ETS_D = decomposition_model(
            STL(dose_quantity),
            ETS(trend),
            ETS(season_week),
            ETS(remainder)
        ),
        ETS_DA = decomposition_model(
            STL(dose_quantity),
            ETS(trend),
            ARIMA(season_week),
            ARIMA(remainder)
        ),
        VAR = VAR(log(dose_quantity + 1) ~ intervention),
        VAR_D = decomposition_model(
            STL(dose_quantity),
            VAR(trend),
            VAR(season_week),
            VAR(remainder)
        )
    ) |> 
    mutate(
        Forecast = (ARIMA + ARIMA_D + ETS + ETS_D + ETS_D + ETS_DA + VAR + VAR_D) / 8
    )

# x <- accuracy(fit_data)

start_date <- max(ts_data$date) + 1
stop_date <- max(ts_data$date) + pred_days

xreg_intervention <- tibble(date = seq.Date(start_date, stop_date, by = "day")) |> 
    mutate(intervention = if_else(date >= intervention_start, TRUE, FALSE)) 

xreg_data <- df_orders_daily |> 
    distinct(product) |> 
    full_join(xreg_intervention, by = character()) |> 
    as_tsibble(key = product, index = date) 
    
fc_data <- forecast(fit_data, new_data = xreg_data)
# 
# fc_test <- forecast(fit_test, new_data = xreg_data)
# 
# ggplot(fc_test, aes(x = date, y = .mean, color = .model)) +
#     geom_line() +
#     facet_grid(vars(product))


df_fc_data <- fc_data %>%
    filter(!is.na(.mean)) %>%
    hilo() %>%
    unpack_hilo(c(`80%`, `95%`)) %>%
    select(-dose_quantity) %>%
    rename(
        lo_80 = `80%_lower`,
        hi_80 = `80%_upper`,
        lo_95 = `95%_lower`,
        hi_95 = `95%_upper`
    )

df_fc_data_ind <- df_fc_data %>%
    as_tibble() %>%
    filter(.model != "Forecast") %>%
    mutate(across(c(.mean, starts_with(c("lo", "hi"))), round))

df_data_hilo <- df_fc_data_ind %>%
    group_by(product, date) %>%
    summarize(across(c(lo_80, hi_80, lo_95, hi_95), mean, na.rm = TRUE), .groups = "drop")

df_fc_data_combo <- df_fc_data %>%
    as_tibble() %>%
    filter(.model == "Forecast") %>%
    select(-starts_with(c("hi", "lo"))) %>%
    left_join(df_data_hilo, by = c("product", "date")) %>%
    mutate(across(c(.mean, starts_with(c("lo", "hi"))), round))

# p <- "iohexol 350 mg/ml 100 ml inj"
# ts_data <- rename(ts_data, date = order_date)
# x <- filter(ts_data, product == p)
# y <- filter(df_fc_data_combo, product == p) |> 
#     mutate(.model = "A_Fcast") |> 
#     rename(date = order_date)
# z <- filter(df_fc_data_ind, product == p) |> 
#     rename(date = order_date)
# 
# plotly_fable(
#     x, 
#     y = dose_quantity, 
#     combo = y, 
#     mods = z, 
#     title = paste("Product:", p), 
#     ytitle = "Product",
#     width = NULL,
#     height = NULL
# )

# save data ---------------------------------------------------------------

write_rds(pred_days, paste0(f, "final/pred_days.Rds"))
# write_rds(update_time, paste0(f, "final/update_time.Rds"))
write_rds(ts_data, paste0(f, "final/ts_data.Rds"))
write_rds(df_fc_data_ind, paste0(f, "final/df_fc_data_ind.Rds"))
write_rds(df_fc_data_combo, paste0(f, "final/df_fc_data_combo.Rds")) 
# write_rds(df_inventory, "data/final/df_inventory.Rds")



# weekly data -------------------------------------------------------------

# df_weekly <- ts_data |>
#     as_tibble() |>
#     mutate(.model = "Actual") |>
#     rename(.mean = dose_quantity) |>
#     bind_rows(df_fc_data_combo) |>
#     arrange(product, .model, date) |> 
#     mutate(week_of = floor_date(date, unit = "week")) |> 
#     group_by(product, week_of) |> 
#     summarize(across(c(.mean, lo_80, hi_80), sum, na.rm = TRUE))
# 
# df_weekly |> 
#     filter(product == "iohexol 350 mg/ml 100 ml inj") |> 
#     ggplot(aes(x = week_of, y = .mean)) +
#     geom_line()
