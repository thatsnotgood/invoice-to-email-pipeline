# install.packages("cyphr")
# install.packages("sodium")
library("tidyverse")
library("readxl")
library("cyphr")
library("sodium")

# ==== 1. Import raw sheets ====

# Helper that reads *one* sheet and cleans it
ReadOneSheet <- function(path, sheet) {
    read_xlsx(path, sheet = sheet) |>
        rename_with(
            function(x) {
                x |>
                    str_replace_all("[^[:alnum:]]+", "_") |>
                    str_replace_all("_+", "_") |>
                    str_replace("^_|_$", "") |>
                    str_to_lower() |>
                    make.unique(sep = "_")
            }
        ) |>
        mutate(across(where(is.character), str_trim))
}

# Main function: loop over sheets, returns named list ====
ImportClientData <- function(
    path = Sys.getenv("CLIENT_XLSX_PATH"),
    sheets = c("metadata", "line_items")) {
    
    stopifnot("Error: CLIENT_XLSX_PATH is empty." = nzchar(path))
    
    sheets |>
        set_names() |>
        map(~ ReadOneSheet(path, .x))
}

dfs <- ImportClientData()    # Reads both sheets

metadata_df <- dfs$metadata
line_items_df <- dfs$line_items

# ==== 2. Prepare an encryption key ====

# Strategy: create *once* on first run, then reuse the same key file.
key_file <- "secrets/master_key.bin"
if (!file.exists(key_file)) {
    dir.create(dirname(key_file), recursive = TRUE, showWarnings = FALSE)
    writeBin(sodium::random(32), key_file)    # 256‑bit symmetric key
}

key <- cyphr::key_sodium(readBin(key_file, "raw", 32))

# ==== 3. Helper: encrypt any data‑frame to .rds.enc

EncryptRds <- function(df, target) {
    temp_plain <- tempfile(fileext = ".rds")
    saveRDS(df, temp_plain, compress = "xz")
    cyphr::encrypt_file(
        path = temp_plain,
        key = key,
        dest = target
    )
    unlink(temp_plain)
}

# ==== 4. Write encrypted artefacts ====

dir.create("data/processed", recursive = TRUE, showWarnings = FALSE)
EncryptRds(metadata_df, "data/processed/metadata.rds.enc")
EncryptRds(line_items_df, "data/processed/line_items.rds.enc")

message("Success! Encrypted .rds files written to data/processed/")

# ==== 5. Remove plain-text data & key from workspace ====

rm(metadata_df, line_items_df)
rm(dfs, key_file, key)
Sys.unsetenv("CLIENT_XLSX_PATH")
gc()