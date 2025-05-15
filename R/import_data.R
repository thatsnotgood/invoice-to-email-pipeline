# install.packages("cyphr")
# install.packages("sodium")
library("tidyverse")
library("readxl")
library("cyphr")
library("sodium")

# ==== 1. Import raw sheets ====

# Helper that reads one sheet and cleans it
ReadOneSheet <- function(path, sheet) {
    clean_sheet <- read_xlsx(path, sheet = sheet) |>
        rename_with(function(x) {
            x |>
                str_replace_all("[^[:alnum:]]+", "_") |>
                str_replace_all("_+", "_") |>
                str_replace("^_|_$", "") |>
                str_to_lower() |>
                make.unique(sep = "_")
        }) |>
        mutate(across(where(is.character), str_trim))
    return(clean_sheet)
}

# Main import function: loop over sheets, returns named list
ImportClientData <- function(
    path = Sys.getenv("CLIENT_XLSX_PATH"),
    sheets = c("metadata", "line_items")) {
    
    # Fail-safe if path is empty
    stopifnot("Error: CLIENT_XLSX_PATH is empty." = nzchar(path))
    
    # Read and clean each sheet, collect into a named list
    sheets_list <- sheets |>
        set_names() |>
        map(function(sheet) {
            return(ReadOneSheet(path, sheet))
        })
    return(sheets_list)
}

invoice_data <- ImportClientData()    # Reads both sheets

metadata_tbl <- invoice_data$metadata
line_items_tbl <- invoice_data$line_items

# ==== 2. Prepare an encryption key ====

# Strategy: create once on first run, then reuse the same key file henceforth
key_file <- "secrets/master_key.bin"
if (!file.exists(key_file)) {
    dir.create(dirname(key_file), recursive = TRUE, showWarnings = FALSE)
    writeBin(sodium::random(32), key_file)    # 256‑bit symmetric key
}

key <- cyphr::key_sodium(readBin(key_file, "raw", 32))

# ==== 3. Helper: encrypt any tibble to .rds.enc ====

EncryptRds <- function(tbl, target) {
    # Fail-safe that requires a global object named `key`
    stopifnot("Error: `key` must exist in the calling environment." = exists("key"))
    
    # Creates temporary .rds file for tibble, temp file is nuked on exit
    temp_plain <- tempfile(fileext = ".rds")
    on.exit(unlink(temp_plain), add = TRUE)
    saveRDS(tbl, temp_plain, compress = "xz")
    
    # Encrypts temporary .rds file to create target .rds.enc file
    out <- cyphr::encrypt_file(temp_plain, key, dest = target)
    
    # Fail-safe if EncryptRds() does not yield target files
    if (!file.exists(target) || file.size(target) == 0) {
        stop("Error: Encrypted file was not created.")
    }
    
    return(out)
}

# ==== 4. Write encrypted artefacts ====

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
EncryptRds(metadata_tbl, "data/processed/metadata.rds.enc")
EncryptRds(line_items_tbl, "data/processed/line_items.rds.enc")

message("Success! Encrypted .rds files written to data/processed/")

# ==== 5. Nuke plain-text data & key from workspace ====

rm(metadata_tbl, line_items_tbl)
rm(invoice_data, key_file, key)
Sys.unsetenv("CLIENT_XLSX_PATH")
gc()