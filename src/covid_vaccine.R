library(tidyverse)
library(readxl)
library(themebg)

df <- read_excel("data/raw/covid_vaccine_doses.xlsx") %>%
    mutate(across(scenario, factor))

df %>%
    ggplot(aes(x = day, y = inventory, color = scenario)) +
    geom_line() +
    theme_bg()

df %>%
    ggplot(aes(x = day, y = tmc_cum, color = scenario)) +
    geom_line() +
    theme_bg()
