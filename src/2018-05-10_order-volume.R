library(tidyverse)
library(lubridate)
library(edwr)
library(officer)
library(rvg)
library(themebg)

dir_raw <- "data/raw/2018-05_order-volume"
tz <- "US/Central"

dirr::gzip_files(dir_raw)

# run MBO query
#   * Patients - by Order Category

raw_patients <- read_data(dir_raw, "patients", FALSE) %>%
    as.patients() %>%
    filter(
        is.na(discharge.datetime) | 
            discharge.datetime >= mdy("3/31/2018", tz = tz)
    )

mbo_id <- concat_encounters(raw_patients$millennium.id)

# run MBO query
#   * Orders - Pharmacy Parent

raw_orders_parent <- read_data(dir_raw, "orders-parent", FALSE) %>%
    distinct() %>%
    select(
        millennium.id = `Encounter Identifier`,
        order.id = `Order Id`,
        order.datetime = `Date and Time - Original (Placed)`,
        order.start = `Date and Time - Order Start`,
        order.dc = `Date and Time - Discontinue Effective`,
        order = `Mnemonic (Primary Generic) FILTER ON`,
        prn = `PRN Indicator`,
        order.location = `Nurse Unit (Order)`,
        building = `Building (Order)`
    ) %>%
    format_dates(
        c("order.datetime", "order.start", "order.dc"), 
        tz
    ) %>%
    filter(!str_detect(order.location, "^CY|^NE"))

# x <- distinct(raw_orders_parent, order.location)

ed_units <- c(
    "HH VUHH",
    "HH EDHH",
    "HH EDTR",
    "HH EREV",
    "HH OBEC",
    "HC EDPD"
)

icu_units <- c(
    "HH CCU",
    "HH CVICU",
    "HH HFIC",
    "HH MICU",
    "HH STIC",
    "HH 7J",
    "HH NVIC",
    "HH TSIC"
)

imu_units <- c(
    "HVI CIMU",
    "HH CVIMU",
    "HH HFIM",
    "HH MIMU",
    "HH SIMU",
    "HH 3CIM",
    "HH NIMU",
    "HH STRK"
)

floor_units <- c(
    "HH 3JP",
    "HH 3CP",
    "HH 4WCP",
    "HH ACE",
    "HH 5ECP",
    "HH 5JP",
    "HH 5WCP",
    "HH 6EJP",
    "HH 6WJP",
    "HH 8NJP",
    "HH EMU",
    "HH NEU",
    "HH 8WJP",
    "HH 9EJP",
    "HH 9WJP",
    "HH REHA",
    "HH TCF"
)

womens_units <- c(
    "HH WC5",
    "HH WC6N",
    "HH WCAN"
)

neonatal_units <- c(
    "HC A8N4",
    "HC A8NH",
    "HC NICE",
    "HC NICW"
)

pedi_units <- c(
    "HC A8OH",
    "HC A8PH",
    "HC CCN",
    "HC CSC",
    "HC PEMU",
    "HC PICU"
)

data_orders <- raw_orders_parent %>%
    filter(!is.na(order.datetime)) %>%
    mutate(
        order.hour = hour(order.datetime),
        order.day = weekdays(order.datetime, TRUE),
        facility = case_when(
            str_detect(order.location, "^HC") ~ "Children\'s",
            str_detect(order.location, "^HHCL") ~ "Other",
            str_detect(order.location, "^RAD") ~ "Other",
            order.location %in% c("HH CAHF", "HH Transplnt Ctr") ~ "Other",
            TRUE ~ "Adult"
        ),
        location.group = case_when(
            order.location %in% ed_units ~ "ED",
            order.location %in% icu_units ~ "ICU",
            order.location %in% imu_units ~ "IMU",
            order.location %in% floor_units ~ "Floor",
            order.location %in% womens_units ~ "Women\'s",
            order.location %in% neonatal_units ~ "Neonatal",
            order.location %in% pedi_units ~ "Pedi",
            TRUE ~ "Other"
        )
    ) %>%
    mutate_at(
        "order.day", 
        factor,
        levels = c(
            "Sun",
            "Mon",
            "Tue",
            "Wed",
            "Thu",
            "Fri",
            "Sat"
        ),
        ordered = TRUE
    ) %>%
    mutate_at(
        "building", 
        str_replace_all, 
        pattern = "HC Hermann", 
        replacement = "HC Childrens"
    )

write_rds(
    data_orders,
    "data/tidy/2018-05_order-volume/data_orders.Rds",
    compress = "gz"
)

pavilions <- c(
    "HH Hermann",
    "HH Cullen",
    "HH Jones",
    "HH HVI",
    "HC Childrens"
)

p_hour <- data_orders %>%
    filter(
        !is.na(facility),
        facility != "other",
        building %in% pavilions
    ) %>%
    ggplot(aes(x = order.hour, fill = building)) + 
    geom_bar() +
    facet_wrap(
        ~ facility, 
        # scales = "free_y", 
        ncol = 1
    ) +
    scale_x_continuous(
        "Hour of Day",
        breaks = seq(0, 24, by = 6)
    ) +
    ylab("Number of orders") +
    scale_fill_brewer("Pavilion", palette = "Set1") +
    theme_bg()

