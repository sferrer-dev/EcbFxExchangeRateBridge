# Load here (once)
if (!requireNamespace("here", quietly = TRUE)) {
  stop("The 'here' package is required by config.R")
}
if (!requireNamespace("fs", quietly = TRUE)) {
  stop("The 'fs' package is required by config.R")
}

# Root of the R project (where the .Rproj ExchangeRate.EDA.Rproj file is located)
project_root <- here::here()

# Root "solution" above src/ExchangeRate.EDA
solution_root <- here::here("..", "..")

# Folder containing the CSV source files of the Bellabeat project data
data_dir <- file.path(solution_root, "data-samples")

# Folder containing the R Markdown files of the Bellabeat analysis
reports_dir <- file.path(project_root, "reports")

# Folder for the generated HTML site directory.
output_dir <- file.path(project_root, "output")

# Folder for the copy HTML site directory published on Github.
docs_dir <- file.path(solution_root, "docs")

# Create reports folder if needed
if (!dir.exists(reports_dir)) dir.create(reports_dir, recursive = TRUE)

# Create output folder if needed
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# Create docs folder if needed
if (!dir.exists(docs_dir)) dir.create(docs_dir, recursive = TRUE)