### Code to combine data for roads unit cost analysis
### Last updated: 28 August 2019
### amma.panin@gmail.com

## World Bank data sources
## https://ppi.worldbank.org/en/customquery
## https://www.doingbusiness.org/en/reports/thematic-reports/road-costs-knowledge-system
## http://web.worldbank.org/WBSITE/EXTERNAL/TOPICS/EXTTRANSPORT/EXTROADSHIGHWAYS/0,,contentMDK:20485235~menuPK:1097394~pagePK:148956~piPK:216618~theSitePK:338661,00.html#english

library(tidyverse)
library(readxl)

### Load paths -------------------------------------------------------

infrastructure.data.folder <- file.path(normalizePath("~"),
                                        "Dropbox",
                                        "Work Documents",
                                        "World Bank",
                                        "amma_striking_stats_local",
                                        "infrastructure",
                                        "data")
setwd(infrastructure.data.folder)


### Load data --------------------------------------------------------

wb.in <- readRDS("wb_indicators_clean.Rds")

country.codes <- read.csv("amma_country_codes.csv",
                          stringsAsFactors = FALSE)

rocks.dt.update.path <- "ROCKS-Update-June-2018.xlsx"
excel_sheets(rocks.dt.update.path)

rocks.update.in <- read_excel(rocks.dt.update.path,
                       sheet = "All",
                       skip = 2)

rocks.dt.old.path <- "ROCKS-Database-WORLD2008_Version2-3.xls"
excel_sheets(rocks.dt.old.path)

rocks.old.in <- read_excel(rocks.dt.old.path,
                       sheet = "Unit Costs Database",
                       skip = 9)


## ppi.dt.path <- "ppi_world_bank.xlsx"
## excel_sheets(ppi.dt.path) # View the sheets in the excel document
## ppi.in <- read_excel(ppi.dt.path)



## Figure out countries to manually recode ---------------------------

setdiff(rocks.update.in$Country, country.codes$wb)
setdiff(rocks.old.in$COUNTRY, country.codes$wb)

ccodes.merge.df <- country.codes %>%
    select(country = wb,
           ccode = code,
           region,
           inc_group) %>%
    unique() %>%
    merge(rocks.update.in %>%
          select(rocks_country = Country) %>%
          unique(),
          by.x = "country",
          by.y = "rocks_country",
          all.x = TRUE) %>%
    mutate(country = ifelse(ccode == "COD", "Congo, Dem. Rep.", country),
           country = ifelse(ccode == "COG", "Congo, Rep.", country),
           country = ifelse(ccode == "MKD", "Macedonia, FYR", country),
           country = ifelse(ccode == "VEN", "Venezuela, RB", country),
           country = ifelse(ccode == "IRN",
                            "Iran, Islamic Rep.", country),
           country = ifelse(ccode == "YEM", "Yemen, Rep.",  country),
           country = ifelse(ccode == "CPV", "Cape Verde", country))  %>%
    rename(rocks_country = country)

## Check that names line up
setdiff(rocks.update.in$Country, ccodes.merge.df$rocks_country)
setdiff(rocks.old.in$COUNTRY, ccodes.merge.df$rocks_country)

### Sort out old ROCKS data ------------------------------------------

## [Assume!!] old rocks data is in 2008 USD
## and new rocks data is in 2017 usd => multiplier of 1.14

names(rocks.old.in) <- tolower(names(rocks.old.in))

rocks.old <- rocks.old.in %>%
    rename(cost_type = costtype,
           work_type = worktype,
           cost_m = costtotal,
           length_km = length,
           project_code_in = record,
           section_code_in = section) %>%
    mutate(year = as.Date(date) %>% format("%Y"),
           component_code_in = NA,
           rocks_wave = "rocks_2008",
           cost_M_USD_per_km = 1.14 * usdperkm *  10 ^ -6)

### Sort out new ROCKS data ------------------------------------------
rocks.names <- c("country",
                 "region",
                 "project_code_in",
                 "component_code_in",
                 "section_code_in",
                 "code_in",
                 "cost_type",
                 "year",
                 "work_type",
                 "duration",
                 "length_km",
                 "cost_m",
                 "currency",
                 "cost_m_USD",
                 "cost_M_USD_per_km",
                 "check_length_under",
                 "check_cost_under",
                 "check_cost_over",
                 "check_cost_over_2",
                 "aggregate_check",
                 "outlier_categories",
                 "outlier_explanations")

names(rocks.update.in) <- rocks.names

rocks.update <- rocks.update.in %>%
    mutate(rocks_wave = "rocks_2018")


### Combine the two data frames  -------------------------------------
## Amongst other things
##  assign a project idx that is unique at the project
##  and country level

common.data <- intersect(names(rocks.update), names(rocks.old))

rocks.total <- rbind(rocks.old %>% select(one_of(common.data)),
                     rocks.update %>% select(one_of(common.data))) %>%
    filter(country != c("Yugoslavia, FR (Serbia/Montenegro)",
                        "End of File")) %>%
    filter(cost_type != "End of File") %>%
    merge(ccodes.merge.df,
          by.x = "country",
          by.y = "rocks_country",
          all.x = TRUE) %>%
    mutate(proj.component.section = paste(project_code_in,
                                          component_code_in,
                                          section_code_in),
           project_country =  paste(country, project_code_in))  %>%
    arrange(component_code_in, section_code_in) %>%
    ungroup() %>%
    mutate(project_idx = 1000 + group_indices(., project_country)) %>%
    ungroup() %>%
    mutate(section_idx = group_indices(.,proj.component.section),
           section_code = paste0(project_idx,
                                 str_pad(section_idx,
                                         width = 3,
                                         side = "left",
                                         pad = 0)))  %>%
    ungroup() %>%
    rename(wb_region = region.y) %>%
    select(-one_of(c("region.x",
                     "currency",
                     "cost_m")))#,
                                        #"proj.component.section")))

try.rocks <- rocks.total %>%
    filter(cost_type != "Ratio")%>%
    group_by(proj.component.section) %>%
    mutate(n_sections = n())

### Rocks summary information ----------------------------------------

on.projects <- length(rocks.total$project_code_in %>% unique())
n.sections <- length(rocks.total$section_code %>% unique())


### Write out file ---------------------------------------------------

write.csv(x = rocks.total,
          file = "rocks_combined_1994-2018.csv",
          row.names = FALSE)