p_hour_bld <- data_orders %>%
    filter(building %in% pavilions) %>%
    ggplot(aes(x = order.hour, fill = location.group)) + 
    geom_bar() +
    facet_wrap(~ building) +
    scale_x_continuous(
        "Hour of Day",
        breaks = seq(0, 24, by = 6)
    ) +
    ylab("Number of orders") +
    scale_fill_brewer("Location", palette = "Set1") +
    theme_bg()

p_day <- data_orders %>%
    filter(
        !is.na(facility),
        facility != "other",
        building %in% pavilions
    ) %>%
    ggplot(aes(x = order.day, fill = building)) + 
    geom_bar() +
    facet_wrap(
        ~ facility, 
        # scales = "free_y", 
        ncol = 1
    ) +
    xlab("Day of week") +
    ylab("Number of orders") +
    scale_fill_brewer("Pavilion", palette = "Set1") +
    theme_bg(xticks = FALSE)

p_day_bld <- data_orders %>%
    filter(building %in% pavilions) %>%
    ggplot(aes(x = order.day, fill = location.group)) + 
    geom_bar() +
    facet_wrap(~ building) +
    xlab("Day of week") +
    ylab("Number of orders") +
    scale_fill_brewer("Location", palette = "Set1") +
    theme_bg()


# mbo_orders <- concat_encounters(raw_orders_parent$order.id)

# run MBO query
#   * Orders - Actions - Parent

raw_actions <- read_data(dir_raw, "orders-actions", FALSE) %>%
    as.order_action() 

data_actions <- raw_actions %>%
    semi_join(data_orders, by = "order.id") %>%
    filter(
        (
            str_detect(
                action.provider.role,
                regex("pharm", ignore_case = TRUE)
            ) |
                str_detect(
                    action.provider,
                    regex("rph", ignore_case = TRUE)
                )
        ),
        action.type != "Status Change",
        action.type != "Complete"
    ) %>%
    mutate(
        action.hour = hour(action.datetime),
        action.day = weekdays(action.datetime, TRUE),
        facility = case_when(
            str_detect(order.location, "^HC") ~ "Children\'s",
            str_detect(order.location, "^HHCL") ~ "Other",
            str_detect(order.location, "^RAD") ~ "Other",
            order.location %in% c("HH CAHF", "HH Transplnt Ctr") ~ "Other",
            TRUE ~ "Adult"
        ),
        location.group = case_when(
            order.location %in% ed_units ~ "ED",
            order.location %in% icu_units ~ "ICU",
            order.location %in% imu_units ~ "IMU",
            order.location %in% floor_units ~ "Floor",
            order.location %in% womens_units ~ "Women\'s",
            order.location %in% neonatal_units ~ "Neonatal",
            order.location %in% pedi_units ~ "Pedi",
            TRUE ~ "Other"
        )
    ) %>%
    mutate_at(
        "action.day", 
        factor,
        levels = c(
            "Sun",
            "Mon",
            "Tue",
            "Wed",
            "Thu",
            "Fri",
            "Sat"
        ),
        ordered = TRUE
    ) %>%
    left_join(
        data_orders[c("millennium.id", "order.id", "building")],
        by = c("millennium.id", "order.id")
    )

write_rds(
    data_actions,
    "data/tidy/2018-05_order-volume/data_actions.Rds",
    compress = "gz"
)

a_hour <- data_actions %>%
    filter(
        !is.na(facility),
        facility != "other",
        building %in% pavilions
    ) %>%
    ggplot(aes(x = action.hour, fill = building)) + 
    geom_bar() +
    facet_wrap(
        ~ facility, 
        # scales = "free_y", 
        ncol = 1
    ) +
    scale_x_continuous(
        "Hour of Day",
        breaks = seq(0, 24, by = 6)
    ) +
    ylab("Number of order actions") +
    scale_fill_brewer("Pavilion", palette = "Set1") +
    theme_bg()

a_hour_type <- data_actions %>%
    filter(
        !is.na(facility),
        facility != "other",
        building %in% pavilions
    ) %>%
    ggplot(aes(x = action.hour, fill = action.type)) + 
    geom_bar() +
    facet_wrap(
        ~ facility, 
        # scales = "free_y", 
        ncol = 1
    ) +
    scale_x_continuous(
        "Hour of Day",
        breaks = seq(0, 24, by = 6)
    ) +
    ylab("Number of order actions") +
    scale_fill_brewer("Pavilion", palette = "Set1") +
    theme_bg()

a_day <- data_actions %>%
    filter(
        !is.na(facility),
        facility != "other",
        building %in% pavilions
    ) %>%
    ggplot(aes(x = action.day, fill = building)) + 
    geom_bar() +
    facet_wrap(
        ~ facility, 
        # scales = "free_y", 
        ncol = 1
    ) +
    xlab("Day of week") +
    ylab("Number of order actions") +
    scale_fill_brewer("Pavilion", palette = "Set1") +
    theme_bg(xticks = FALSE)

a_day_type <- data_actions %>%
    filter(
        !is.na(facility),
        facility != "other",
        building %in% pavilions
    ) %>%
    ggplot(aes(x = action.day, fill = action.type)) + 
    geom_bar() +
    facet_wrap(
        ~ facility, 
        # scales = "free_y", 
        ncol = 1
    ) +
    xlab("Day of week") +
    ylab("Number of order actions") +
    scale_fill_brewer("Pavilion", palette = "Set1") +
    theme_bg(xticks = FALSE)
