library(tidyverse)
library(readxl)
library(lubridate)

df <- read_excel("data/raw/stats_abx_orders/stats_abx_orders_turnaround_2019-07.xlsx") %>%
    rename_all(str_to_lower) %>%
    mutate(across(order_id, as.character))

x <- count(df, order_month, facility, order_group)

y <- df %>%
    group_by(order_month, facility, order_group) %>%
    summarize(across(c(order_verify_min, verify_admin_min, order_admin_min), median))

z <- df %>%
    count(order_id) %>%
    filter(n > 1)
