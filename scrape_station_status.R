# Load libraries
library(dplyr)
library(tidyr)
library(purrr)
library(lubridate)
library(jsonlite)
library(magrittr)
library(DBI)
library(RSQLite)

# Connect to the database
db <- dbConnect(RSQLite::SQLite(), "lyft_bike_data.db")

# Grab the data and format it
station_status <- fromJSON("https://gbfs.lyft.com/gbfs/2.3/dca-cabi/en/station_status.json",
                           flatten = TRUE) %>% 
  use_series("data") %>% 
  list_rbind() %>% 
  unnest(cols = vehicle_types_available) %>% 
  mutate(vehicle_type_id = case_when(vehicle_type_id == "1" ~ "bikes", 
                                     vehicle_type_id == "2" ~ "ebikes",
                                     .default = vehicle_type_id))

column_names <- names(station_status)

column_names <- column_names[column_names != c("count", "vehicle_type_id")]

station_status <- station_status %>% 
  pivot_wider(id_cols = all_of(column_names), 
              names_from = vehicle_type_id, 
              values_from = count,
              names_prefix = "available_") %>% 
  mutate(last_reported = as_datetime(last_reported, tz = "America/New_York"))

# Write the data to the table
dbWriteTable(conn = db, name = "station_status", value = station_status, 
             append = TRUE)

# Disconnect from the database
dbDisconnect(db)