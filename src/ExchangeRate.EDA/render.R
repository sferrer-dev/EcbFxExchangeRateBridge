library(rmarkdown)
library(here)
library(fs)

# Custom project configuration
source(here("config", "config.R"))

rmarkdown::render(
  input      = here::here("reports", "01_Ecb_Exchange_Rate_Profiling_EDA.Rmd"),
  output_dir = here::here("output"),
  clean      = TRUE
)

# Rapport 2 : Overview
rmarkdown::render(
  input      = here("reports", "02_Ecb_Exchange_Rate_Files_Overview.Rmd"),
  output_dir = here("output"),
  clean      = TRUE
)


# Publication : sync output/* -> docs/
fs::dir_delete(docs_dir)
fs::dir_create(docs_dir)

files_to_publish <- fs::dir_ls(output_dir, recurse = TRUE, all = TRUE)
fs::file_copy(files_to_publish, docs_dir, overwrite = TRUE)


