# packages ---------------------------------------------------------------------
library(purrr)
library(dplyr)
library(here)
library(readr)
library(scoringutils)
library(rmarkdown)
library(data.table)
library(covidHubUtils)
library(lubridate)

options(knitr.duplicate.label = "allow")

start_date <- as.Date("2021-03-22")
recreate <- TRUE

report_dates <-
  lubridate::floor_date(lubridate::today(), "week", week_start = 7) + 1
report_type <- "evaluation"

locations <- hub_locations_ecdc

suppressWarnings(dir.create(here::here("html")))

last_forecast_date <- report_date - 7
## load forecasts --------------------------------------------------------------
forecasts <- load_forecasts(source = "local_hub_repo",
                            hub_repo_path = here(),
                            hub = "ECDC")
setDT(forecasts)
## set forecast date to corresponding submision date
forecasts[, forecast_date :=
              ceiling_date(forecast_date, "week", week_start = 2) - 1]
forecasts <- forecasts[forecast_date >= "2021-03-08"]
forecasts <- forecasts[forecast_date <= last_forecast_date]
setnames(forecasts, old = c("value"), new = c("prediction"))

## load truth data -------------------------------------------------------------
truth <- map_dfr(.x = c("inc case", "inc death"),
                 .f = ~ load_truth(truth_source = "JHU",
                                   target_variable = .x,
                                   hub = "ECDC"))
setDT(truth)
truth[, model := NULL]
truth <- truth[target_end_date <= report_date]
setnames(truth, old = c("value"),
         new = c("true_value"))

data <- scoringutils::merge_pred_and_obs(forecasts, truth,
                                         join = "full")

if (recreate) {
  report_dates <- seq(start_date, report_dates, by = 7)
}

for (rdc in as.character(report_dates)) {
    report_date <- as.Date(rdc)
    for (i in seq_len(nrow(hub_locations_ecdc))) {
        country_code <- hub_locations_ecdc$location[i]
        country <- hub_locations_ecdc$location_name[i]

        rmarkdown::render(here::here(
            "code", "reports", "evaluation",
            "evaluation-by-country.Rmd"
        ),
        output_format = "html_document",
        params = list(
            data = data,
            location_code = country_code,
            location_name = country,
            report_date = report_date
        ),
        output_file =
            here::here(
                "html",
                paste0(
                    "evaluation-report-", report_date,
                    "-", country, ".html"
                )
            ),
        envir = new.env()
        )
    }

    rmarkdown::render(here::here(
        "code", "reports", "evaluation",
        "evaluation-report.Rmd"
    ),
    params = list(
        data = data,
        report_date = report_date,
        location_name = "Overall"
    ),
    output_format = "html_document",
    output_file =
        here::here("html", paste0(
            "evaluation-report-", report_date,
            "-Overall.html"
        )),
    envir = new.env()
    )
}
